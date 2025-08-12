import Foundation
import AVFoundation

/// Audio quality presets
enum AudioQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// Sample rate for the quality level
    var sampleRate: Double {
        switch self {
        case .low: return 22050.0
        case .medium: return 44100.0
        case .high: return 48000.0
        }
    }
    
    /// Bit rate for the quality level
    var bitRate: Int {
        switch self {
        case .low: return 64_000    // 64 kbps
        case .medium: return 128_000 // 128 kbps
        case .high: return 192_000   // 192 kbps
        }
    }
}

/// Audio recording settings
struct AudioSettings {
    /// Whether to include microphone audio
    let includeMicrophone: Bool
    
    /// Whether to include system audio
    let includeSystemAudio: Bool
    
    /// Audio quality preset
    let quality: AudioQuality
    
    /// Sample rate in Hz
    let sampleRate: Double
    
    /// Bit rate in bits per second
    let bitRate: Int
    
    /// Number of audio channels
    let channels: Int
    
    /// Create audio settings dictionary for AVAssetWriter
    var avSettings: [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitRate,
            AVNumberOfChannelsKey: channels
        ]
    }
}

extension AudioSettings {
    /// Create default audio settings
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone (default: false)
    ///   - includeSystemAudio: Whether to include system audio (default: true)
    ///   - quality: Audio quality (default: medium)
    /// - Returns: AudioSettings instance
    static func `default`(includeMicrophone: Bool = false,
                         includeSystemAudio: Bool = true,
                         quality: AudioQuality = .medium) -> AudioSettings {
        return AudioSettings(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: includeSystemAudio,
            quality: quality,
            sampleRate: quality.sampleRate,
            bitRate: quality.bitRate,
            channels: 2 // Stereo
        )
    }
    
    /// Check if any audio recording is enabled
    var hasAudio: Bool {
        return includeMicrophone || includeSystemAudio
    }
}