import XCTest
@testable import SwiftCapture

final class MockDisplayManagerTests: XCTestCase {
    
    var mockDisplayManager: MockDisplayManager!
    
    override func setUp() {
        super.setUp()
        mockDisplayManager = MockDisplayManager()
    }
    
    override func tearDown() {
        mockDisplayManager = nil
        super.tearDown()
    }
    
    // MARK: - Mock Display Manager Tests
    
    func testGetAllScreens_WithMockScreens_ShouldReturnMockData() throws {
        // Setup mock screens
        let screen1 = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Built-in Display",
            isPrimary: true,
            scaleFactor: 2.0
        )
        
        let screen2 = ScreenInfo(
            index: 2,
            displayID: 2,
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            name: "External Display",
            isPrimary: false,
            scaleFactor: 1.0
        )
        
        mockDisplayManager.mockScreens = [screen1, screen2]
        
        let screens = try mockDisplayManager.getAllScreens()
        
        XCTAssertEqual(screens.count, 2)
        XCTAssertEqual(screens[0].index, 1)
        XCTAssertEqual(screens[0].name, "Built-in Display")
        XCTAssertTrue(screens[0].isPrimary)
        XCTAssertEqual(screens[1].index, 2)
        XCTAssertEqual(screens[1].name, "External Display")
        XCTAssertFalse(screens[1].isPrimary)
    }
    
    func testGetScreen_ValidIndex_ShouldReturnCorrectScreen() throws {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 2.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        
        let retrievedScreen = try mockDisplayManager.getScreen(at: 1)
        
        XCTAssertEqual(retrievedScreen.index, 1)
        XCTAssertEqual(retrievedScreen.name, "Test Display")
        XCTAssertEqual(retrievedScreen.frame.width, 1920)
        XCTAssertEqual(retrievedScreen.frame.height, 1080)
    }
    
    func testGetScreen_InvalidIndex_ShouldThrowError() {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 2.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        
        XCTAssertThrowsError(try mockDisplayManager.getScreen(at: 2)) { error in
            XCTAssertTrue(error is ScreenRecorderError)
            if case .screenNotFound(let index) = error as! ScreenRecorderError {
                XCTAssertEqual(index, 2)
            } else {
                XCTFail("Expected screenNotFound error")
            }
        }
    }
    
    func testValidateScreen_ValidIndex_ShouldNotThrow() throws {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 2.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        
        try mockDisplayManager.validateScreen(1)
    }
    
    func testValidateScreen_InvalidIndex_ShouldThrow() {
        mockDisplayManager.mockScreens = []
        
        XCTAssertThrowsError(try mockDisplayManager.validateScreen(1)) { error in
            XCTAssertTrue(error is ScreenRecorderError)
        }
    }
    
    func testParseAndValidateArea_ValidArea_ShouldReturnParsedArea() throws {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 1.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        
        let area = try mockDisplayManager.parseAndValidateArea("100:200:800:600", for: 1)
        
        if case .customRect(let rect) = area {
            XCTAssertEqual(rect.origin.x, 100)
            XCTAssertEqual(rect.origin.y, 200)
            XCTAssertEqual(rect.width, 800)
            XCTAssertEqual(rect.height, 600)
        } else {
            XCTFail("Expected customRect, got \(area)")
        }
    }
    
    func testParseAndValidateArea_AreaExceedsScreen_ShouldThrow() {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 1.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        
        // Area that exceeds screen bounds
        XCTAssertThrowsError(try mockDisplayManager.parseAndValidateArea("0:0:3000:2000", for: 1)) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testMockDisplayManager_ErrorMode_ShouldThrowErrors() {
        mockDisplayManager.shouldThrowError = true
        
        XCTAssertThrowsError(try mockDisplayManager.getAllScreens()) { error in
            XCTAssertTrue(error is ScreenRecorderError)
            if case .systemRequirementsNotMet = error as! ScreenRecorderError {
                // Expected error
            } else {
                XCTFail("Expected systemRequirementsNotMet error")
            }
        }
        
        XCTAssertThrowsError(try mockDisplayManager.getScreen(at: 1)) { error in
            XCTAssertTrue(error is ScreenRecorderError)
        }
    }
    
    // MARK: - Integration with Parameter Validator Tests
    
    func testParameterValidator_WithMockDisplayManager_ShouldWorkCorrectly() throws {
        let screen = ScreenInfo(
            index: 1,
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            name: "Test Display",
            isPrimary: true,
            scaleFactor: 1.0
        )
        
        mockDisplayManager.mockScreens = [screen]
        let validator = ParameterValidator(displayManager: mockDisplayManager)
        
        // Should validate successfully
        try validator.validateScreen(1)
        
        // Should parse and validate area correctly
        let area = try validator.validateArea("100:200:800:600", for: 1)
        if case .customRect(let rect) = area {
            XCTAssertEqual(rect.width, 800)
            XCTAssertEqual(rect.height, 600)
        } else {
            XCTFail("Expected customRect")
        }
    }
    
    func testParameterValidator_WithMockDisplayManager_InvalidScreen_ShouldThrow() {
        mockDisplayManager.mockScreens = [] // No screens available
        let validator = ParameterValidator(displayManager: mockDisplayManager)
        
        XCTAssertThrowsError(try validator.validateScreen(1)) { error in
            XCTAssertTrue(error is ScreenRecorderError)
        }
    }
    
    // MARK: - Mock Behavior Tests
    
    func testMockDisplayManager_MultipleScreens_ShouldHandleCorrectly() throws {
        let screens = [
            ScreenInfo(index: 1, displayID: 1, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), name: "Primary", isPrimary: true, scaleFactor: 2.0),
            ScreenInfo(index: 2, displayID: 2, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440), name: "Secondary", isPrimary: false, scaleFactor: 1.0),
            ScreenInfo(index: 3, displayID: 3, frame: CGRect(x: 4480, y: 0, width: 1920, height: 1080), name: "Tertiary", isPrimary: false, scaleFactor: 1.0)
        ]
        
        mockDisplayManager.mockScreens = screens
        
        // Test getting all screens
        let allScreens = try mockDisplayManager.getAllScreens()
        XCTAssertEqual(allScreens.count, 3)
        
        // Test getting specific screens
        let screen1 = try mockDisplayManager.getScreen(at: 1)
        XCTAssertEqual(screen1.name, "Primary")
        XCTAssertTrue(screen1.isPrimary)
        
        let screen2 = try mockDisplayManager.getScreen(at: 2)
        XCTAssertEqual(screen2.name, "Secondary")
        XCTAssertFalse(screen2.isPrimary)
        
        let screen3 = try mockDisplayManager.getScreen(at: 3)
        XCTAssertEqual(screen3.name, "Tertiary")
        XCTAssertFalse(screen3.isPrimary)
        
        // Test validation
        try mockDisplayManager.validateScreen(1)
        try mockDisplayManager.validateScreen(2)
        try mockDisplayManager.validateScreen(3)
        
        XCTAssertThrowsError(try mockDisplayManager.validateScreen(4))
    }
    
    func testMockDisplayManager_EmptyScreens_ShouldHandleGracefully() throws {
        mockDisplayManager.mockScreens = []
        
        let screens = try mockDisplayManager.getAllScreens()
        XCTAssertTrue(screens.isEmpty)
        
        XCTAssertThrowsError(try mockDisplayManager.getScreen(at: 1))
        XCTAssertThrowsError(try mockDisplayManager.validateScreen(1))
    }
}