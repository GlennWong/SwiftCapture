import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation

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
        
        // Setup graceful shutdown handling (only for timed recordings)
        var captureStream: SCStream?
        var isRecordingComplete = false
        
        // For timed recordings, set up signal handler here
        if finalConfig.duration >= 0 {
            SignalHandler.shared.setupForRecording(progressIndicator: progressIndicator) {
                // Graceful shutdown callback
                if let stream = captureStream, !isRecordingComplete {
                    do {
                        try await self.captureController.stopCapture(stream)
                    } catch {
                        print("⚠️ Error during graceful shutdown: \(error.localizedDescription)")
                    }
                }
            }
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
                        // Use a semaphore to ensure finalization completes before exit
                        let finalizationSemaphore = DispatchSemaphore(value: 0)
                        var finalizationError: Error?
                        
                        Task {
                            do {
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
                                do {
                                    try await self.outputManager.finalizeRecording(
                                        writer: writer,
                                        videoInput: videoInput,
                                        audioInput: audioInput
                                    )
                                    let finalizeDuration = Date().timeIntervalSince(finalizeStartTime)
                                    print("✅ File finalized successfully in \(String(format: "%.2f", finalizeDuration))s")
                                } catch {
                                    let finalizeDuration = Date().timeIntervalSince(finalizeStartTime)
                                    print("⚠️ Error finalizing recording after \(String(format: "%.2f", finalizeDuration))s: \(error.localizedDescription)")
                                    print("📁 Note: Video file may be corrupted")
                                    finalizationError = error
                                }
                                
                                // Complete progress indicator
                                progressIndicator.stopProgress()
                                
                            } catch {
                                finalizationError = error
                                print("⚠️ Unexpected error during finalization: \(error.localizedDescription)")
                            }
                            
                            // Signal that finalization is complete
                            finalizationSemaphore.signal()
                        }
                        
                        // Wait for finalization to complete with timeout
                        let timeoutResult = finalizationSemaphore.wait(timeout: .now() + 8.0)
                        
                        if timeoutResult == .timedOut {
                            print("⚠️ Finalization timed out - file may be incomplete")
                        }
                        
                        // Resume continuation to exit the wait
                        if let error = finalizationError {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                
                // For continuous recording, the finalization is handled in the signal handler
                // so we skip the normal finalization flow below
                
            } else {
                // Timed recording mode - wait for the exact duration
                let durationSeconds = finalConfig.duration
                let durationNanoseconds = UInt64(durationSeconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: durationNanoseconds)
            }
            
            // Stop capture
            progressIndicator.updateProgress(message: "Stopping recording...")
            
            // Mark recording as complete to prevent signal handler interference
            isRecordingComplete = true
            
            // Stop the capture stream first
            try await captureController.stopCapture(captureStream!)
            
            // Mark inputs as finished after stopping capture
            videoInput.markAsFinished()
            if let audioInput = audioInput {
                audioInput.markAsFinished()
            }
            
            // Finalize output with timeout protection
            let finalizeStartTime = Date()
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


