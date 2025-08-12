import Foundation

/// Manages storage and retrieval of recording presets
class PresetStorage {
    
    /// Directory where presets are stored
    private let presetsDirectory: URL
    
    /// Initialize preset storage
    /// - Throws: Error if presets directory cannot be created
    init() throws {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        presetsDirectory = homeDirectory.appendingPathComponent(".swiftcapture/presets")
        
        // Create presets directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: presetsDirectory.path) {
            try FileManager.default.createDirectory(at: presetsDirectory,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        }
    }
    
    /// Save a preset to disk
    /// - Parameters:
    ///   - name: Preset name
    ///   - configuration: Recording configuration to save
    /// - Throws: Error if preset cannot be saved
    func savePreset(named name: String, configuration: RecordingConfiguration) throws {
        let preset = RecordingPreset(from: configuration, name: name)
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
    
    /// Load a preset from disk
    /// - Parameter name: Preset name
    /// - Returns: RecordingPreset
    /// - Throws: Error if preset cannot be loaded
    func loadPreset(named name: String) throws -> RecordingPreset {
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var preset = try decoder.decode(RecordingPreset.self, from: data)
        preset.lastUsed = Date() // Update last used time
        
        // Save the updated preset with new lastUsed time
        try savePreset(named: name, preset: preset)
        
        return preset
    }
    
    /// List all available presets
    /// - Returns: Array of preset names
    /// - Throws: Error if presets directory cannot be read
    func listPresets() throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(at: presetsDirectory,
                                                                 includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles])
        
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    
    /// Get detailed information about all presets
    /// - Returns: Array of RecordingPreset objects
    /// - Throws: Error if presets cannot be loaded
    func getAllPresets() throws -> [RecordingPreset] {
        let presetNames = try listPresets()
        var presets: [RecordingPreset] = []
        
        for name in presetNames {
            do {
                let preset = try loadPresetWithoutUpdatingLastUsed(named: name)
                presets.append(preset)
            } catch {
                // Skip presets that can't be loaded (corrupted files)
                print("Warning: Could not load preset '\(name)': \(error.localizedDescription)")
            }
        }
        
        return presets.sorted { $0.lastUsed ?? $0.createdAt > $1.lastUsed ?? $1.createdAt }
    }
    
    /// Delete a preset
    /// - Parameter name: Preset name
    /// - Throws: Error if preset cannot be deleted
    func deletePreset(named name: String) throws {
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        try FileManager.default.removeItem(at: presetURL)
    }
    
    /// Check if a preset exists
    /// - Parameter name: Preset name
    /// - Returns: True if preset exists
    func presetExists(named name: String) -> Bool {
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        return FileManager.default.fileExists(atPath: presetURL.path)
    }
    
    /// Load preset without updating last used time (for internal use)
    /// - Parameter name: Preset name
    /// - Returns: RecordingPreset
    /// - Throws: Error if preset cannot be loaded
    private func loadPresetWithoutUpdatingLastUsed(named name: String) throws -> RecordingPreset {
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(RecordingPreset.self, from: data)
    }
    
    /// Save preset object directly (for internal use)
    /// - Parameters:
    ///   - name: Preset name
    ///   - preset: RecordingPreset object
    /// - Throws: Error if preset cannot be saved
    private func savePreset(named name: String, preset: RecordingPreset) throws {
        let presetURL = presetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
}