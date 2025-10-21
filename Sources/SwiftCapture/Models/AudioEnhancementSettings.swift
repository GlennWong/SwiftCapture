import Foundation
import AVFoundation

/// Audio enhancement presets for different content types
enum AudioPreset: String, CaseIterable, Codable {
    case speech = "speech"      // 语音优化
    case music = "music"        // 音乐优化
    case gaming = "gaming"      // 游戏优化
    case balanced = "balanced"  // 平衡模式
    case custom = "custom"      // 自定义
    
    /// Get default settings for each preset
    var defaultSettings: AudioEnhancementSettings {
        switch self {
        case .speech:
            return AudioEnhancementSettings(
                masterGain: 3.0,
                autoGainEnabled: true,
                targetLUFS: -16.0,
                compressionRatio: 4.0,
                threshold: -18.0,
                attack: 3.0,
                release: 30.0,
                preset: .speech
            )
        case .music:
            return AudioEnhancementSettings(
                masterGain: 1.0,
                autoGainEnabled: true,
                targetLUFS: -14.0,
                compressionRatio: 2.5,
                threshold: -12.0,
                attack: 10.0,
                release: 100.0,
                preset: .music
            )
        case .gaming:
            return AudioEnhancementSettings(
                masterGain: 4.0,
                autoGainEnabled: true,
                targetLUFS: -18.0,
                compressionRatio: 3.5,
                threshold: -15.0,
                attack: 5.0,
                release: 50.0,
                preset: .gaming
            )
        case .balanced:
            return AudioEnhancementSettings(
                masterGain: 2.0,
                autoGainEnabled: true,
                targetLUFS: -16.0,
                compressionRatio: 3.0,
                threshold: -12.0,
                attack: 5.0,
                release: 50.0,
                preset: .balanced
            )
        case .custom:
            return AudioEnhancementSettings(preset: .custom)
        }
    }
}

/// Comprehensive audio enhancement configuration
struct AudioEnhancementSettings {
    // MARK: - Basic Gain Settings
    
    /// Master gain adjustment in dB (-20.0 to +20.0)
    var masterGain: Float
    
    /// Enable automatic gain control
    var autoGainEnabled: Bool
    
    /// Target loudness in LUFS (Loudness Units relative to Full Scale)
    var targetLUFS: Float
    
    // MARK: - Compressor Settings
    
    /// Compression ratio (1.0 = no compression, higher values = more compression)
    var compressionRatio: Float
    
    /// Compression threshold in dBFS (decibels relative to full scale)
    var threshold: Float
    
    /// Attack time in milliseconds (how quickly compression starts)
    var attack: Float
    
    /// Release time in milliseconds (how quickly compression stops)
    var release: Float
    
    // MARK: - Limiter Settings
    
    /// Limiter threshold in dBFS (prevents audio from exceeding this level)
    var limiterThreshold: Float
    
    /// Limiter release time in milliseconds
    var limiterRelease: Float
    
    // MARK: - Quality Protection
    
    /// Maximum allowed Total Harmonic Distortion + Noise (0.001 = 0.1%)
    var maxTHD: Float
    
    /// Enable quality protection mechanisms
    var qualityProtectionEnabled: Bool
    
    // MARK: - Processing Control
    
    /// Enable audio enhancement processing
    var processingEnabled: Bool
    
    /// Enable real-time quality monitoring
    var qualityMonitoringEnabled: Bool
    
    /// Enable lossless audio enhancement mode
    var losslessModeEnabled: Bool
    
    /// Enable quality comparison between original and processed audio
    var qualityComparisonEnabled: Bool
    
    // MARK: - Preset Configuration
    
    /// Current audio preset
    var preset: AudioPreset
    
    // MARK: - Initialization
    
