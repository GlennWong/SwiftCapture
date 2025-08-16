import Foundation
import AVFoundation
import CoreGraphics

/// Output format for recordings
enum OutputFormat: String, CaseIterable {
    case mov = "mov"
    case mp4 = "mp4"
    
    /// File extension for the format
    var fileExtension: String {
        return rawValue
    }
    
    /// AVFileType for the format
    var avFileType: AVFileType {
        switch self {
        case .mov: return .mov
        case .mp4: return .mp4
        }
    }
    
    /// Recommended codec for the format
    var recommendedCodec: AVVideoCodecType {
        switch self {
        case .mov:
            // MOV supports both H.264 and HEVC, prefer H.264 for compatibility
            return .h264
        case .mp4:
            // Legacy case - should not be used since format is fixed to MOV
            return .h264
        }
    }
    
    /// Alternative codecs supported by the format
    var supportedCodecs: [AVVideoCodecType] {
        switch self {
        case .mov:
            // MOV is more flexible and supports more codecs
            return [.h264, .hevc, .proRes422, .proRes4444]
        case .mp4:
            // Legacy case - should not be used since format is fixed to MOV
            return [.h264, .hevc]
        }
    }
    
    /// Format-specific optimization settings
    var optimizationSettings: [String: Any] {
        switch self {
        case .mov:
            // MOV format optimizations for macOS
            return [
                "fastStart": false, // MOV doesn't need fast start optimization
                "fragmentedMP4": false
            ]
        case .mp4:
            // Legacy case - should not be used since format is fixed to MOV
            return [
                "fastStart": true,
                "fragmentedMP4": false
            ]
        }
    }
    
    /// Check if codec is compatible with this format
    /// - Parameter codec: Video codec to check
    /// - Returns: true if compatible, false otherwise
    func isCompatible(with codec: AVVideoCodecType) -> Bool {
        return supportedCodecs.contains(codec)
    }
    
    /// Get format description for user display
    var description: String {
        switch self {
        case .mov:
            return "MOV (QuickTime) - macOS native format, high quality"
        case .mp4:
            return "MP4 (MPEG-4) - legacy format, not used"
        }
    }
}

/// Complete configuration for a recording session
struct RecordingConfiguration {
    /// Recording duration in seconds
    let duration: TimeInterval
    
    /// Output file URL
    let outputURL: URL
    
    /// Output format
    let outputFormat: OutputFormat
    
    /// Area to record
    let recordingArea: RecordingArea
    
    /// Target screen (nil for primary screen)
    let targetScreen: ScreenInfo?
    
    /// Target application (nil for screen recording)
    let targetApplication: ApplicationInfo?
    
    /// Audio recording settings
    let audioSettings: AudioSettings
    
    /// Video recording settings
    let videoSettings: VideoSettings
    
    /// Countdown before recording starts (in seconds)
    let countdown: Int
    
    /// Recording mode based on configuration
    var recordingMode: RecordingMode {
        if targetApplication != nil {
            return .application
        } else {
            return .screen
        }
    }
}

/// Recording mode enumeration
enum RecordingMode {
    case screen
    case application
}

extension RecordingConfiguration {
    /// Create a default configuration
    /// - Parameters:
    ///   - duration: Recording duration in seconds (default: 10)
    ///   - outputURL: Output file URL
    ///   - resolution: Recording resolution
    /// - Returns: RecordingConfiguration with default settings
    static func `default`(duration: TimeInterval = 10.0,
                         outputURL: URL,
                         resolution: CGSize) -> RecordingConfiguration {
        return RecordingConfiguration(
            duration: duration,
            outputURL: outputURL,
            outputFormat: .mov,
            recordingArea: .fullScreen,
            targetScreen: nil,
            targetApplication: nil,
            audioSettings: .default(),
            videoSettings: .default(resolution: resolution),
            countdown: 0
        )
    }
}

extension RecordingConfiguration: CustomStringConvertible {
    var description: String {
        var components: [String] = []
        
        components.append("Duration: \(duration)s")
        components.append("Output: \(outputURL.lastPathComponent)")
        components.append("Format: \(outputFormat.rawValue.uppercased())")
        components.append("Area: \(recordingArea)")
        
        if let screen = targetScreen {
            components.append("Screen: \(screen.name)")
        }
        
        if let app = targetApplication {
            components.append("Application: \(app.name)")
        }
        
        components.append("Video: \(videoSettings.fps)fps, \(videoSettings.quality.rawValue)")
        components.append("Audio: \(audioSettings.hasAudio ? "enabled" : "disabled")")
        
        if countdown > 0 {
            components.append("Countdown: \(countdown)s")
        }
        
        return components.joined(separator: ", ")
    }
}