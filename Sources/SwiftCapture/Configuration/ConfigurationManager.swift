import Foundation
import CoreGraphics

/// Manages recording configurations, presets, and parameter validation
class ConfigurationManager {
    
    private let validator: ParameterValidator
    private let presetStorage: PresetStorage
    
    /// Initialize configuration manager
    /// - Throws: Error if preset storage cannot be initialized
    init() throws {
        self.validator = ParameterValidator()
        self.presetStorage = try PresetStorage()
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
        
        // Create audio settings
        let audioSettings = AudioSettings(
            includeMicrophone: command.enableMicrophone,
            includeSystemAudio: true, // Always include system audio
            forceSystemAudio: command.systemAudioOnly, // Force system-wide audio if requested
            quality: baseConfig?.audioSettings.quality ?? .medium,
            sampleRate: baseConfig?.audioSettings.sampleRate ?? AudioQuality.medium.sampleRate,
            bitRate: baseConfig?.audioSettings.bitRate ?? AudioQuality.medium.bitRate,
            channels: 2
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
}