    /// Initialize with default balanced settings
    init(
        masterGain: Float = 0.0,
        autoGainEnabled: Bool = true,
        targetLUFS: Float = -16.0,
        compressionRatio: Float = 3.0,
        threshold: Float = -12.0,
        attack: Float = 5.0,
        release: Float = 50.0,
        limiterThreshold: Float = -1.0,
        limiterRelease: Float = 10.0,
        maxTHD: Float = 0.001,
        qualityProtectionEnabled: Bool = true,
        processingEnabled: Bool = false,
        qualityMonitoringEnabled: Bool = true,
        losslessModeEnabled: Bool = false,
        qualityComparisonEnabled: Bool = true,
        preset: AudioPreset = .balanced
    ) {
        self.masterGain = max(-20.0, min(20.0, masterGain)) // Clamp to valid range
        self.autoGainEnabled = autoGainEnabled
        self.targetLUFS = targetLUFS
        self.compressionRatio = max(1.0, compressionRatio)
        self.threshold = max(-60.0, min(0.0, threshold))
        self.attack = max(0.1, attack)
        self.release = max(1.0, release)
        self.limiterThreshold = max(-10.0, min(0.0, limiterThreshold))
        self.limiterRelease = max(1.0, limiterRelease)
        self.maxTHD = max(0.0001, min(0.1, maxTHD))
        self.qualityProtectionEnabled = qualityProtectionEnabled
        self.processingEnabled = processingEnabled
        self.qualityMonitoringEnabled = qualityMonitoringEnabled
        self.losslessModeEnabled = losslessModeEnabled
        self.qualityComparisonEnabled = qualityComparisonEnabled
        self.preset = preset
    }
    
    // MARK: - Validation
    
    /// Validate all settings are within acceptable ranges
    var isValid: Bool {
        return masterGain >= -20.0 && masterGain <= 20.0 &&
               compressionRatio >= 1.0 &&
               threshold >= -60.0 && threshold <= 0.0 &&
               attack >= 0.1 &&
               release >= 1.0 &&
               limiterThreshold >= -10.0 && limiterThreshold <= 0.0 &&
               limiterRelease >= 1.0 &&
               maxTHD >= 0.0001 && maxTHD <= 0.1
    }
    
    /// Get validation errors if any
    var validationErrors: [String] {
        var errors: [String] = []
        
        if masterGain < -20.0 || masterGain > 20.0 {
            errors.append("Master gain must be between -20.0 and +20.0 dB")
        }
        
        if compressionRatio < 1.0 {
            errors.append("Compression ratio must be 1.0 or higher")
        }
        
        if threshold < -60.0 || threshold > 0.0 {
            errors.append("Threshold must be between -60.0 and 0.0 dBFS")
        }
        
        if attack < 0.1 {
            errors.append("Attack time must be at least 0.1 ms")
        }
        
        if release < 1.0 {
            errors.append("Release time must be at least 1.0 ms")
        }
        
        if limiterThreshold < -10.0 || limiterThreshold > 0.0 {
            errors.append("Limiter threshold must be between -10.0 and 0.0 dBFS")
        }
        
        if limiterRelease < 1.0 {
            errors.append("Limiter release time must be at least 1.0 ms")
        }
        
        if maxTHD < 0.0001 || maxTHD > 0.1 {
            errors.append("Maximum THD must be between 0.0001 and 0.1")
        }
        
        return errors
    }
}

// MARK: - AudioEnhancementSettings Extensions

extension AudioEnhancementSettings {
    
    /// Create settings from preset
    /// - Parameter preset: Audio preset to use
    /// - Returns: AudioEnhancementSettings configured for the preset
    static func from(preset: AudioPreset) -> AudioEnhancementSettings {
        return preset.defaultSettings
    }
    
    /// Apply preset while preserving custom overrides
    /// - Parameter preset: Preset to apply
    mutating func applyPreset(_ preset: AudioPreset) {
        let presetSettings = preset.defaultSettings
        
        // Only update if not in custom mode or explicitly changing preset
        if self.preset != .custom || preset != .custom {
            self.masterGain = presetSettings.masterGain
            self.autoGainEnabled = presetSettings.autoGainEnabled
            self.targetLUFS = presetSettings.targetLUFS
            self.compressionRatio = presetSettings.compressionRatio
            self.threshold = presetSettings.threshold
            self.attack = presetSettings.attack
            self.release = presetSettings.release
            self.limiterThreshold = presetSettings.limiterThreshold
            self.limiterRelease = presetSettings.limiterRelease
            self.maxTHD = presetSettings.maxTHD
            self.qualityProtectionEnabled = presetSettings.qualityProtectionEnabled
            self.preset = preset
        }
    }
    
