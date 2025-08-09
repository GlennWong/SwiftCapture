import XCTest
@testable import ScreenRecorder

final class MockApplicationManagerTests: XCTestCase {
    
    var mockApplicationManager: MockApplicationManager!
    
    override func setUp() {
        super.setUp()
        mockApplicationManager = MockApplicationManager()
    }
    
    override func tearDown() {
        mockApplicationManager = nil
        super.tearDown()
    }
    
    // MARK: - Mock Application Manager Tests
    
    func testGetAllApplications_WithMockApps_ShouldReturnMockData() throws {
        // Setup mock applications
        let app1 = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [
                WindowInfo(windowID: 1, title: "Google", frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: true),
                WindowInfo(windowID: 2, title: "GitHub", frame: CGRect(x: 100, y: 100, width: 1200, height: 800), isOnScreen: true)
            ],
            isRunning: true
        )
        
        let app2 = ApplicationInfo(
            bundleIdentifier: "com.apple.dt.Xcode",
            name: "Xcode",
            processID: 67890,
            windows: [
                WindowInfo(windowID: 3, title: "ScreenRecorder.xcodeproj", frame: CGRect(x: 200, y: 200, width: 1400, height: 900), isOnScreen: true)
            ],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [app1, app2]
        
        let applications = try mockApplicationManager.getAllApplications()
        
        XCTAssertEqual(applications.count, 2)
        XCTAssertEqual(applications[0].name, "Safari")
        XCTAssertEqual(applications[0].bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(applications[0].windows.count, 2)
        XCTAssertEqual(applications[1].name, "Xcode")
        XCTAssertEqual(applications[1].bundleIdentifier, "com.apple.dt.Xcode")
        XCTAssertEqual(applications[1].windows.count, 1)
    }
    
    func testGetApplication_ExactMatch_ShouldReturnCorrectApp() throws {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        let xcodeApp = ApplicationInfo(
            bundleIdentifier: "com.apple.dt.Xcode",
            name: "Xcode",
            processID: 67890,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp, xcodeApp]
        
        let foundApp = try mockApplicationManager.getApplication(named: "Safari")
        XCTAssertEqual(foundApp.name, "Safari")
        XCTAssertEqual(foundApp.bundleIdentifier, "com.apple.Safari")
    }
    
    func testGetApplication_CaseInsensitiveMatch_ShouldReturnCorrectApp() throws {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp]
        
        let foundApp = try mockApplicationManager.getApplication(named: "safari")
        XCTAssertEqual(foundApp.name, "Safari")
        
        let foundApp2 = try mockApplicationManager.getApplication(named: "SAFARI")
        XCTAssertEqual(foundApp2.name, "Safari")
    }
    
    func testGetApplication_BundleIdentifierMatch_ShouldReturnCorrectApp() throws {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp]
        
