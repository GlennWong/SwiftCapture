import Foundation
import CoreGraphics

/// Manages recording configurations, presets, and parameter validation
class ConfigurationManager {
    
    private let validator: ParameterValidator
    private let presetStorage: PresetStorage
    private let audioPresetManager: AudioPresetManager
    
    /// Initialize configuration manager
    /// - Throws: Error if preset storage cannot be initialized
    init() throws {
        self.validator = ParameterValidator()
        self.presetStorage = try PresetStorage()
        self.audioPresetManager = try AudioPresetManager()
    }
    
    /// Create recording configuration from CLI command
    /// - Parameter command: SwiftCaptureCommand with CLI options
    /// - Returns: Validated RecordingConfiguration
    /// - Throws: ValidationError if any parameters are invalid
    func createConfiguration(from command: SwiftCaptureCommand) throws -> RecordingConfiguration {
        
        // Start with preset if specified
        var baseConfig: RecordingConfiguration?
        if let presetName = command.preset {
            let preset = try presetStorage.loadPreset(named: presetName)
            // Create a temporary output URL for preset conversion
            let tempURL = URL(fileURLWithPath: "/tmp/temp.mov")
            baseConfig = try preset.toRecordingConfiguration(outputURL: tempURL)
        }
        
        // Validate individual parameters
        try validator.validateDuration(command.duration)
        
        // Convert duration: nil means continuous recording (represented as -1.0)
        let durationSeconds: TimeInterval
        if let durationMs = command.duration {
            durationSeconds = TimeInterval(durationMs) / 1000.0 // Convert from milliseconds
        } else {
            durationSeconds = -1.0 // Special value indicating continuous recording
        }
        
        let recordingArea: RecordingArea
        if let areaString = command.area {
            recordingArea = try validator.validateArea(areaString)
        } else if command.app != nil {
            // For application recording, we'll set the area based on the window size later
            recordingArea = baseConfig?.recordingArea ?? .fullScreen
        } else {
            recordingArea = baseConfig?.recordingArea ?? .fullScreen
        }
        
        // Get screen information
        let displayManager = DisplayManager()
        let targetScreen: ScreenInfo?
        if command.app == nil {
            // Screen recording mode - get the specified screen
            try validator.validateScreen(command.screen)
            targetScreen = try displayManager.getScreen(at: command.screen)
        } else {
            // Application recording mode - screen will be determined later
            targetScreen = nil
        }
        
        // Get application information if specified
        let targetApplication: ApplicationInfo?
        if let appName = command.app {
            let applicationManager = ApplicationManager()
            try validator.validateApplication(appName)
            targetApplication = try applicationManager.getApplication(named: appName)
        } else {
            targetApplication = nil
        }
        
        try validator.validateFPS(command.fps)
        let videoQuality = try validator.validateQuality(command.quality)
        
        // Detect output format from file extension
        let outputFormat = command.detectOutputFormat()
        try validator.validateCountdown(command.countdown)
        
        // Create and validate output URL with intelligent naming and conflict resolution
        let outputURL = try validator.validateOutputPath(command.output, format: outputFormat, overwrite: command.force)
        try validator.checkDiskSpace(for: outputURL)
        
        // Create audio enhancement settings
        let enhancementSettings = try createAudioEnhancementSettings(from: command, baseConfig: baseConfig)
        
        // Create audio settings
        let audioSettings = AudioSettings(
            includeMicrophone: command.enableMicrophone,
            includeSystemAudio: true, // Always include system audio
            forceSystemAudio: command.systemAudioOnly, // Force system-wide audio if requested
            quality: baseConfig?.audioSettings.quality ?? .medium,
            sampleRate: baseConfig?.audioSettings.sampleRate ?? AudioQuality.medium.sampleRate,
            bitRate: baseConfig?.audioSettings.bitRate ?? AudioQuality.medium.bitRate,
            channels: 2,
            enhancementSettings: enhancementSettings,
            qualityMonitoringEnabled: command.audioMonitor || command.audioSpectrum || command.audioEnhancement,
            processingEnabled: command.audioEnhancement
        )
        

        
        // Calculate actual resolution based on screen and area
        let actualResolution: CGSize
        if let screen = targetScreen {
            let recordingRect = recordingArea.toCGRect(for: screen)
            // recordingRect already includes scale factor, don't apply it again
            actualResolution = CGSize(
                width: recordingRect.width,
                height: recordingRect.height
            )
        } else {
            // Placeholder resolution for application recording
            actualResolution = CGSize(width: 1920, height: 1080)
        }
        
        // Create optimized video settings for the selected format
        let finalVideoSettings = VideoSettings.optimized(
            fps: command.fps,
            quality: videoQuality,
            resolution: actualResolution,
            for: outputFormat,
            showCursor: command.showCursor
        )
        
        // Create final configuration
        let configuration = RecordingConfiguration(
            duration: durationSeconds, // Use converted duration (may be -1.0 for continuous)
            outputURL: outputURL,
            outputFormat: outputFormat,
            recordingArea: recordingArea,
            targetScreen: targetScreen,
            targetApplication: targetApplication,
            audioSettings: audioSettings,
            videoSettings: finalVideoSettings,
            countdown: command.countdown,
            verbose: command.verbose
        )
        
        return configuration
    }
    
