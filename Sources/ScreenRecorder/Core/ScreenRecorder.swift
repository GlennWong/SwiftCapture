import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation

/// Main screen recorder class that coordinates all recording components
/// This replaces the LegacyScreenRecorder with a modular architecture
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
        
        // Start progress indicator
        let progressIndicator = ProgressIndicator.startRecording(
            outputURL: finalConfig.outputURL,
            duration: finalConfig.duration
        )
        
        // Setup graceful shutdown handling
        var captureStream: SCStream?
        SignalHandler.shared.setupForRecording(progressIndicator: progressIndicator) {
            // Graceful shutdown callback
            if let stream = captureStream {
                do {
                    try await self.captureController.stopCapture(stream)
                } catch {
                    print("⚠️ Error during graceful shutdown: \(error.localizedDescription)")
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
            
            // Record for the specified duration
            let durationNanoseconds = UInt64(finalConfig.duration * 1_000_000_000)
            try await Task.sleep(nanoseconds: durationNanoseconds)
            
            // Stop capture
            progressIndicator.updateProgress(message: "Stopping recording...")
            try await captureController.stopCapture(captureStream!)
            
            // Finalize output
            try await outputManager.finalizeRecording(
                writer: writer,
                videoInput: videoInput,
                audioInput: audioInput
            )
            
            // Complete progress indicator
            progressIndicator.stopProgress()
            
        } catch {
            // Handle errors and cleanup
            progressIndicator.stopProgressWithError(error)
            
            // Try to stop capture if it was started
            if let stream = captureStream {
                do {
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
        if let screen = resolvedConfig.targetScreen {
            let recordingRect = resolvedConfig.recordingArea.toCGRect(for: screen)
            let actualResolution = CGSize(
                width: recordingRect.width * screen.scaleFactor,
                height: recordingRect.height * screen.scaleFactor
            )
            
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
        }
        
        return resolvedConfig
    }
    
    // MARK: - List Operations
    
    /// List available screens
    /// - Throws: Error if screen listing fails
    func listScreens() throws {
        try displayManager.listScreens()
    }
    
    /// List available applications
    /// - Throws: Error if application listing fails
    func listApplications() throws {
        try applicationManager.listApplications()
    }
    
    // MARK: - Validation Methods
    
    /// Validate recording configuration
    /// - Parameter config: Configuration to validate
    /// - Throws: ValidationError if configuration is invalid
    func validateConfiguration(_ config: RecordingConfiguration) throws {
        // Validate duration
        if config.duration < 0.1 {
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
        let screenIndex = config.targetScreen?.index ?? 1
        try displayManager.validateArea(config.recordingArea, for: screenIndex)
        
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

// MARK: - Legacy Compatibility

/// Legacy compatibility wrapper for existing code
/// This allows gradual migration from LegacyScreenRecorder
@available(macOS 12.3, *)
extension ScreenRecorder {
    
    /// Legacy record method for backward compatibility
    /// - Parameters:
    ///   - durationMs: Duration in milliseconds
    ///   - outputPath: Optional output path
    ///   - fullScreen: Whether to record full screen
    ///   - fps: Frame rate
    ///   - quality: Video quality
    ///   - format: Output format
    ///   - showCursor: Whether to show cursor
    static func record(
        durationMs: Int,
        outputPath: String?,
        fullScreen: Bool,
        fps: Int = 30,
        quality: VideoQuality = .medium,
        format: OutputFormat = .mov,
        showCursor: Bool = false
    ) async {
        let recorder = ScreenRecorder()
        
        do {
            // Convert legacy parameters to new configuration
            let outputURL = try recorder.outputManager.generateOutputURL(from: outputPath, format: format)
            
            // For legacy compatibility, assume second screen (index 2) if available
            let screens = try recorder.displayManager.getAllScreens()
            let targetScreen = screens.count >= 2 ? screens[1] : screens[0]
            
            let recordingArea: RecordingArea = fullScreen ? .fullScreen : .centered(width: Int(targetScreen.frame.height * 3 / 4), height: Int(targetScreen.frame.height))
            
            let config = RecordingConfiguration(
                duration: Double(durationMs) / 1000.0,
                outputURL: outputURL,
                outputFormat: format,
                recordingArea: recordingArea,
                targetScreen: targetScreen,
                targetApplication: nil,
                audioSettings: .default(includeSystemAudio: true),
                videoSettings: VideoSettings(
                    fps: fps,
                    quality: quality,
                    codec: .h264,
                    showCursor: showCursor,
                    resolution: CGSize(
                        width: recordingArea == .fullScreen ? targetScreen.frame.width * targetScreen.scaleFactor : targetScreen.frame.height * targetScreen.scaleFactor * 3 / 4,
                        height: targetScreen.frame.height * targetScreen.scaleFactor
                    )
                ),
                countdown: 0
            )
            
            try await recorder.record(with: config)
            
        } catch {
            print("❌ Recording failed: \(error.localizedDescription)")
        }
    }
}