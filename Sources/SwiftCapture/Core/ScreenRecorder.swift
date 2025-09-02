import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import Darwin

/// Main screen recorder class that coordinates all recording components
/// Uses a modular architecture for maintainable and testable code
@available(macOS 12.3, *)
class ScreenRecorder {
    
    // MARK: - Manager Dependencies
    private let displayManager: DisplayManager
    private let applicationManager: ApplicationManager
    private let outputManager: OutputManager
    private let captureController: CaptureController
    
    // MARK: - Initialization
    init() {
        self.displayManager = DisplayManager()
        self.applicationManager = ApplicationManager()
        self.outputManager = OutputManager()
        self.captureController = CaptureController()
    }
    
    // MARK: - Main Recording Method
    
    /// Execute recording with the given configuration
    /// - Parameter config: Complete recording configuration
    /// - Throws: Various errors if recording fails
    func record(with config: RecordingConfiguration) async throws {
        // Resolve screen and application information
        let finalConfig = try await resolveConfiguration(config)
        
        print("🎬 Starting recording with configuration:")
        print("   \(finalConfig)")
        print("📝 Recording details:")
        print("   Mode: \(finalConfig.duration < 0 ? "Continuous" : "Timed")")
        if finalConfig.duration >= 0 {
            print("   Duration: \(String(format: "%.2f", finalConfig.duration))s (\(Int(finalConfig.duration * 1000))ms)")
        }
        print("   Output: \(finalConfig.outputURL.path)")
        print("   Resolution: \(Int(finalConfig.videoSettings.resolution.width)) × \(Int(finalConfig.videoSettings.resolution.height))")
        print("   Frame rate: \(finalConfig.videoSettings.fps) fps")
        print("   Quality: \(finalConfig.videoSettings.quality.rawValue)")
        
        // Show countdown if configured
        if finalConfig.countdown > 0 {
            try await showCountdown(finalConfig.countdown)
        }
        
        // Setup output components
        let (writer, videoInput, audioInput, adaptor) = try outputManager.setupRecording(for: finalConfig)
        
        // Create progress indicator but don't start it yet
        let progressIndicator = ProgressIndicator(
            outputURL: finalConfig.outputURL,
            expectedDuration: finalConfig.duration
        )
        
        // Setup graceful shutdown handling
        var captureStream: SCStream?
        var isRecordingComplete = false
        
        // Only set up signal handler for continuous recording (duration < 0)
        // For timed recordings, let them complete naturally without signal interruption
        if finalConfig.duration < 0 {
            // This will be set up later in the continuous recording branch
            // to avoid premature signal handler setup
        }
        
        do {
            // Start capture
            captureStream = try await captureController.startCapture(
                with: finalConfig,
                writer: writer,
                videoInput: videoInput,
                audioInput: audioInput,
                adaptor: adaptor
            )
            
            // Start progress indicator after capture is actually started
            progressIndicator.startProgress()
            
            // Wait for the specified duration or until interrupted
            if finalConfig.duration < 0 {
                // Continuous recording mode - wait indefinitely until interrupted
                
                // Use async continuation to wait indefinitely until the signal handler stops the recording
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // Update the signal handler to resume the continuation when interrupted
                    SignalHandler.shared.setupForRecording(progressIndicator: progressIndicator) {
                        // Graceful shutdown callback for continuous recording
                        // Use async/await pattern for proper concurrency handling
                        Task {
                            // Mark recording as complete to prevent double stopping
                            isRecordingComplete = true
                            
                            print("🛑 Stopping continuous recording and finalizing file...")
                            
                            // Stop the capture stream
                            if let stream = captureStream {
                                do {
                                    try await self.captureController.stopCapture(stream)
                                } catch {
                                    print("⚠️ Error during graceful shutdown: \(error.localizedDescription)")
                                }
                            }
                            
                            // Mark inputs as finished
                            videoInput.markAsFinished()
                            if let audioInput = audioInput {
                                audioInput.markAsFinished()
                            }
                            
                            // Finalize recording with proper error handling and timing
                            let finalizeStartTime = Date()
                            print("💾 Starting file finalization (timeout: 15s)...")
                            let finalizationResult = await withTaskGroup(of: Result<Void, Error>.self) { group in
                                // Finalization task
                                group.addTask {
                                    do {
                                        try await self.outputManager.finalizeRecording(
                                            writer: writer,
                                            videoInput: videoInput,
                                            audioInput: audioInput
                                        )
                                        return .success(())
                                    } catch {
                                        return .failure(error)
                                    }
                                }
                                
                                // Timeout task (15 seconds - increased from 8 seconds)
                                group.addTask {
                                    do {
                                        try await Task.sleep(nanoseconds: 15_000_000_000)
                                        return .failure(NSError(domain: "FinalizationTimeout", code: -1, 
                                                      userInfo: [NSLocalizedDescriptionKey: "File finalization timed out after 15 seconds"]))
                                    } catch {
                                        return .failure(error)
                                    }
                                }
                                
                                // Return the first completed task
                                let result = await group.next() ?? .failure(NSError(domain: "UnknownError", code: -1))
                                group.cancelAll()
                                return result
                            }
                            
                            let finalizeDuration = Date().timeIntervalSince(finalizeStartTime)
                            
                            switch finalizationResult {
                            case .success():
                                print("✅ File finalized successfully in \(String(format: "%.2f", finalizeDuration))s")
                            case .failure(let error):
                                if error.localizedDescription.contains("timed out") {
                                    print("⚠️ File finalization timed out after \(String(format: "%.2f", finalizeDuration))s")
                                    print("📁 The video file may be incomplete or unplayable")
                                    print("💡 Try using shorter recording durations or check available disk space")
                                } else {
                                    print("⚠️ Error finalizing recording after \(String(format: "%.2f", finalizeDuration))s: \(error.localizedDescription)")
                                    print("📁 The video file may be corrupted or unplayable")
                                }
                                // Don't throw the error - let the program exit gracefully
                                // The file might still be partially usable
                                print("🔄 Attempting graceful exit despite finalization issues...")
                            }
                            
                            // Complete progress indicator
                            progressIndicator.stopProgress()
                            
                            // Resume continuation successfully
                            continuation.resume()
                        }
                    }
                }
                
                // For continuous recording, the finalization is handled in the signal handler
                // Exit gracefully after completion
                print("🔄 Continuous recording completed, exiting...")
                exit(0)
                
            } else {
                // Timed recording mode - wait for the exact duration
                let durationSeconds = finalConfig.duration
                print("🕰️ Starting timed recording for \(String(format: "%.2f", durationSeconds)) seconds (\(String(format: "%.0f", durationSeconds * 1000)) ms)")
                
                // Enhanced logging for debugging duration issues
                print("🔍 Debug Info:")
                print("   Target duration: \(durationSeconds) seconds (\(Int(durationSeconds * 1000)) ms)")
                print("   Signal handler state before setup: \(SignalHandler.shared.isHandling ? "active" : "inactive")")
                
                // Clean up any existing signal handlers to ensure fresh start
                SignalHandler.shared.cleanup()
                print("   Signal handler cleaned up, state: \(SignalHandler.shared.isHandling ? "active" : "inactive")")
                
                // Set up a gentle signal handler that allows early termination but doesn't exit immediately
                var shouldStopEarly = false
                var earlyTerminationReason = "Unknown"
                
                SignalHandler.shared.setupGracefulShutdown {
                    print("\n🛑 Early termination requested (Ctrl+C)")
                    print("   Stopping timed recording gracefully...")
                    earlyTerminationReason = "User interrupted (Ctrl+C)"
                    shouldStopEarly = true
                }
                print("   Signal handler setup complete, state: \(SignalHandler.shared.isHandling ? "active" : "inactive")")
                
                // Wait for duration or early termination
                let startTime = Date()
                let expectedEndTime = startTime.addingTimeInterval(durationSeconds)
                let acceptableErrorMargin: TimeInterval = 0.1 // 允许0.1秒误差
                
                var lastProgressTime = startTime
                var iterationCount = 0
                var lastLogTime = startTime
                var lastDurationCheckTime = startTime
                
                print("🚀 Starting recording loop at \(startTime)")
                print("🎯 Expected end time: \(expectedEndTime) (\(String(format: "%.1f", durationSeconds))s later)")
                print("⚙️ Acceptable error margin: ±\(acceptableErrorMargin)s")
                
                while !shouldStopEarly {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let currentTime = Date()
                    
                    // 双重保险检查：基于时间间隔和绝对时间戳
                    let timeBasedCheck = elapsed >= durationSeconds
                    let timestampBasedCheck = currentTime >= expectedEndTime.addingTimeInterval(-acceptableErrorMargin)
                    
                    // 主要检查：达到目标时长
                    if timeBasedCheck {
                        print("✓ Target duration reached: \(String(format: "%.2f", elapsed))s (time-based check)")
                        break
                    }
                    
                    // 备用检查：达到预期结束时间
                    if timestampBasedCheck {
                        let timeUntilExpected = expectedEndTime.timeIntervalSince(currentTime)
                        if timeUntilExpected <= acceptableErrorMargin {
                            print("✓ Target duration reached: \(String(format: "%.2f", elapsed))s (timestamp-based check)")
                            print("🕰️ Time until expected end: \(String(format: "%.2f", timeUntilExpected))s")
                            break
                        }
                    }
                    
                    // 安全检查：防止超时运行（比目标时间多1秒）
                    if elapsed > durationSeconds + 1.0 {
                        print("⚠️ Safety check triggered: Recording exceeded target by \(String(format: "%.2f", elapsed - durationSeconds))s")
                        earlyTerminationReason = "Safety timeout - exceeded target duration by \(String(format: "%.2f", elapsed - durationSeconds))s"
                        shouldStopEarly = true
                        break
                    }
                    
                    // 定期检查：每半秒检查一次对时状态（静默检查）
                    if Date().timeIntervalSince(lastDurationCheckTime) >= 0.2 {
                        let timeUntilExpected = expectedEndTime.timeIntervalSince(currentTime)
                        
                        // 静默检查时间漂移，只在异常时输出警告
                        let timeDrift = abs(timeUntilExpected - (durationSeconds - elapsed))
                        if timeDrift > 1.0 {
                            print("⚠️ Time drift detected: \(String(format: "%.2f", timeDrift))s")
                        }
                        
                        lastDurationCheckTime = Date()
                    }
                    
                    // Progress logging every 10 seconds
                    if Date().timeIntervalSince(lastProgressTime) >= 10.0 {
                        let remaining = durationSeconds - elapsed
                        print("🔄 Recording progress: \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", durationSeconds))s (\(String(format: "%.1f", remaining))s remaining)")
                        lastProgressTime = Date()
                    }
                    
                    // Enhanced debugging: Log detailed status every 30 seconds
                    if Date().timeIntervalSince(lastLogTime) >= 30.0 {
                        var memoryUsage = mach_task_basic_info()
                        var size = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
                        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryUsage) {
                            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                                task_info(mach_task_self_,
                                         task_flavor_t(MACH_TASK_BASIC_INFO),
                                         $0,
                                         &size)
                            }
                        }
                        
                        if kerr == KERN_SUCCESS {
                            let memoryMB = Double(memoryUsage.resident_size) / 1024.0 / 1024.0
                            print("📊 Status check at \(String(format: "%.1f", elapsed))s:")
                            print("   Memory usage: \(String(format: "%.1f", memoryMB))MB")
                            print("   Signal handler state: \(SignalHandler.shared.isHandling ? "active" : "inactive")")
                            print("   Should stop early: \(shouldStopEarly)")
                            print("   Iterations completed: \(iterationCount)")
                        }
                        lastLogTime = Date()
                    }
                    
