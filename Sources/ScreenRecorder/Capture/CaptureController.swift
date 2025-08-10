import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit
import CoreGraphics

/// Controls the actual screen capture process using ScreenCaptureKit
/// Extracted from LegacyScreenRecorder to provide modular recording functionality
@available(macOS 12.3, *)
class CaptureController {
    
    private var currentDelegate: CaptureDelegate?
    
    /// Error types for capture operations
    enum CaptureError: LocalizedError {
        case contentRetrievalFailed(Error)
        case streamCreationFailed(Error)
        case captureStartFailed(Error)
        case captureStopFailed(Error)
        case configurationError(String)
        
        var errorDescription: String? {
            switch self {
            case .contentRetrievalFailed(let error):
                return "Failed to retrieve shareable content: \(error.localizedDescription)"
            case .streamCreationFailed(let error):
                return "Failed to create capture stream: \(error.localizedDescription)"
            case .captureStartFailed(let error):
                return "Failed to start capture: \(error.localizedDescription)"
            case .captureStopFailed(let error):
                return "Failed to stop capture: \(error.localizedDescription)"
            case .configurationError(let message):
                return "Configuration error: \(message)"
            }
        }
    }
    
    /// Delegate for handling capture output
    private class CaptureDelegate: NSObject, SCStreamOutput {
        let videoInput: AVAssetWriterInput
        let audioInput: AVAssetWriterInput?
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let writer: AVAssetWriter
        private var startTime: CMTime?
        private var shouldStop = false
        private var frameCount = 0
        private var audioSampleCount = 0
        
        init(videoInput: AVAssetWriterInput, 
             audioInput: AVAssetWriterInput?, 
             adaptor: AVAssetWriterInputPixelBufferAdaptor, 
             writer: AVAssetWriter) {
            self.videoInput = videoInput
            self.audioInput = audioInput
            self.adaptor = adaptor
            self.writer = writer
        }
        
        func stopCapture() {
            shouldStop = true
        }
        
        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
            // Stop processing if we've been told to stop
            if shouldStop {
                return
            }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Initialize session timing on first frame
            if startTime == nil {
                startTime = timestamp
                writer.startSession(atSourceTime: startTime!)
            }
            
            // Don't check duration here - let the main recording loop handle timing
            