    /// Create a copy with modified gain
    /// - Parameter gain: New master gain value
    /// - Returns: New AudioEnhancementSettings with updated gain
    func withGain(_ gain: Float) -> AudioEnhancementSettings {
        var settings = self
        settings.masterGain = max(-20.0, min(20.0, gain))
        settings.preset = .custom // Mark as custom when manually modified
        return settings
    }
    
    /// Create a copy with processing enabled/disabled
    /// - Parameter enabled: Whether to enable processing
    /// - Returns: New AudioEnhancementSettings with updated processing state
    func withProcessing(_ enabled: Bool) -> AudioEnhancementSettings {
        var settings = self
        settings.processingEnabled = enabled
        return settings
    }
    
    /// Create a copy with lossless mode enabled/disabled
    /// - Parameter enabled: Whether to enable lossless mode
    /// - Returns: New AudioEnhancementSettings with updated lossless mode state
    func withLosslessMode(_ enabled: Bool) -> AudioEnhancementSettings {
        var settings = self
        settings.losslessModeEnabled = enabled
        
        if enabled {
            // Apply lossless-friendly settings
            settings.compressionRatio = min(settings.compressionRatio, 1.5)
            settings.threshold = max(settings.threshold, -6.0)
            settings.limiterThreshold = max(settings.limiterThreshold, -0.5)
            settings.maxTHD = min(settings.maxTHD, 0.0005)
            settings.preset = .custom
        }
        
        return settings
    }
    
    /// Create a copy with quality comparison enabled/disabled
    /// - Parameter enabled: Whether to enable quality comparison
    /// - Returns: New AudioEnhancementSettings with updated quality comparison state
    func withQualityComparison(_ enabled: Bool) -> AudioEnhancementSettings {
        var settings = self
        settings.qualityComparisonEnabled = enabled
        return settings
    }
    
    /// Get lossless-optimized settings
    /// - Returns: AudioEnhancementSettings optimized for lossless processing
    func losslessOptimized() -> AudioEnhancementSettings {
        var settings = self
        settings.losslessModeEnabled = true
        settings.compressionRatio = 1.2 // Minimal compression
        settings.threshold = -3.0 // High threshold
        settings.attack = 1.0 // Fast attack
        settings.release = 20.0 // Quick release
        settings.limiterThreshold = -0.3 // Conservative limiting
        settings.limiterRelease = 5.0 // Fast limiter release
        settings.maxTHD = 0.0003 // Very strict THD limit
        settings.qualityProtectionEnabled = true
        settings.qualityComparisonEnabled = true
        settings.preset = .custom
        return settings
    }
}

// MARK: - Codable Support

extension AudioEnhancementSettings: Codable {
    
    enum CodingKeys: String, CodingKey {
        case masterGain
        case autoGainEnabled
        case targetLUFS
        case compressionRatio
        case threshold
        case attack
        case release
        case limiterThreshold
        case limiterRelease
        case maxTHD
        case qualityProtectionEnabled
        case processingEnabled
        case qualityMonitoringEnabled
        case losslessModeEnabled
        case qualityComparisonEnabled
        case preset
    }
}

// MARK: - Equatable Support

extension AudioEnhancementSettings: Equatable {
    static func == (lhs: AudioEnhancementSettings, rhs: AudioEnhancementSettings) -> Bool {
        return lhs.masterGain == rhs.masterGain &&
               lhs.autoGainEnabled == rhs.autoGainEnabled &&
               lhs.targetLUFS == rhs.targetLUFS &&
               lhs.compressionRatio == rhs.compressionRatio &&
               lhs.threshold == rhs.threshold &&
               lhs.attack == rhs.attack &&
               lhs.release == rhs.release &&
               lhs.limiterThreshold == rhs.limiterThreshold &&
               lhs.limiterRelease == rhs.limiterRelease &&
               lhs.maxTHD == rhs.maxTHD &&
               lhs.qualityProtectionEnabled == rhs.qualityProtectionEnabled &&
               lhs.processingEnabled == rhs.processingEnabled &&
               lhs.qualityMonitoringEnabled == rhs.qualityMonitoringEnabled &&
               lhs.losslessModeEnabled == rhs.losslessModeEnabled &&
               lhs.qualityComparisonEnabled == rhs.qualityComparisonEnabled &&
               lhs.preset == rhs.preset
    }
}