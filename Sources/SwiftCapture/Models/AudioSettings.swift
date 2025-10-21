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
    
    /// Force system-wide audio recording (for app recording)
    let forceSystemAudio: Bool
    
    /// Audio quality preset
    let quality: AudioQuality
    
    /// Sample rate in Hz
    let sampleRate: Double
    
    /// Bit rate in bits per second
    let bitRate: Int
    
    /// Number of audio channels
    let channels: Int
    
    /// Audio enhancement settings
    let enhancementSettings: AudioEnhancementSettings
    
    /// Enable quality monitoring during recording
    let qualityMonitoringEnabled: Bool
    
    /// Enable audio processing
    let processingEnabled: Bool
    
    /// Create audio settings dictionary for AVAssetWriter
    var avSettings: [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: bitRate,
            AVNumberOfChannelsKey: channels
        ]
    }
    
    /// Create enhanced audio settings dictionary with higher quality for processed audio
    var enhancedAVSettings: [String: Any] {
        var settings = avSettings
        
        // Use higher bit rate for enhanced audio to accommodate processing
        let enhancedBitRate = min(bitRate * 2, 320_000) // Maximum 320kbps
        settings[AVEncoderBitRateKey] = enhancedBitRate
        
        // Enable high quality encoding
        settings[AVEncoderAudioQualityKey] = AVAudioQuality.max.rawValue
        
        return settings
    }
}

extension AudioSettings {
    /// Create default audio settings
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone (default: false)
    ///   - includeSystemAudio: Whether to include system audio (default: true)
    ///   - forceSystemAudio: Force system-wide audio recording (default: false)
    ///   - quality: Audio quality (default: medium)
    ///   - enhancementSettings: Audio enhancement configuration (default: disabled)
    ///   - qualityMonitoringEnabled: Enable quality monitoring (default: true)
    ///   - processingEnabled: Enable audio processing (default: false)
    /// - Returns: AudioSettings instance
    static func `default`(includeMicrophone: Bool = false,
                         includeSystemAudio: Bool = true,
                         forceSystemAudio: Bool = false,
                         quality: AudioQuality = .medium,
                         enhancementSettings: AudioEnhancementSettings = AudioEnhancementSettings(),
                         qualityMonitoringEnabled: Bool = true,
                         processingEnabled: Bool = false) -> AudioSettings {
        return AudioSettings(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: includeSystemAudio,
            forceSystemAudio: forceSystemAudio,
            quality: quality,
            sampleRate: quality.sampleRate,
            bitRate: quality.bitRate,
            channels: 2, // Stereo
            enhancementSettings: enhancementSettings,
            qualityMonitoringEnabled: qualityMonitoringEnabled,
            processingEnabled: processingEnabled
        )
    }
    
    /// Create audio settings with enhancement enabled
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone
    ///   - includeSystemAudio: Whether to include system audio
    ///   - forceSystemAudio: Force system-wide audio recording
    ///   - quality: Audio quality
    ///   - preset: Audio enhancement preset
    ///   - gain: Master gain in dB (optional override)
    /// - Returns: AudioSettings with enhancement enabled
    static func withEnhancement(includeMicrophone: Bool = false,
                               includeSystemAudio: Bool = true,
                               forceSystemAudio: Bool = false,
                               quality: AudioQuality = .medium,
                               preset: AudioPreset = .balanced,
                               gain: Float? = nil) -> AudioSettings {
        var enhancementSettings = AudioEnhancementSettings.from(preset: preset)
        enhancementSettings.processingEnabled = true
        
        if let customGain = gain {
            enhancementSettings = enhancementSettings.withGain(customGain)
        }
        
        return AudioSettings(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: includeSystemAudio,
            forceSystemAudio: forceSystemAudio,
            quality: quality,
            sampleRate: quality.sampleRate,
            bitRate: quality.bitRate,
            channels: 2,
            enhancementSettings: enhancementSettings,
            qualityMonitoringEnabled: true,
            processingEnabled: true
        )
    }
    
    /// Check if any audio recording is enabled
    var hasAudio: Bool {
        return includeMicrophone || includeSystemAudio
    }
    
    /// Check if audio enhancement is active
    var hasEnhancement: Bool {
        return processingEnabled && enhancementSettings.processingEnabled
    }
    
    /// Get the appropriate AVSettings based on whether enhancement is enabled
    var finalAVSettings: [String: Any] {
        return hasEnhancement ? enhancedAVSettings : avSettings
    }
}