    /// Save current configuration as a preset
    /// - Parameters:
    ///   - name: Preset name
    ///   - configuration: Configuration to save
    /// - Throws: ValidationError if preset name is invalid or already exists
    func savePreset(named name: String, configuration: RecordingConfiguration) throws {
        try validator.validatePresetName(name)
        
        if presetStorage.presetExists(named: name) {
            throw ValidationError.presetAlreadyExists(name)
        }
        
        try presetStorage.savePreset(named: name, configuration: configuration)
        print("✅ Preset '\(name)' saved successfully")
    }
    
    /// Load a preset by name
    /// - Parameter name: Preset name
    /// - Returns: RecordingPreset
    /// - Throws: ValidationError if preset doesn't exist
    func loadPreset(named name: String) throws -> RecordingPreset {
        return try presetStorage.loadPreset(named: name)
    }
    
    /// List all available presets
    /// - Parameter jsonOutput: Whether to output in JSON format
    /// - Throws: Error if presets cannot be listed
    func listPresets(jsonOutput: Bool = false) throws {
        let presets = try presetStorage.getAllPresets()
        
        if presets.isEmpty {
            if jsonOutput {
                let output = PresetListJSON(presets: [])
                print(try output.toJSONString())
            } else {
                print("No presets found. Create one with --save-preset <name>")
            }
            return
        }
        
        if jsonOutput {
            let output = PresetListJSON(presets: presets)
            print(try output.toJSONString())
        } else {
            print("Available presets:")
            print("==================")
            
            for preset in presets {
                print("\n📋 \(preset.name)")
                
                if preset.duration == -1 {
                    print("   Duration: Continuous (until Ctrl+C)")
                } else {
                    print("   Duration: \(preset.duration)ms")
                }
                
                if let area = preset.area {
                    print("   Area: \(area)")
                } else {
                    print("   Area: Full Screen")
                }
                
                print("   Screen: \(preset.screen)")
                
                if let app = preset.app {
                    print("   App: \(app)")
                }
                
                print("   Video: \(preset.fps)fps, \(preset.quality) quality")
                print("   Audio: \(preset.enableMicrophone ? "microphone + system" : "system only")")
                print("   Format: \(preset.format.uppercased())")
                
                if preset.showCursor {
                    print("   Cursor: visible")
                }
                
                if preset.countdown > 0 {
                    print("   Countdown: \(preset.countdown)s")
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .short
                
                print("   Created: \(dateFormatter.string(from: preset.createdAt))")
                
                if let lastUsed = preset.lastUsed {
                    print("   Last used: \(dateFormatter.string(from: lastUsed))")
                }
            }
            
            print("\nUse --preset <name> to load a preset")
        }
    }
    
    /// Delete a preset
    /// - Parameter name: Preset name
    /// - Throws: ValidationError if preset doesn't exist
    func deletePreset(named name: String) throws {
        try presetStorage.deletePreset(named: name)
        print("✅ Preset '\(name)' deleted successfully")
    }
    
    /// Validate a complete recording configuration
    /// - Parameter configuration: Configuration to validate
    /// - Throws: ValidationError if configuration is invalid
    func validateConfiguration(_ configuration: RecordingConfiguration) throws {
        // Validate duration
        let durationMs = Int(configuration.duration * 1000)
        try validator.validateDuration(durationMs)
        
        // Validate FPS
        try validator.validateFPS(configuration.videoSettings.fps)
        
        // Validate countdown
        try validator.validateCountdown(configuration.countdown)
        
        // Check disk space
        try validator.checkDiskSpace(for: configuration.outputURL)
        
        // Additional validation can be added here as needed
    }
    
    /// Update configuration with actual screen and application info
    /// - Parameters:
    ///   - configuration: Base configuration
    ///   - screen: Actual screen info
    ///   - application: Actual application info (optional)
    /// - Returns: Updated configuration with correct resolution and targets
    func updateConfiguration(_ configuration: RecordingConfiguration,
                           with screen: ScreenInfo?,
                           application: ApplicationInfo? = nil) -> RecordingConfiguration {
        
        // Calculate actual recording resolution
        let actualResolution: CGSize
        if let screen = screen {
            let recordingRect = configuration.recordingArea.toCGRect(for: screen)
            actualResolution = recordingRect.size
        } else {
            actualResolution = configuration.videoSettings.resolution
        }
        
        // Update video settings with actual resolution
        let updatedVideoSettings = VideoSettings(
            fps: configuration.videoSettings.fps,
            quality: configuration.videoSettings.quality,
            codec: configuration.videoSettings.codec,
            showCursor: configuration.videoSettings.showCursor,
            resolution: actualResolution
        )
        
        return RecordingConfiguration(
            duration: configuration.duration,
            outputURL: configuration.outputURL,
            outputFormat: configuration.outputFormat,
            recordingArea: configuration.recordingArea,
            targetScreen: screen,
            targetApplication: application,
            audioSettings: configuration.audioSettings,
            videoSettings: updatedVideoSettings,
            countdown: configuration.countdown,
            verbose: configuration.verbose
        )
    }
    
    // MARK: - Audio Preset Management
    
    /// Save current audio settings as a custom preset
    /// - Parameters:
    ///   - name: Preset name
    ///   - settings: Audio enhancement settings to save
    ///   - description: Optional description
    /// - Throws: ValidationError if preset name is invalid or already exists
    func saveAudioPreset(named name: String, settings: AudioEnhancementSettings, description: String? = nil) throws {
        try validator.validatePresetName(name)
        
        if audioPresetManager.customPresetExists(named: name) {
            throw ValidationError.presetAlreadyExists(name)
        }
        
        // Validate settings before saving
        let validationResult = audioPresetManager.validatePresetSettings(settings)
        if !validationResult.isValid {
            let errors = validationResult.errors.joined(separator: ", ")
            throw ValidationError(
                "Invalid audio preset settings: \(errors)",
                suggestion: "Check your audio enhancement parameters and ensure they are within valid ranges"
            )
        }
        
        try audioPresetManager.saveCustomPreset(named: name, settings: settings)
        print("✅ Audio preset '\(name)' saved successfully")
        
        // Show warnings if any
        if !validationResult.warnings.isEmpty {
            print("⚠️ Warnings:")
            for warning in validationResult.warnings {
                print("   • \(warning)")
            }
        }
        
        // Show suggestions if any
        if !validationResult.suggestions.isEmpty {
            print("💡 Suggestions:")
            for suggestion in validationResult.suggestions {
                print("   • \(suggestion)")
            }
        }
    }
    
    /// Load an audio preset by name or type
    /// - Parameter presetIdentifier: Preset name (for custom) or preset type
    /// - Returns: AudioEnhancementSettings
    /// - Throws: ValidationError if preset doesn't exist or is invalid
    func loadAudioPreset(_ presetIdentifier: String) throws -> AudioEnhancementSettings {
        // First try to parse as built-in preset
        if let builtInPreset = AudioPreset(rawValue: presetIdentifier.lowercased()) {
            return try audioPresetManager.loadPreset(builtInPreset)
        }
        
        // If not a built-in preset, try to load as custom preset
        return try audioPresetManager.loadCustomPreset(named: presetIdentifier)
    }
    
    /// List all available audio presets (built-in and custom)
    /// - Parameter jsonOutput: Whether to output in JSON format
    /// - Throws: Error if presets cannot be listed
    func listAudioPresets(jsonOutput: Bool = false) throws {
        let customPresets = try audioPresetManager.getAllCustomPresets()
        let builtInPresets = AudioPreset.allCases.filter { $0 != .custom }
        
        if jsonOutput {
            let output = AudioPresetListJSON(
                builtInPresets: builtInPresets.map { preset in
                    AudioPresetInfo(
                        name: preset.rawValue,
                        type: "built-in",
                        description: getPresetDescription(preset),
                        settings: preset.defaultSettings
                    )
                },
                customPresets: customPresets.map { preset in
                    AudioPresetInfo(
                        name: preset.name,
                        type: "custom",
                        description: preset.description ?? "Custom audio preset",
                        settings: preset.settings,
                        createdAt: preset.createdAt,
                        lastUsed: preset.lastUsed
                    )
                }
            )
            print(try output.toJSONString())
        } else {
            print("Available Audio Presets:")
            print("========================")
            
            // Show built-in presets
            print("\n🔧 Built-in Presets:")
            for preset in builtInPresets {
                print("   📋 \(preset.rawValue)")
                print("      \(getPresetDescription(preset))")
                let settings = preset.defaultSettings
                print("      Gain: \(settings.masterGain) dB, Compression: \(settings.compressionRatio):1")
            }
            
            // Show custom presets
            if !customPresets.isEmpty {
                print("\n🎨 Custom Presets:")
                for preset in customPresets {
                    print("   📋 \(preset.name)")
                    if let description = preset.description {
                        print("      \(description)")
                    }
                    let settings = preset.settings
                    print("      Gain: \(settings.masterGain) dB, Compression: \(settings.compressionRatio):1")
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    dateFormatter.timeStyle = .short
                    
                    print("      Created: \(dateFormatter.string(from: preset.createdAt))")
                    if let lastUsed = preset.lastUsed {
                        print("      Last used: \(dateFormatter.string(from: lastUsed))")
                    }
                }
            } else {
                print("\n🎨 Custom Presets: None")
                print("   Create custom presets with --save-audio-preset <name>")
            }
            
            print("\nUsage:")
            print("  --audio-preset speech              # Use built-in speech preset")
            print("  --audio-preset my-custom          # Use custom preset")
            print("  --save-audio-preset my-config     # Save current settings as preset")
        }
    }
    
    /// Delete an audio preset
    /// - Parameter name: Preset name
    /// - Throws: ValidationError if preset doesn't exist or is built-in
    func deleteAudioPreset(named name: String) throws {
        // Prevent deletion of built-in presets
        if AudioPreset(rawValue: name.lowercased()) != nil {
            throw ValidationError(
                "Cannot delete built-in preset '\(name)'",
                suggestion: "Only custom presets can be deleted"
            )
        }
        
        try audioPresetManager.deleteCustomPreset(named: name)
        print("✅ Audio preset '\(name)' deleted successfully")
    }
    
    /// Get recommended audio preset for content type
    /// - Parameter contentType: Type of content being recorded
    /// - Returns: Recommended AudioPreset
    func getRecommendedAudioPreset(for contentType: AudioPresetContentType) -> AudioPreset {
        return audioPresetManager.getRecommendedPreset(for: contentType)
    }
    
    /// Validate audio preset settings and provide feedback
    /// - Parameter settings: Settings to validate
    /// - Returns: Validation result with suggestions
    func validateAudioPresetSettings(_ settings: AudioEnhancementSettings) -> AudioPresetValidationResult {
        return audioPresetManager.validatePresetSettings(settings)
    }
    
    // MARK: - Private Helper Methods
    
    /// Get description for built-in presets
    /// - Parameter preset: Audio preset
    /// - Returns: Description string
    private func getPresetDescription(_ preset: AudioPreset) -> String {
        switch preset {
        case .speech:
            return "Optimized for voice recordings and meetings"
        case .music:
            return "Preserves full frequency range for music content"
        case .gaming:
            return "Enhanced for game audio and streaming"
        case .balanced:
            return "General purpose preset for mixed content"
        case .custom:
            return "User-defined custom settings"
        }
    }
    
    // MARK: - Audio Enhancement Configuration
    
    /// Create audio enhancement settings from CLI command
    /// - Parameters:
    ///   - command: SwiftCaptureCommand with CLI options
    ///   - baseConfig: Base configuration from preset (optional)
    /// - Returns: Configured AudioEnhancementSettings
    /// - Throws: ValidationError if settings are invalid
    private func createAudioEnhancementSettings(from command: SwiftCaptureCommand, baseConfig: RecordingConfiguration?) throws -> AudioEnhancementSettings {
        
        // Start with base settings from preset or default
        var settings: AudioEnhancementSettings
        
        if let baseConfig = baseConfig {
            settings = baseConfig.audioSettings.enhancementSettings
        } else {
            // Try to load audio preset (built-in or custom)
            do {
                settings = try loadAudioPreset(command.audioPreset)
            } catch {
                // If preset loading fails, try parsing as built-in preset
                guard let preset = AudioPreset(rawValue: command.audioPreset.lowercased()) else {
                    throw ValidationError(
                        "Invalid audio preset: '\(command.audioPreset)'",
                        suggestion: "Use speech, music, gaming, balanced, or a custom preset name"
                    )
                }
                settings = AudioEnhancementSettings.from(preset: preset)
            }
        }
        
        // Apply command-line overrides
        if let gain = command.audioGain {
            settings.masterGain = gain
            settings.preset = .custom // Mark as custom when manually modified
        }
        
        if command.autoGain {
            settings.autoGainEnabled = true
        }
        
        if let ratio = command.compressionRatio {
            settings.compressionRatio = ratio
            settings.preset = .custom
        }
        
        if let threshold = command.limiterThreshold {
            settings.limiterThreshold = threshold
            settings.preset = .custom
        }
        
        if command.qualityProtection {
            settings.qualityProtectionEnabled = true
        }
        
        if command.losslessMode {
            settings.losslessModeEnabled = true
            settings.preset = .custom
        }
        
        if command.qualityComparison {
            settings.qualityComparisonEnabled = true
        }
        
        // Enable processing if enhancement is requested
        if command.audioEnhancement {
            settings.processingEnabled = true
        }
        
        // Enable quality monitoring if requested
        if command.audioMonitor || command.audioSpectrum {
            settings.qualityMonitoringEnabled = true
        }
        
        // Enable quality comparison automatically if quality protection is enabled
        if command.qualityProtection && !command.qualityComparison {
            settings.qualityComparisonEnabled = true
        }
        
        // Audio preview requires enhancement to be enabled
        if command.audioPreview && !command.audioEnhancement {
            throw ValidationError(
                "Audio preview requires audio enhancement to be enabled",
                suggestion: "Use --audio-enhancement along with --audio-preview"
            )
        }
        
        // Validate final settings
        if !settings.isValid {
            let errors = settings.validationErrors.joined(separator: ", ")
            throw ValidationError(
                "Invalid audio enhancement settings: \(errors)",
                suggestion: "Check your audio enhancement parameters and ensure they are within valid ranges"
            )
        }
        
        return settings
    }
}

// MARK: - Audio Preset JSON Models

/// JSON model for audio preset information
struct AudioPresetInfo: Codable {
    let name: String
    let type: String // "built-in" or "custom"
    let description: String
    let settings: AudioEnhancementSettings
    let createdAt: Date?
    let lastUsed: Date?
    
    init(name: String, type: String, description: String, settings: AudioEnhancementSettings, createdAt: Date? = nil, lastUsed: Date? = nil) {
        self.name = name
        self.type = type
        self.description = description
        self.settings = settings
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
}

/// JSON model for listing audio presets
struct AudioPresetListJSON: Codable {
    let builtInPresets: [AudioPresetInfo]
    let customPresets: [AudioPresetInfo]
    
    func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}