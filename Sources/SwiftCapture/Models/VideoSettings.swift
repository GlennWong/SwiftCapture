import Foundation
import AVFoundation
import CoreGraphics

/// Video quality presets with appropriate bitrate settings
enum VideoQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// Bitrate multiplier for the quality level
    var bitRateMultiplier: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 4
        }
    }
    
    /// Base bitrate per pixel for 1080p at 30fps
    var baseBitRate: Int {
        switch self {
        case .low: return 2_000_000    // 2 Mbps - suitable for screen content
        case .medium: return 5_000_000 // 5 Mbps - balanced quality/size
        case .high: return 10_000_000  // 10 Mbps - high quality
        }
    }
    
    /// Quality-specific compression settings
    var compressionSettings: [String: Any] {
        switch self {
        case .low:
            return [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC,
                AVVideoMaxKeyFrameIntervalKey: 120 // More keyframes for better seeking
            ]
        case .medium:
            return [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoMaxKeyFrameIntervalKey: 90
            ]
        case .high:
            return [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoAllowFrameReorderingKey: true
            ]
        }
    }
}

/// Video recording settings with fps and quality controls
struct VideoSettings {
    /// Frames per second (15, 30, or 60)
    let fps: Int
    
    /// Video quality preset
    let quality: VideoQuality
    
    /// Video codec to use
    let codec: AVVideoCodecType
    
    /// Whether to show cursor in recording
    let showCursor: Bool
    
    /// Recording resolution
    let resolution: CGSize
    
    /// Calculate appropriate bitrate based on resolution, quality, and fps
    var bitRate: Int {
        let pixelCount = Int(resolution.width * resolution.height)
        let scaleFactor = Double(pixelCount) / (1920.0 * 1080.0) // Scale from 1080p baseline
        let adjustedBitRate = Double(quality.baseBitRate) * scaleFactor
        let fpsAdjustment = Double(fps) / 30.0 // Adjust for frame rate
        return Int(adjustedBitRate * fpsAdjustment)
    }
    
    /// Frame interval for ScreenCaptureKit configuration
    var frameInterval: CMTime {
        return CMTime(value: 1, timescale: CMTimeScale(fps))
    }
    
    /// Create comprehensive video settings dictionary for AVAssetWriter
    var avSettings: [String: Any] {
        var compressionProperties: [String: Any] = [:]
        
        // 🔧 修复：根据编解码器类型设置正确的压缩属性
        switch codec {
        case .h264:
            // H.264 特定设置
            compressionProperties = quality.compressionSettings
        case .hevc:
            // HEVC 特定设置 - 不使用 H.264 特定的属性
            switch quality {
            case .low:
                compressionProperties = [
                    AVVideoMaxKeyFrameIntervalKey: 120
                ]
            case .medium:
                compressionProperties = [
                    AVVideoMaxKeyFrameIntervalKey: 90
                ]
            case .high:
                compressionProperties = [
                    AVVideoMaxKeyFrameIntervalKey: 60,
                    AVVideoAllowFrameReorderingKey: true
                ]
            }
        default:
            // 其他编解码器的基本设置
            compressionProperties = [
                AVVideoMaxKeyFrameIntervalKey: fps * 3
            ]
        }
        
        // 添加通用设置
        compressionProperties[AVVideoAverageBitRateKey] = bitRate
        compressionProperties[AVVideoExpectedSourceFrameRateKey] = fps
        
        // Add fps-specific optimizations
        switch fps {
        case 15:
            // Lower frame rate - optimize for file size
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = 45 // 3 seconds at 15fps
        case 30:
            // Standard frame rate - balanced settings
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = 90 // 3 seconds at 30fps
        case 60:
            // High frame rate - optimize for smooth motion
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = 180 // 3 seconds at 60fps
            if quality == .high && codec == .h264 {
                compressionProperties[AVVideoAllowFrameReorderingKey] = true
            }
        default:
            // Fallback for any other fps values
            compressionProperties[AVVideoMaxKeyFrameIntervalKey] = fps * 3
        }
        
        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: Int(resolution.width),
            AVVideoHeightKey: Int(resolution.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
    }
    
    /// Validate fps value
    static func validateFPS(_ fps: Int) -> Bool {
        return [15, 30, 60].contains(fps)
    }
    
    /// Get recommended quality settings for given resolution and fps
    static func recommendedQuality(for resolution: CGSize, fps: Int) -> VideoQuality {
        let pixelCount = Int(resolution.width * resolution.height)
        
        // For very high resolutions or high fps, recommend lower quality to manage file size
        if pixelCount > 3840 * 2160 || fps == 60 {
            return .medium
        } else if pixelCount > 1920 * 1080 {
            return .medium
        } else {
            return .high
        }
    }
}

extension VideoSettings {
    /// Create default video settings
    /// - Parameters:
    ///   - fps: Frame rate (default: 30)
    ///   - quality: Video quality (default: medium)
    ///   - resolution: Recording resolution
    ///   - showCursor: Whether to show cursor (default: false)
    /// - Returns: VideoSettings instance
    static func `default`(fps: Int = 30, 
                         quality: VideoQuality = .medium, 
                         resolution: CGSize,
                         showCursor: Bool = false) -> VideoSettings {
        return VideoSettings(
            fps: fps,
            quality: quality,
            codec: .h264,
            showCursor: showCursor,
            resolution: resolution
        )
    }
    
    /// Create optimized video settings for specific output format
    /// - Parameters:
    ///   - fps: Frame rate
    ///   - quality: Video quality
    ///   - resolution: Recording resolution
    ///   - format: Output format to optimize for
    ///   - showCursor: Whether to show cursor (default: false)
    /// - Returns: VideoSettings optimized for the format
    static func optimized(fps: Int,
                         quality: VideoQuality,
                         resolution: CGSize,
                         for format: OutputFormat,
                         showCursor: Bool = false) -> VideoSettings {
        let codec = getOptimizedCodec(for: format, quality: quality, resolution: resolution)
        
        return VideoSettings(
            fps: fps,
            quality: quality,
            codec: codec,
            showCursor: showCursor,
            resolution: resolution
        )
    }
    
    /// Get optimized codec for format and settings
    /// - Parameters:
    ///   - format: Output format
    ///   - quality: Video quality
    ///   - resolution: Recording resolution
    /// - Returns: Recommended codec
    private static func getOptimizedCodec(for format: OutputFormat, quality: VideoQuality, resolution: CGSize) -> AVVideoCodecType {
        let pixelCount = Int(resolution.width * resolution.height)
        
        switch format {
        case .mov:
            // For MOV, we can use HEVC for high quality/resolution to save space
            if quality == .high && pixelCount > 1920 * 1080 {
                return .hevc // Better compression for high-res content
            } else {
                return .h264 // Standard choice for compatibility
            }
        case .mp4:
            // For MP4, stick with H.264 for maximum compatibility
            return .h264
        }
    }
}