                    iterationCount += 1
                    try await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms
                }
                
                let actualDuration = Date().timeIntervalSince(startTime)
                let actualEndTime = Date()
                let expectedDurationDiff = actualDuration - durationSeconds
                let timestampDiff = actualEndTime.timeIntervalSince(expectedEndTime)
                
                print("🏁 Recording duration analysis:")
                print("   Actual duration: \(String(format: "%.2f", actualDuration))s")
                print("   Target duration: \(String(format: "%.2f", durationSeconds))s")
                print("   Duration difference: \(String(format: "%.2f", expectedDurationDiff))s")
                print("   Expected end time: \(expectedEndTime)")
                print("   Actual end time: \(actualEndTime)")
                print("   Timestamp difference: \(String(format: "%.2f", timestampDiff))s")
                print("   Total iterations: \(iterationCount)")
                
                // 分析结束原因
                if shouldStopEarly {
                    print("⚠️ Recording ended early - Reason: \(earlyTerminationReason)")
                } else if abs(expectedDurationDiff) <= acceptableErrorMargin {
                    print("✅ Recording completed within acceptable margin (±\(acceptableErrorMargin)s)")
                } else if expectedDurationDiff > acceptableErrorMargin {
                    print("⚠️ Recording ran \(String(format: "%.2f", expectedDurationDiff))s longer than expected")
                } else {
                    print("⚠️ Recording ended \(String(format: "%.2f", -expectedDurationDiff))s earlier than expected")
                }
                
                // Clean up signal handler
                SignalHandler.shared.cleanup()
                
                if shouldStopEarly {
                    print("⚠️ Recording stopped early by: \(earlyTerminationReason)")
                    print("   Actual duration: \(String(format: "%.2f", actualDuration))s / Target: \(String(format: "%.2f", durationSeconds))s")
                    print("   Duration shortfall: \(String(format: "%.2f", durationSeconds - actualDuration))s")
                    print("   Timestamp difference: \(String(format: "%.2f", timestampDiff))s")
                    
                    // 提供诊断建议
                    if earlyTerminationReason.contains("Safety timeout") {
                        print("🔍 Analysis: Recording exceeded expected duration significantly")
                    } else if earlyTerminationReason.contains("Ctrl+C") {
                        print("🔍 Analysis: User manually interrupted the recording")
                    } else {
                        print("🔍 Analysis: Unexpected early termination - investigate signal sources")
                    }
                }
            }
            
            // Stop capture
            progressIndicator.updateProgress(message: "Stopping recording...")
            
            // Mark recording as complete to prevent signal handler interference
            isRecordingComplete = true
            
            print("🛑 Stopping capture stream...")
            
            // Stop the capture stream first
            try await captureController.stopCapture(captureStream!)
            
            print("📝 Marking inputs as finished...")
            
            // Mark inputs as finished after stopping capture
            videoInput.markAsFinished()
            if let audioInput = audioInput {
                audioInput.markAsFinished()
            }
            
            // Finalize output with timeout protection
            let finalizeStartTime = Date()
            print("💾 Starting file finalization...")
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // 文件写入任务
                    group.addTask {
                        try await self.outputManager.finalizeRecording(
                            writer: writer,
                            videoInput: videoInput,
                            audioInput: audioInput
                        )
                    }
                    
                    // 超时检查任务 (3秒超时)
                    group.addTask {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        throw NSError(domain: "FinalizationTimeout", code: -1, 
                                    userInfo: [NSLocalizedDescriptionKey: "文件写入超时"])
                    }
                    
                    try await group.next()
                    group.cancelAll()
                }
                let finalizeDuration = Date().timeIntervalSince(finalizeStartTime)
                print("✅ File finalization completed successfully in \(String(format: "%.2f", finalizeDuration))s")
            } catch {
                let finalizeDuration = Date().timeIntervalSince(finalizeStartTime)
                print("⚠️ 文件写入耗时: \(String(format: "%.2f", finalizeDuration))秒")
                if finalizeDuration >= 3.0 {
                    print("⚠️ 文件写入超时，文件可能不完整")
                }
            }
            
            // Complete progress indicator
            progressIndicator.stopProgress()
            
        } catch {
            // Handle errors and cleanup
            progressIndicator.stopProgressWithError(error)
            
            // Try to stop capture if it was started and not already complete
            if let stream = captureStream, !isRecordingComplete {
                do {
                    isRecordingComplete = true
                    try await captureController.stopCapture(stream)
                } catch {
                    print("⚠️ Error stopping capture during cleanup: \(error.localizedDescription)")
                }
            }
            
            throw error
        }
        
        // Clean up signal handler
        SignalHandler.shared.cleanup()
    }
    
    /// Resolve configuration by filling in screen and application details
    /// - Parameter config: Base configuration
    /// - Returns: Configuration with resolved screen and application info
    /// - Throws: Error if resolution fails
    private func resolveConfiguration(_ config: RecordingConfiguration) async throws -> RecordingConfiguration {
        var resolvedConfig = config
        
        // Resolve screen information
        if let targetScreen = config.targetScreen {
            // Screen already specified, validate it exists
            try displayManager.validateScreen(targetScreen.index)
        } else {
            // No screen specified, use default screen based on recording mode
            let screens = try displayManager.getAllScreens()
            let defaultScreen: ScreenInfo
            
            if config.targetApplication != nil {
                // For application recording, use primary screen
                defaultScreen = screens.first { $0.isPrimary } ?? screens[0]
            } else {
                // For screen recording, use the specified screen index from CLI (default 1)
                // This will be handled by ConfigurationManager, but for now use primary
                defaultScreen = screens.first { $0.isPrimary } ?? screens[0]
            }
            
            resolvedConfig = RecordingConfiguration(
                duration: config.duration,
                outputURL: config.outputURL,
                outputFormat: config.outputFormat,
                recordingArea: config.recordingArea,
                targetScreen: defaultScreen,
                targetApplication: config.targetApplication,
                audioSettings: config.audioSettings,
                videoSettings: config.videoSettings,
                countdown: config.countdown
            )
        }
        
        // Resolve application information if specified
        if let targetApp = config.targetApplication {
            // Validate the application is still running and suitable for recording
            try applicationManager.validateApplicationForRecording(targetApp)
        }
        
        // Update video settings with actual resolution
        let actualResolution: CGSize
        
        if resolvedConfig.recordingMode == .application, let targetApp = resolvedConfig.targetApplication {
            // 🔧 修复：应用录制的分辨率计算
            if let window = targetApp.windows.first {
                // 获取窗口所在屏幕的缩放因子
                let windowCenter = CGPoint(
                    x: window.frame.origin.x + window.frame.width / 2,
                    y: window.frame.origin.y + window.frame.height / 2
                )
                
                let screens = NSScreen.screens
                var scaleFactor: CGFloat = 1.0
                var containingScreen: NSScreen?
                
                for screen in screens {
                    if screen.frame.contains(windowCenter) {
                        scaleFactor = screen.backingScaleFactor
                        containingScreen = screen
                        break
                    }
                }
                
                if scaleFactor == 1.0 {
                    scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
                    containingScreen = NSScreen.main
                }
                
                // 🔧 关键修复：使用窗口的实际尺寸计算像素分辨率
                // 确保录制分辨率与窗口实际大小完全匹配
                let windowWidth = window.frame.width
                let windowHeight = window.frame.height
                
                // 计算像素分辨率
                actualResolution = CGSize(
                    width: windowWidth * scaleFactor,
                    height: windowHeight * scaleFactor
                )
                
                print("🔍 Application Resolution Calculation:")
                print("   Window frame: \(Int(window.frame.origin.x)), \(Int(window.frame.origin.y)), \(Int(windowWidth)) × \(Int(windowHeight))")
                print("   Containing screen: \(containingScreen?.localizedName ?? "Unknown")")
                print("   Scale factor: \(scaleFactor)x")
                print("   Final resolution: \(Int(actualResolution.width)) × \(Int(actualResolution.height)) pixels")
            } else {
                // Fallback if no windows found
                actualResolution = CGSize(width: 1920, height: 1080)
                print("⚠️ No windows found for application, using fallback resolution")
            }
        } else if let screen = resolvedConfig.targetScreen {
            // Screen recording - use screen-based calculation
            let recordingRect = resolvedConfig.recordingArea.toCGRect(for: screen)
            // recordingRect already includes scale factor from toCGRect, don't apply it again
            actualResolution = CGSize(
                width: recordingRect.width,
                height: recordingRect.height
            )
        } else {
            // Fallback resolution
            actualResolution = resolvedConfig.videoSettings.resolution
        }
        
        let updatedVideoSettings = VideoSettings(
            fps: resolvedConfig.videoSettings.fps,
            quality: resolvedConfig.videoSettings.quality,
            codec: resolvedConfig.videoSettings.codec,
            showCursor: resolvedConfig.videoSettings.showCursor,
            resolution: actualResolution
        )
        
        resolvedConfig = RecordingConfiguration(
            duration: resolvedConfig.duration,
            outputURL: resolvedConfig.outputURL,
            outputFormat: resolvedConfig.outputFormat,
            recordingArea: resolvedConfig.recordingArea,
            targetScreen: resolvedConfig.targetScreen,
            targetApplication: resolvedConfig.targetApplication,
            audioSettings: resolvedConfig.audioSettings,
            videoSettings: updatedVideoSettings,
            countdown: resolvedConfig.countdown
        )
        
        return resolvedConfig
    }
    
    // MARK: - List Operations
    
    /// List available screens
    /// - Parameter jsonOutput: Whether to output in JSON format
    /// - Throws: Error if screen listing fails
    func listScreens(jsonOutput: Bool = false) throws {
        try displayManager.listScreens(jsonOutput: jsonOutput)
    }
    
    /// List available applications
    /// - Parameter jsonOutput: Whether to output in JSON format
    /// - Throws: Error if application listing fails
    func listApplications(jsonOutput: Bool = false) throws {
        try applicationManager.listApplications(jsonOutput: jsonOutput)
    }
    
    // MARK: - Validation Methods
    
    /// Validate recording configuration
    /// - Parameter config: Configuration to validate
    /// - Throws: ValidationError if configuration is invalid
    func validateConfiguration(_ config: RecordingConfiguration) throws {
        // Validate duration (continuous recording mode uses -1.0, which is valid)
        if config.duration >= 0 && config.duration < 0.1 {
            throw ValidationError.invalidDuration(Int(config.duration * 1000))
        }
        
        // Validate screen if specified
        if let screenInfo = config.targetScreen {
            try displayManager.validateScreen(screenInfo.index)
        }
        
        // Validate application if specified
        if let appInfo = config.targetApplication {
            try applicationManager.validateApplicationForRecording(appInfo)
        }
        
        // Validate recording area
        if config.recordingMode == .screen {
            // Only validate against screen for screen recording
            let screenIndex = config.targetScreen?.index ?? 1
            try displayManager.validateArea(config.recordingArea, for: screenIndex)
        }
        // For application recording, we don't need to validate against screen bounds
        
        // Validate output path
        try outputManager.validateOutputPath(config.outputURL)
        
        // Validate video settings
        if !VideoSettings.validateFPS(config.videoSettings.fps) {
            throw ValidationError.invalidFPS(config.videoSettings.fps)
        }
        
        // Validate countdown
        if config.countdown < 0 {
            throw ValidationError.invalidCountdown(config.countdown)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Show countdown before recording starts
    /// - Parameter seconds: Number of seconds to count down
    private func showCountdown(_ seconds: Int) async throws {
        print("🕐 Starting countdown...")
        
        for i in (1...seconds).reversed() {
            print("   \(i)...")
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        print("🎬 Recording!")
    }
}


