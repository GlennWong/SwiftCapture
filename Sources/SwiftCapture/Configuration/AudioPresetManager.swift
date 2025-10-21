import Foundation

/// Manages audio enhancement presets and custom configurations
class AudioPresetManager {
    
    /// Directory where audio presets are stored
    private let audioPresetsDirectory: URL
    
    /// Initialize audio preset manager
    /// - Throws: Error if audio presets directory cannot be created
    init() throws {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        audioPresetsDirectory = homeDirectory.appendingPathComponent(".swiftcapture/audio-presets")
        
        // Create audio presets directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioPresetsDirectory.path) {
            try FileManager.default.createDirectory(at: audioPresetsDirectory,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        }
    }
    
    // MARK: - Preset Management
    
    /// Save a custom audio preset
    /// - Parameters:
    ///   - name: Preset name
    ///   - settings: Audio enhancement settings to save
    /// - Throws: Error if preset cannot be saved
    func saveCustomPreset(named name: String, settings: AudioEnhancementSettings) throws {
        let preset = AudioPresetData(name: name, settings: settings)
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
    
    /// Load a custom audio preset
    /// - Parameter name: Preset name
    /// - Returns: AudioEnhancementSettings
    /// - Throws: Error if preset cannot be loaded
    func loadCustomPreset(named name: String) throws -> AudioEnhancementSettings {
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var preset = try decoder.decode(AudioPresetData.self, from: data)
        preset.lastUsed = Date() // Update last used time
        
        // Save the updated preset with new lastUsed time
        try saveCustomPreset(named: name, preset: preset)
        
        return preset.settings
    }
    
    /// Load audio preset (built-in or custom)
    /// - Parameter preset: Audio preset type
    /// - Returns: AudioEnhancementSettings
    /// - Throws: Error if custom preset cannot be loaded
    func loadPreset(_ preset: AudioPreset) throws -> AudioEnhancementSettings {
        switch preset {
        case .speech, .music, .gaming, .balanced:
            return preset.defaultSettings
        case .custom:
            // For custom preset, we need a name - this should be handled by the caller
            throw ValidationError(
                "Custom preset requires a specific preset name",
                suggestion: "Use loadCustomPreset(named:) for custom presets"
            )
        }
    }
    
    /// Apply preset to existing settings
    /// - Parameters:
    ///   - preset: Audio preset to apply
    ///   - settings: Current settings to modify
    /// - Returns: Updated AudioEnhancementSettings
    /// - Throws: Error if custom preset cannot be loaded
    func applyPreset(_ preset: AudioPreset, to settings: inout AudioEnhancementSettings) throws {
        _ = try loadPreset(preset) // Validate preset exists
        settings.applyPreset(preset)
    }
    
    /// List all available custom presets
    /// - Returns: Array of custom preset names
    /// - Throws: Error if presets directory cannot be read
    func listCustomPresets() throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(at: audioPresetsDirectory,
                                                                 includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles])
        
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    
    /// Get detailed information about all custom presets
    /// - Returns: Array of AudioPresetData objects
    /// - Throws: Error if presets cannot be loaded
    func getAllCustomPresets() throws -> [AudioPresetData] {
        let presetNames = try listCustomPresets()
        var presets: [AudioPresetData] = []
        
        for name in presetNames {
            do {
                let preset = try loadCustomPresetData(named: name)
                presets.append(preset)
            } catch {
                // Skip presets that can't be loaded (corrupted files)
                print("Warning: Could not load audio preset '\(name)': \(error.localizedDescription)")
            }
        }
        
        return presets.sorted { $0.lastUsed ?? $0.createdAt > $1.lastUsed ?? $1.createdAt }
    }
    
    /// Delete a custom preset
    /// - Parameter name: Preset name
    /// - Throws: Error if preset cannot be deleted
    func deleteCustomPreset(named name: String) throws {
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        try FileManager.default.removeItem(at: presetURL)
    }
    
    /// Check if a custom preset exists
    /// - Parameter name: Preset name
    /// - Returns: True if preset exists
    func customPresetExists(named name: String) -> Bool {
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        return FileManager.default.fileExists(atPath: presetURL.path)
    }
    
