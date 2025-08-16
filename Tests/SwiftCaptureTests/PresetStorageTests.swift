import XCTest
@testable import SwiftCapture

final class PresetStorageTests: XCTestCase {
    
    var presetStorage: PresetStorage!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test presets
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCapturePresetTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
        
        // Create preset storage with custom directory
        do {
            presetStorage = try TestPresetStorage(customDirectory: tempDirectory)
        } catch {
            XCTFail("Failed to initialize PresetStorage: \(error)")
        }
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        presetStorage = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Save and Load Tests
    
    func testSavePreset_ValidConfiguration_ShouldSaveSuccessfully() throws {
        let config = createTestConfiguration()
        let presetName = "test-preset"
        
        try presetStorage.savePreset(named: presetName, configuration: config)
        
        // Verify file was created
        let presetURL = tempDirectory.appendingPathComponent("\(presetName).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: presetURL.path))
        
        // Verify file content
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let savedPreset = try decoder.decode(RecordingPreset.self, from: data)
        
        XCTAssertEqual(savedPreset.name, presetName)
        XCTAssertEqual(savedPreset.duration, 10000)
        XCTAssertEqual(savedPreset.fps, 30)
        XCTAssertEqual(savedPreset.quality, "medium")
        // Format is fixed to MOV, no longer stored in presets
    }
    
    func testLoadPreset_ExistingPreset_ShouldLoadSuccessfully() throws {
        let config = createTestConfiguration()
        let presetName = "load-test"
        
        // Save preset first
        try presetStorage.savePreset(named: presetName, configuration: config)
        
        // Load preset
        let loadedPreset = try presetStorage.loadPreset(named: presetName)
        
        XCTAssertEqual(loadedPreset.name, presetName)
        XCTAssertEqual(loadedPreset.duration, 10000)
        XCTAssertEqual(loadedPreset.fps, 30)
        XCTAssertEqual(loadedPreset.quality, "medium")
        // Format is fixed to MOV, no longer stored in presets
        XCTAssertNotNil(loadedPreset.lastUsed) // Should be updated when loaded
    }
    
    func testLoadPreset_NonExistentPreset_ShouldThrow() {
        XCTAssertThrowsError(try presetStorage.loadPreset(named: "non-existent")) { error in
            XCTAssertTrue(error is ValidationError)
            let validationError = error as! ValidationError
            XCTAssertTrue(validationError.message.contains("not found"))
        }
    }
    
    // MARK: - List Presets Tests
    
    func testListPresets_EmptyDirectory_ShouldReturnEmptyArray() throws {
        let presets = try presetStorage.listPresets()
        XCTAssertTrue(presets.isEmpty)
    }
    
    func testListPresets_WithPresets_ShouldReturnSortedNames() throws {
        let config = createTestConfiguration()
        
        // Save multiple presets
        try presetStorage.savePreset(named: "zebra", configuration: config)
        try presetStorage.savePreset(named: "alpha", configuration: config)
        try presetStorage.savePreset(named: "beta", configuration: config)
        
        let presets = try presetStorage.listPresets()
        
        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(presets, ["alpha", "beta", "zebra"]) // Should be sorted
    }
    
    func testGetAllPresets_WithPresets_ShouldReturnDetailedInfo() throws {
        let config = createTestConfiguration()
        
        // Save presets with different timestamps
        try presetStorage.savePreset(named: "first", configuration: config)
        Thread.sleep(forTimeInterval: 0.1) // Small delay to ensure different timestamps
        try presetStorage.savePreset(named: "second", configuration: config)
        
        let presets = try presetStorage.getAllPresets()
        
        XCTAssertEqual(presets.count, 2)
        
        // Should be sorted by creation date (newest first)
        XCTAssertTrue(presets[0].createdAt >= presets[1].createdAt)
    }
    
    // MARK: - Delete Preset Tests
    
    func testDeletePreset_ExistingPreset_ShouldDeleteSuccessfully() throws {
        let config = createTestConfiguration()
        let presetName = "delete-test"
        
        // Save preset first
        try presetStorage.savePreset(named: presetName, configuration: config)
        XCTAssertTrue(presetStorage.presetExists(named: presetName))
        
        // Delete preset
        try presetStorage.deletePreset(named: presetName)
        XCTAssertFalse(presetStorage.presetExists(named: presetName))
        
        // Verify file was deleted
        let presetURL = tempDirectory.appendingPathComponent("\(presetName).json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: presetURL.path))
    }
    
    func testDeletePreset_NonExistentPreset_ShouldThrow() {
        XCTAssertThrowsError(try presetStorage.deletePreset(named: "non-existent")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Preset Exists Tests
    
    func testPresetExists_ExistingPreset_ShouldReturnTrue() throws {
        let config = createTestConfiguration()
        let presetName = "exists-test"
        
        XCTAssertFalse(presetStorage.presetExists(named: presetName))
        
        try presetStorage.savePreset(named: presetName, configuration: config)
        XCTAssertTrue(presetStorage.presetExists(named: presetName))
    }
    
    func testPresetExists_NonExistentPreset_ShouldReturnFalse() {
        XCTAssertFalse(presetStorage.presetExists(named: "non-existent"))
    }
    
    // MARK: - Preset Conversion Tests
    
    func testPresetConversion_RoundTrip_ShouldPreserveData() throws {
        let originalConfig = createTestConfiguration()
        let presetName = "conversion-test"
        
        // Save as preset
        try presetStorage.savePreset(named: presetName, configuration: originalConfig)
        
        // Load preset
        let loadedPreset = try presetStorage.loadPreset(named: presetName)
        
        // Convert back to configuration
        let outputURL = URL(fileURLWithPath: "/tmp/test-output.mov")
        let convertedConfig = try loadedPreset.toRecordingConfiguration(outputURL: outputURL)
        
        // Verify key properties are preserved
        XCTAssertEqual(convertedConfig.duration, originalConfig.duration)
        XCTAssertEqual(convertedConfig.outputFormat, originalConfig.outputFormat)
        XCTAssertEqual(convertedConfig.recordingArea, originalConfig.recordingArea)
        XCTAssertEqual(convertedConfig.videoSettings.fps, originalConfig.videoSettings.fps)
        XCTAssertEqual(convertedConfig.videoSettings.quality, originalConfig.videoSettings.quality)
        XCTAssertEqual(convertedConfig.videoSettings.showCursor, originalConfig.videoSettings.showCursor)
        XCTAssertEqual(convertedConfig.audioSettings.includeMicrophone, originalConfig.audioSettings.includeMicrophone)
        XCTAssertEqual(convertedConfig.countdown, originalConfig.countdown)
    }
    
    func testPresetConversion_WithCustomArea_ShouldPreserveArea() throws {
        var config = createTestConfiguration()
        config = RecordingConfiguration(
            duration: config.duration,
            outputURL: config.outputURL,
            outputFormat: config.outputFormat,
            recordingArea: .customRect(CGRect(x: 100, y: 200, width: 800, height: 600)),
            targetScreen: config.targetScreen,
            targetApplication: config.targetApplication,
            audioSettings: config.audioSettings,
            videoSettings: config.videoSettings,
            countdown: config.countdown
        )
        
        let presetName = "area-test"
        try presetStorage.savePreset(named: presetName, configuration: config)
        
        let loadedPreset = try presetStorage.loadPreset(named: presetName)
        XCTAssertEqual(loadedPreset.area, "100:200:800:600")
        
        let outputURL = URL(fileURLWithPath: "/tmp/test-output.mov")
        let convertedConfig = try loadedPreset.toRecordingConfiguration(outputURL: outputURL)
        
        if case .customRect(let rect) = convertedConfig.recordingArea {
            XCTAssertEqual(rect.origin.x, 100)
            XCTAssertEqual(rect.origin.y, 200)
            XCTAssertEqual(rect.width, 800)
            XCTAssertEqual(rect.height, 600)
        } else {
            XCTFail("Expected customRect, got \(convertedConfig.recordingArea)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testGetAllPresets_WithCorruptedFile_ShouldSkipCorruptedPresets() throws {
        let config = createTestConfiguration()
        
        // Save a valid preset
        try presetStorage.savePreset(named: "valid", configuration: config)
        
        // Create a corrupted preset file
        let corruptedURL = tempDirectory.appendingPathComponent("corrupted.json")
        try "invalid json content".write(to: corruptedURL, atomically: true, encoding: .utf8)
        
        // Should return only the valid preset
        let presets = try presetStorage.getAllPresets()
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets[0].name, "valid")
    }
    
    // MARK: - Helper Methods
    
    private func createTestConfiguration() -> RecordingConfiguration {
        return RecordingConfiguration(
            duration: 10.0,
            outputURL: URL(fileURLWithPath: "/tmp/test.mov"),
            outputFormat: .mov,
            recordingArea: .fullScreen,
            targetScreen: nil,
            targetApplication: nil,
            audioSettings: AudioSettings(
                includeMicrophone: false,
                includeSystemAudio: true,
                forceSystemAudio: false,
                quality: .medium,
                sampleRate: 44100,
                bitRate: 128000,
                channels: 2
            ),
            videoSettings: VideoSettings(
                fps: 30,
                quality: .medium,
                codec: .h264,
                showCursor: false,
                resolution: CGSize(width: 1920, height: 1080)
            ),
            countdown: 0
        )
    }
}

// MARK: - Test Preset Storage

class TestPresetStorage: PresetStorage {
    private let customPresetsDirectory: URL
    
    init(customDirectory: URL) throws {
        self.customPresetsDirectory = customDirectory
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: customDirectory.path) {
            try FileManager.default.createDirectory(at: customDirectory,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        }
        
        try super.init()
    }
    
    override func savePreset(named name: String, configuration: RecordingConfiguration) throws {
        let preset = RecordingPreset(from: configuration, name: name)
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
    
    override func loadPreset(named name: String) throws -> RecordingPreset {
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var preset = try decoder.decode(RecordingPreset.self, from: data)
        preset.lastUsed = Date()
        
        // Save the updated preset with new lastUsed time
        try savePreset(named: name, preset: preset)
        
        return preset
    }
    
    override func listPresets() throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(at: customPresetsDirectory,
                                                                 includingPropertiesForKeys: nil,
                                                                 options: [.skipsHiddenFiles])
        
        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    
    override func getAllPresets() throws -> [RecordingPreset] {
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
    
    override func deletePreset(named name: String) throws {
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        try FileManager.default.removeItem(at: presetURL)
    }
    
    override func presetExists(named name: String) -> Bool {
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        return FileManager.default.fileExists(atPath: presetURL.path)
    }
    
    private func loadPresetWithoutUpdatingLastUsed(named name: String) throws -> RecordingPreset {
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: presetURL.path) else {
            throw ValidationError.presetNotFound(name)
        }
        
        let data = try Data(contentsOf: presetURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(RecordingPreset.self, from: data)
    }
    
    private func savePreset(named name: String, preset: RecordingPreset) throws {
        let presetURL = customPresetsDirectory.appendingPathComponent("\(name).json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(preset)
        try data.write(to: presetURL)
    }
}