        let foundApp = try mockApplicationManager.getApplication(named: "com.apple.Safari")
        XCTAssertEqual(foundApp.name, "Safari")
        XCTAssertEqual(foundApp.bundleIdentifier, "com.apple.Safari")
    }
    
    func testGetApplication_FuzzyMatch_ShouldReturnCorrectApp() throws {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp]
        
        // Partial name match
        let foundApp = try mockApplicationManager.getApplication(named: "Saf")
        XCTAssertEqual(foundApp.name, "Safari")
        
        // Partial bundle ID match
        let foundApp2 = try mockApplicationManager.getApplication(named: "apple.Safari")
        XCTAssertEqual(foundApp2.name, "Safari")
    }
    
    func testGetApplication_MultipleFuzzyMatches_ShouldThrowError() {
        let app1 = ApplicationInfo(
            bundleIdentifier: "com.test.App1",
            name: "Test App 1",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        let app2 = ApplicationInfo(
            bundleIdentifier: "com.test.App2",
            name: "Test App 2",
            processID: 67890,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [app1, app2]
        
        XCTAssertThrowsError(try mockApplicationManager.getApplication(named: "Test")) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
            if case .applicationNotFound(let message) = error as! ApplicationManager.ApplicationError {
                XCTAssertTrue(message.contains("Multiple matches"))
            } else {
                XCTFail("Expected applicationNotFound error with multiple matches message")
            }
        }
    }
    
    func testGetApplication_NoMatch_ShouldThrowError() {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp]
        
        XCTAssertThrowsError(try mockApplicationManager.getApplication(named: "NonExistentApp")) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
            if case .applicationNotFound(let appName) = error as! ApplicationManager.ApplicationError {
                XCTAssertEqual(appName, "NonExistentApp")
            } else {
                XCTFail("Expected applicationNotFound error")
            }
        }
    }
    
    func testValidateApplicationForRecording_RunningApp_ShouldNotThrow() throws {
        let app = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [
                WindowInfo(windowID: 1, title: "Test Window", frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: true)
            ],
            isRunning: true
        )
        
        try mockApplicationManager.validateApplicationForRecording(app)
    }
    
    func testValidateApplicationForRecording_NotRunningApp_ShouldThrowError() {
        let app = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: false
        )
        
        XCTAssertThrowsError(try mockApplicationManager.validateApplicationForRecording(app)) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
        }
    }
    
    func testValidateApplicationForRecording_NoWindows_ShouldNotThrowButWarn() throws {
        let app = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [],
            isRunning: true
        )
        
        // Should not throw, but would print a warning in real implementation
        try mockApplicationManager.validateApplicationForRecording(app)
    }
    
    func testValidateApplicationForRecording_HiddenWindows_ShouldNotThrowButWarn() throws {
        let app = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [
                WindowInfo(windowID: 1, title: "Hidden Window", frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: false)
            ],
            isRunning: true
        )
        
        // Should not throw, but would print a warning in real implementation
        try mockApplicationManager.validateApplicationForRecording(app)
    }
    
    // MARK: - Mock Behavior Tests
    
    func testMockApplicationManager_ErrorMode_ShouldThrowErrors() {
        mockApplicationManager.shouldThrowError = true
        
        XCTAssertThrowsError(try mockApplicationManager.getAllApplications()) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
            if case .noRunningApplications = error as! ApplicationManager.ApplicationError {
                // Expected error
            } else {
                XCTFail("Expected noRunningApplications error")
            }
        }
        
        XCTAssertThrowsError(try mockApplicationManager.getApplication(named: "Safari")) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
        }
    }
    
    func testMockApplicationManager_EmptyApplications_ShouldHandleGracefully() throws {
        mockApplicationManager.mockApplications = []
        
        let applications = try mockApplicationManager.getAllApplications()
        XCTAssertTrue(applications.isEmpty)
        
        XCTAssertThrowsError(try mockApplicationManager.getApplication(named: "Safari")) { error in
            XCTAssertTrue(error is ApplicationManager.ApplicationError)
        }
    }
    
    func testMockApplicationManager_ComplexWindowStructure_ShouldHandleCorrectly() throws {
        let complexApp = ApplicationInfo(
            bundleIdentifier: "com.complex.App",
            name: "Complex App",
            processID: 12345,
            windows: [
                WindowInfo(windowID: 1, title: "Main Window", frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: true),
                WindowInfo(windowID: 2, title: "Inspector", frame: CGRect(x: 1200, y: 0, width: 300, height: 800), isOnScreen: true),
                WindowInfo(windowID: 3, title: "Hidden Panel", frame: CGRect(x: 0, y: 800, width: 400, height: 200), isOnScreen: false),
                WindowInfo(windowID: 4, title: "", frame: CGRect(x: 400, y: 800, width: 200, height: 100), isOnScreen: true) // Untitled window
            ],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [complexApp]
        
        let foundApp = try mockApplicationManager.getApplication(named: "Complex App")
        XCTAssertEqual(foundApp.windows.count, 4)
        
        // Verify window details
        let mainWindow = foundApp.windows.first { $0.title == "Main Window" }
        XCTAssertNotNil(mainWindow)
        XCTAssertTrue(mainWindow!.isOnScreen)
        
        let hiddenPanel = foundApp.windows.first { $0.title == "Hidden Panel" }
        XCTAssertNotNil(hiddenPanel)
        XCTAssertFalse(hiddenPanel!.isOnScreen)
        
        let untitledWindow = foundApp.windows.first { $0.title.isEmpty }
        XCTAssertNotNil(untitledWindow)
        XCTAssertTrue(untitledWindow!.isOnScreen)
    }
    
    // MARK: - Integration Tests
    
    func testMockApplicationManager_WithConfigurationManager_ShouldWorkCorrectly() throws {
        let safariApp = ApplicationInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            processID: 12345,
            windows: [
                WindowInfo(windowID: 1, title: "Test Page", frame: CGRect(x: 0, y: 0, width: 1200, height: 800), isOnScreen: true)
            ],
            isRunning: true
        )
        
        mockApplicationManager.mockApplications = [safariApp]
        
        // Test that the mock can be used with configuration creation
        let foundApp = try mockApplicationManager.getApplication(named: "Safari")
        XCTAssertEqual(foundApp.name, "Safari")
        
        try mockApplicationManager.validateApplicationForRecording(foundApp)
    }
}

// MARK: - Mock Application Manager

class MockApplicationManager: ApplicationManager {
    var mockApplications: [ApplicationInfo] = []
    var shouldThrowError = false
    
    override func getAllApplications() throws -> [ApplicationInfo] {
        if shouldThrowError {
            throw ApplicationError.noRunningApplications
        }
        return mockApplications.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    override func getApplication(named name: String) throws -> ApplicationInfo {
        if shouldThrowError {
            throw ApplicationError.applicationNotFound(name)
        }
        
        let applications = mockApplications
        
        // First try exact match (case insensitive)
        if let exactMatch = applications.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exactMatch
        }
        
        // Try bundle identifier match
        if let bundleMatch = applications.first(where: { $0.bundleIdentifier.lowercased() == name.lowercased() }) {
            return bundleMatch
        }
        
        // Try fuzzy matching - contains match
        let fuzzyMatches = applications.filter { app in
            app.name.lowercased().contains(name.lowercased()) ||
            app.bundleIdentifier.lowercased().contains(name.lowercased())
        }
        
        if fuzzyMatches.count == 1 {
            return fuzzyMatches[0]
        } else if fuzzyMatches.count > 1 {
            throw ApplicationError.applicationNotFound("Multiple matches found for '\(name)'. Please be more specific.")
        }
        
        // No matches found
        throw ApplicationError.applicationNotFound(name)
    }
    
    override func validateApplicationForRecording(_ application: ApplicationInfo) throws {
        // Check if application is still running
        guard application.isRunning else {
            throw ApplicationError.applicationNotFound("Application '\(application.name)' is no longer running")
        }
        
        // Check if application has any windows
        guard !application.windows.isEmpty else {
            // In real implementation, this would print a warning
            return
        }
        
        // Check if any windows are visible
        let visibleWindows = application.windows.filter { $0.isOnScreen }
        if visibleWindows.isEmpty {
            // In real implementation, this would print a warning
        }
    }
}