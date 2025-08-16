import XCTest
@testable import SwiftCapture

final class ParameterValidatorTests: XCTestCase {
    
    var validator: ParameterValidator!
    var mockDisplayManager: MockDisplayManager!
    
    override func setUp() {
        super.setUp()
        mockDisplayManager = MockDisplayManager()
        validator = ParameterValidator(displayManager: mockDisplayManager)
    }
    
    override func tearDown() {
        validator = nil
        mockDisplayManager = nil
        super.tearDown()
    }
    
    // MARK: - Duration Validation Tests
    
    func testValidateDuration_ValidDuration_ShouldNotThrow() throws {
        // Test valid durations
        try validator.validateDuration(100)  // Minimum
        try validator.validateDuration(1000) // 1 second
        try validator.validateDuration(5000) // 5 seconds
        try validator.validateDuration(60000) // 1 minute
    }
    
    func testValidateDuration_TooShort_ShouldThrow() {
        XCTAssertThrowsError(try validator.validateDuration(99)) { error in
            XCTAssertTrue(error is ValidationError)
            let validationError = error as! ValidationError
            XCTAssertTrue(validationError.message.contains("Invalid duration: 99ms"))
        }
        
        XCTAssertThrowsError(try validator.validateDuration(0)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateDuration(-1000)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Area Validation Tests
    
    func testValidateArea_ValidFormats_ShouldReturnCorrectArea() throws {
        // Test custom rectangle
        let customRect = try validator.validateArea("100:200:800:600")
        if case .customRect(let rect) = customRect {
            XCTAssertEqual(rect.origin.x, 100)
            XCTAssertEqual(rect.origin.y, 200)
            XCTAssertEqual(rect.width, 800)
            XCTAssertEqual(rect.height, 600)
        } else {
            XCTFail("Expected customRect, got \(customRect)")
        }
        
        // Test centered area
        let centered = try validator.validateArea("center:800:600")
        if case .centered(let width, let height) = centered {
            XCTAssertEqual(width, 800)
            XCTAssertEqual(height, 600)
        } else {
            XCTFail("Expected centered, got \(centered)")
        }
    }
    
    func testValidateArea_InvalidFormats_ShouldThrow() {
        // Test invalid formats
        XCTAssertThrowsError(try validator.validateArea("invalid")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateArea("100:200:800")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateArea("100:200:800:600:extra")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateArea("abc:def:ghi:jkl")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Screen Validation Tests
    
    func testValidateScreen_ValidScreen_ShouldNotThrow() throws {
        // Mock display manager should validate screen 1 and 2
        mockDisplayManager.mockScreens = [
            ScreenInfo(index: 1, displayID: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), name: "Built-in Display", isPrimary: true, scaleFactor: 2.0),
            ScreenInfo(index: 2, displayID: 2, frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), name: "External Display", isPrimary: false, scaleFactor: 1.0)
        ]
        
        try validator.validateScreen(1)
        try validator.validateScreen(2)
    }
    
    func testValidateScreen_InvalidScreen_ShouldThrow() {
        mockDisplayManager.mockScreens = [
            ScreenInfo(index: 1, displayID: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), name: "Built-in Display", isPrimary: true, scaleFactor: 2.0)
        ]
        
        XCTAssertThrowsError(try validator.validateScreen(0)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateScreen(-1)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateScreen(3)) { error in
            XCTAssertTrue(error is SwiftCaptureError)
        }
    }
    
    // MARK: - Application Validation Tests
    
    func testValidateApplication_ValidName_ShouldNotThrow() throws {
        try validator.validateApplication("Safari")
        try validator.validateApplication("Xcode")
        try validator.validateApplication("Terminal")
    }
    
    func testValidateApplication_EmptyName_ShouldThrow() {
        XCTAssertThrowsError(try validator.validateApplication("")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateApplication("   ")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - FPS Validation Tests
    
    func testValidateFPS_ValidValues_ShouldNotThrow() throws {
        try validator.validateFPS(15)
        try validator.validateFPS(30)
        try validator.validateFPS(60)
    }
    
    func testValidateFPS_InvalidValues_ShouldThrow() {
        XCTAssertThrowsError(try validator.validateFPS(10)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateFPS(45)) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateFPS(120)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Quality Validation Tests
    
    func testValidateQuality_ValidValues_ShouldReturnCorrectEnum() throws {
        XCTAssertEqual(try validator.validateQuality("low"), .low)
        XCTAssertEqual(try validator.validateQuality("medium"), .medium)
        XCTAssertEqual(try validator.validateQuality("high"), .high)
        
        // Test case insensitive
        XCTAssertEqual(try validator.validateQuality("LOW"), .low)
        XCTAssertEqual(try validator.validateQuality("Medium"), .medium)
        XCTAssertEqual(try validator.validateQuality("HIGH"), .high)
    }
    
    func testValidateQuality_InvalidValues_ShouldThrow() {
        XCTAssertThrowsError(try validator.validateQuality("invalid")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validateQuality("best")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Format Validation Tests
    
    func testGetOutputFormat_ShouldAlwaysReturnMOV() throws {
        // Format is now fixed to MOV
        XCTAssertEqual(validator.getOutputFormat(), .mov)
    }
    

    
    // MARK: - Countdown Validation Tests
    
    func testValidateCountdown_ValidValues_ShouldNotThrow() throws {
        try validator.validateCountdown(0)
        try validator.validateCountdown(3)
        try validator.validateCountdown(10)
    }
    
    func testValidateCountdown_NegativeValue_ShouldThrow() {
        XCTAssertThrowsError(try validator.validateCountdown(-1)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Preset Name Validation Tests
    
    func testValidatePresetName_ValidNames_ShouldNotThrow() throws {
        try validator.validatePresetName("meeting")
        try validator.validatePresetName("demo-setup")
        try validator.validatePresetName("test_config")
        try validator.validatePresetName("preset123")
    }
    
    func testValidatePresetName_InvalidNames_ShouldThrow() {
        XCTAssertThrowsError(try validator.validatePresetName("")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validatePresetName("   ")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validatePresetName("preset with spaces")) { error in
            XCTAssertTrue(error is ValidationError)
        }
        
        XCTAssertThrowsError(try validator.validatePresetName("preset@special")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Output Path Validation Tests
    
    func testValidateOutputPath_ValidPaths_ShouldReturnURL() throws {
        // Test with explicit path
        let url1 = try validator.validateOutputPath("/tmp/test.mov")
        XCTAssertEqual(url1.lastPathComponent, "test.mov")
        
        // Test with nil (should generate default name)
        let url2 = try validator.validateOutputPath(nil)
        XCTAssertTrue(url2.lastPathComponent.hasSuffix(".mov"))
        XCTAssertTrue(url2.lastPathComponent.contains("-"))
    }
    
    func testValidateOutputPath_WithForceFlag_ShouldReturnOriginalURL() throws {
        // Create a temporary file to test force overwrite behavior
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-force.mov")
        
        // Create the file
        FileManager.default.createFile(atPath: testFile.path, contents: Data("test".utf8))
        defer {
            try? FileManager.default.removeItem(at: testFile)
        }
        
        // Test without force flag (should generate numbered filename)
        let url1 = try validator.validateOutputPath(testFile.path, format: .mov, overwrite: false)
        XCTAssertNotEqual(url1.lastPathComponent, "test-force.mov")
        XCTAssertTrue(url1.lastPathComponent.contains("test-force"))
        
        // Test with force flag (should return original filename)
        let url2 = try validator.validateOutputPath(testFile.path, format: .mov, overwrite: true)
        XCTAssertEqual(url2.lastPathComponent, "test-force.mov")
    }
}

// MARK: - Mock Classes

class MockDisplayManager: DisplayManager {
    var mockScreens: [ScreenInfo] = []
    var shouldThrowError = false
    
    override func getAllScreens() throws -> [ScreenInfo] {
        if shouldThrowError {
            throw SwiftCaptureError.systemRequirementsNotMet
        }
        return mockScreens
    }
    
    override func getScreen(at index: Int) throws -> ScreenInfo {
        if shouldThrowError {
            throw SwiftCaptureError.systemRequirementsNotMet
        }
        
        guard let screen = mockScreens.first(where: { $0.index == index }) else {
            throw SwiftCaptureError.screenNotFound(index)
        }
        
        return screen
    }
    
    override func validateScreen(_ index: Int) throws {
        _ = try getScreen(at: index)
    }
    
    override func parseAndValidateArea(_ areaString: String, for screenIndex: Int) throws -> RecordingArea {
        let area = try RecordingArea.parse(from: areaString)
        let screen = try getScreen(at: screenIndex)
        try area.validate(against: screen)
        return area
    }
}