            switch outputType {
            case .screen:
                guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
                

                
                if videoInput.isReadyForMoreMediaData && !shouldStop {
                    let success = adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                    frameCount += 1
                    if !success {
                        print("⚠️ Failed to append video frame at timestamp: \(CMTimeGetSeconds(timestamp))")
                    }
                }
            case .audio:
                if let audioInput = audioInput, audioInput.isReadyForMoreMediaData && !shouldStop {
                    let success = audioInput.append(sampleBuffer)
                    audioSampleCount += 1
                    if !success {
                        print("⚠️ Failed to append audio sample at timestamp: \(CMTimeGetSeconds(timestamp))")
                    }
                }
            default:
                break
            }
        }
    }
    
    /// Start screen capture with the given configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - writer: AVAssetWriter for output
    ///   - videoInput: Video input for the writer
    ///   - audioInput: Optional audio input for the writer
    ///   - adaptor: Pixel buffer adaptor for video
    /// - Returns: SCStream instance for the capture
    /// - Throws: CaptureError if capture setup fails
    func startCapture(
        with config: RecordingConfiguration,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) async throws -> SCStream {
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.contentRetrievalFailed(error)
        }
        
        // Create stream configuration
        let streamConfig = try createStreamConfiguration(from: config, content: content)
        
        // Create content filter
        let filter = try createContentFilter(from: config, content: content)
        
        // Create capture delegate
        let delegate = CaptureDelegate(
            videoInput: videoInput,
            audioInput: audioInput,
            adaptor: adaptor,
            writer: writer
        )
        
        // Store delegate reference for later use
        self.currentDelegate = delegate
        
        // Create stream
        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        
        // Add stream outputs
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
        let audioQueue = DispatchQueue(label: "audioQueue", qos: .userInitiated)
        
        do {
            try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: videoQueue)
        } catch {
            throw CaptureError.captureStartFailed(error)
        }
        
        // Add audio output if enabled
        if config.audioSettings.hasAudio {
            do {
                if #available(macOS 13.0, *) {
                    try stream.addStreamOutput(delegate, type: .audio, sampleHandlerQueue: audioQueue)
                }
            } catch {
                print("⚠️ Warning: Failed to add audio output: \(error.localizedDescription)")
                // Continue without audio rather than failing completely
            }
        }
        
        // Start capture
        do {
            try await stream.startCapture()
        } catch {
            throw CaptureError.captureStartFailed(error)
        }
        
        return stream
    }
    
    /// Stop screen capture
    /// - Parameter stream: SCStream to stop
    /// - Throws: CaptureError if stop fails
    func stopCapture(_ stream: SCStream) async throws {
        // First tell the delegate to stop processing new frames
        currentDelegate?.stopCapture()
        
        do {
            try await stream.stopCapture()
        } catch {
            throw CaptureError.captureStopFailed(error)
        }
        
        // Clear delegate reference
        currentDelegate = nil
    }
    
    /// Create ScreenCaptureKit stream configuration from recording configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content for validation
    /// - Returns: Configured SCStreamConfiguration
    /// - Throws: CaptureError if configuration is invalid
    private func createStreamConfiguration(
        from config: RecordingConfiguration, 
        content: SCShareableContent
    ) throws -> SCStreamConfiguration {
        
        let streamConfig = SCStreamConfiguration()
        
        // Configure recording area and resolution
        let (sourceRect, outputSize) = try calculateRecordingDimensions(
            config: config, 
            content: content
        )
        
        streamConfig.sourceRect = sourceRect
        streamConfig.width = Int(outputSize.width)
        streamConfig.height = Int(outputSize.height)
        
        // Configure video settings
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.minimumFrameInterval = config.videoSettings.frameInterval
        streamConfig.showsCursor = config.videoSettings.showCursor
        
        // 🔧 修复：对于应用录制的特殊配置
        if config.recordingMode == .application {
            // 应用录制时的关键设置
            streamConfig.scalesToFit = false  // 禁用自动缩放
            
            // 版本兼容的设置
            if #available(macOS 14.0, *) {
                streamConfig.preservesAspectRatio = true  // 保持宽高比
                streamConfig.captureResolution = .best
            }
            
            // 对于应用录制，不设置sourceRect，让系统自动处理
            if sourceRect == CGRect.null {
                // 不设置sourceRect，使用完整窗口
                print("   Using full window capture (no sourceRect)")
            }
        } else {
            // 屏幕录制时保持原有设置
            streamConfig.scalesToFit = false
        }
        
        // Configure color space and quality
        streamConfig.colorSpaceName = CGColorSpace.displayP3
        streamConfig.backgroundColor = CGColor.clear
        
        // Configure advanced settings for macOS 14+
        if #available(macOS 14.0, *) {
            streamConfig.queueDepth = 8
        }
        
        // Configure audio if enabled
        if config.audioSettings.hasAudio {
            if #available(macOS 13.0, *) {
                streamConfig.capturesAudio = true
            }
        }
        
        print("📹 Capture Configuration:")
        print("   Source Rect: \(sourceRect)")
        print("   Output Size: \(Int(outputSize.width)) × \(Int(outputSize.height))")
        print("   Frame Rate: \(config.videoSettings.fps) fps")
        print("   Show Cursor: \(config.videoSettings.showCursor)")
        print("   Audio Enabled: \(config.audioSettings.hasAudio)")
        
        return streamConfig
    }
    
    /// Create content filter based on recording configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content
    /// - Returns: Configured SCContentFilter
    /// - Throws: CaptureError if filter creation fails
    private func createContentFilter(
        from config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> SCContentFilter {
        
        switch config.recordingMode {
        case .screen:
            // Screen recording mode
            let targetDisplay: SCDisplay
            
            if let screenInfo = config.targetScreen {
                // Find the display matching the screen info
                guard let display = content.displays.first(where: { $0.displayID == screenInfo.displayID }) else {
                    throw CaptureError.configurationError("Target screen not found in available displays")
                }
                targetDisplay = display
            } else {
                // Use primary display
                guard let display = content.displays.first else {
                    throw CaptureError.configurationError("No displays available for recording")
                }
                targetDisplay = display
            }
            
            return SCContentFilter(display: targetDisplay, excludingWindows: [])
            
        case .application:
            // Application recording mode
            guard let targetApp = config.targetApplication else {
                throw CaptureError.configurationError("No target application specified for application recording")
            }
            
            // Find the application in shareable content
            guard content.applications.contains(where: { 
                $0.bundleIdentifier == targetApp.bundleIdentifier 
            }) else {
                throw CaptureError.configurationError("Target application not found in shareable content")
            }
            
            // Get windows for the application
            let appWindows = content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
            }
            
            if appWindows.isEmpty {
                throw CaptureError.configurationError("No windows found for target application")
            }
            
            return SCContentFilter(desktopIndependentWindow: appWindows.first!)
        }
    }
    
    /// Calculate recording dimensions based on configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content for screen information
    /// - Returns: Tuple of source rect and output size
    /// - Throws: CaptureError if calculation fails
    private func calculateRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        switch config.recordingMode {
        case .screen:
            return try calculateScreenRecordingDimensions(config: config, content: content)
        case .application:
            return try calculateApplicationRecordingDimensions(config: config, content: content)
        }
    }
    
    /// Calculate dimensions for screen recording
    private func calculateScreenRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        let targetDisplay: SCDisplay
        
        if let screenInfo = config.targetScreen {
            guard let display = content.displays.first(where: { $0.displayID == screenInfo.displayID }) else {
                throw CaptureError.configurationError("Target screen not found")
            }
            targetDisplay = display
        } else {
            guard let display = content.displays.first else {
                throw CaptureError.configurationError("No displays available")
            }
            targetDisplay = display
        }
        
        // Get screen information from NSScreen for scale factor
        let screens = NSScreen.screens
        guard let nsScreen = screens.first(where: { 
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == targetDisplay.displayID 
        }) else {
            throw CaptureError.configurationError("Could not find NSScreen for display")
        }
        
        let scaleFactor = nsScreen.backingScaleFactor
        let logicalFrame = nsScreen.frame
        
        // Calculate recording area (now in pixel coordinates)
        let recordingRect = config.recordingArea.toCGRect(for: ScreenInfo(
            index: 1,
            displayID: targetDisplay.displayID,
            frame: logicalFrame,
            name: "Display",
            isPrimary: true,
            scaleFactor: scaleFactor
        ))
        
        // Recording rect is already in pixel coordinates, no need to multiply by scale factor
        let actualWidth = Int(recordingRect.width)
        let actualHeight = Int(recordingRect.height)
        
        // Convert pixel coordinates back to logical coordinates for ScreenCaptureKit
        let logicalSourceRect = CGRect(
            x: recordingRect.origin.x / scaleFactor,
            y: recordingRect.origin.y / scaleFactor,
            width: recordingRect.width / scaleFactor,
            height: recordingRect.height / scaleFactor
        )
        
        return (
            sourceRect: logicalSourceRect,
            outputSize: CGSize(width: actualWidth, height: actualHeight)
        )
    }
    
    /// Calculate dimensions for application recording
    private func calculateApplicationRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        guard let targetApp = config.targetApplication else {
            throw CaptureError.configurationError("No target application specified")
        }
        
        // Find application windows in ScreenCaptureKit content
        let appWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
        }
        
        guard let scWindow = appWindows.first else {
            throw CaptureError.configurationError("No windows found for target application")
        }
        
        // Get the ScreenCaptureKit window frame (this is already in the correct coordinate system)
        let scWindowFrame = scWindow.frame
        
        // Find the display that contains this window to get the correct scale factor
        let windowCenter = CGPoint(
            x: scWindowFrame.origin.x + scWindowFrame.width / 2,
            y: scWindowFrame.origin.y + scWindowFrame.height / 2
        )
        
        // Get the display containing the window center
        let screens = NSScreen.screens
        var scaleFactor: CGFloat = 1.0
        var containingScreen: NSScreen?
        
        for screen in screens {
            // Convert screen frame to match ScreenCaptureKit coordinate system
            let screenFrame = screen.frame
            let flippedScreenFrame = CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: screenFrame.height
            )
            
            if flippedScreenFrame.contains(windowCenter) {
                scaleFactor = screen.backingScaleFactor
                containingScreen = screen
                break
            }
        }
        
        // If no screen contains the window center, use the main screen's scale factor
        if scaleFactor == 1.0 {
            scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
            containingScreen = NSScreen.main
        }
        
        // 🔧 修复：使用ScreenCaptureKit窗口的实际尺寸
        // ScreenCaptureKit已经提供了正确的窗口边界，不需要额外的坐标转换
        let actualWidth = scWindowFrame.width
        let actualHeight = scWindowFrame.height
        
        // 计算输出像素尺寸 - 使用实际窗口尺寸乘以缩放因子
        let outputWidth = Int(actualWidth * scaleFactor)
        let outputHeight = Int(actualHeight * scaleFactor)
        
        print("🔍 Application Recording Debug:")
        print("   SCWindow Frame: \(Int(scWindowFrame.origin.x)), \(Int(scWindowFrame.origin.y)), \(Int(actualWidth)) × \(Int(actualHeight))")
        print("   Scale Factor: \(scaleFactor)x")
        print("   Output Size (pixels): \(outputWidth) × \(outputHeight)")
        print("   Containing Screen: \(containingScreen?.localizedName ?? "Unknown")")
        
        // 🔧 关键修复：不使用sourceRect，让ScreenCaptureKit自动处理窗口边界
        // 对于应用窗口录制，sourceRect应该设置为CGRect.null或窗口的完整区域
        return (
            sourceRect: CGRect.null, // 让ScreenCaptureKit自动使用完整窗口区域
            outputSize: CGSize(width: outputWidth, height: outputHeight)
        )
    }
}