    // MARK: - Preset Validation and Recommendations
    
    /// Get recommended preset for content type
    /// - Parameter contentType: Type of content being recorded
    /// - Returns: Recommended AudioPreset
    func getRecommendedPreset(for contentType: AudioPresetContentType) -> AudioPreset {
        switch contentType {
        case .speech, .meeting, .presentation:
            return .speech
        case .music, .podcast, .audiobook:
            return .music
        case .gaming, .streaming:
            return .gaming
        case .mixed, .unknown:
            return .balanced
        }
    }
    
    /// Validate preset settings
    /// - Parameter settings: Settings to validate
    /// - Returns: Validation result with suggestions
    func validatePresetSettings(_ settings: AudioEnhancementSettings) -> AudioPresetValidationResult {
        var warnings: [String] = []
        var suggestions: [String] = []
        
        // Check for potentially problematic settings
        if settings.masterGain > 10.0 {
            warnings.append("High master gain (\(settings.masterGain) dB) may cause distortion")
            suggestions.append("Consider using compression instead of high gain")
        }
        
        if settings.compressionRatio > 8.0 {
            warnings.append("Very high compression ratio (\(settings.compressionRatio):1) may sound unnatural")
            suggestions.append("Try a lower compression ratio (2.0-4.0) for more natural sound")
        }
        
        if settings.attack < 1.0 && settings.compressionRatio > 4.0 {
            warnings.append("Fast attack with high compression may cause pumping artifacts")
            suggestions.append("Increase attack time to 3-5ms or reduce compression ratio")
        }
        
        if settings.limiterThreshold > -0.5 {
            warnings.append("Limiter threshold very close to 0 dBFS may cause clipping")
            suggestions.append("Set limiter threshold to -1.0 dBFS or lower for safety")
        }
        
        return AudioPresetValidationResult(
            isValid: settings.isValid,
            errors: settings.validationErrors,
            warnings: warnings,
            suggestions: suggestions
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// Load custom preset data without updating last used time
    /// - Parameter name: Preset name
    /// - Returns: AudioPresetData
    /// - Throws: Error if preset cannot be loaded
    private func loadCustomPresetData(named name: String) throws -> AudioPresetData {
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(AudioPresetData.self, from: data)
    }
    
    /// Save preset data directly
    /// - Parameters:
    ///   - name: Preset name
    ///   - preset: AudioPresetData object
    /// - Throws: Error if preset cannot be saved
    private func saveCustomPreset(named name: String, preset: AudioPresetData) throws {
        let presetURL = audioPresetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
}

// MARK: - Supporting Types

/// Audio content type for preset recommendations
enum AudioPresetContentType {
    case speech
    case meeting
    case presentation
    case music
    case podcast
    case audiobook
    case gaming
    case streaming
    case mixed
    case unknown
}

/// Audio preset data for storage
struct AudioPresetData: Codable {
    /// Preset name
    let name: String
    
    /// Audio enhancement settings
    let settings: AudioEnhancementSettings
    
    /// When the preset was created
    let createdAt: Date
    
    /// When the preset was last used (mutable for updates)
    var lastUsed: Date?
    
    /// Optional description
    let description: String?
    
    /// Initialize with settings
    /// - Parameters:
    ///   - name: Preset name
    ///   - settings: Audio enhancement settings
    ///   - description: Optional description
    init(name: String, settings: AudioEnhancementSettings, description: String? = nil) {
        self.name = name
        self.settings = settings
        self.description = description
        self.createdAt = Date()
        self.lastUsed = nil
    }
}

/// Validation result for audio preset settings
struct AudioPresetValidationResult {
    /// Whether settings are valid
    let isValid: Bool
    
    /// Validation errors (prevent usage)
    let errors: [String]
    
    /// Warnings (allow usage but inform user)
    let warnings: [String]
    
    /// Suggestions for improvement
    let suggestions: [String]
    
    /// Whether there are any issues
    var hasIssues: Bool {
        return !errors.isEmpty || !warnings.isEmpty
    }
}