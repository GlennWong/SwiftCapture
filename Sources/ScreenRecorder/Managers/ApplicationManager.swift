import Foundation
import CoreGraphics
import AppKit

/// Manages application detection and selection for screen recording
class ApplicationManager {
    
    /// Error types for application management
    enum ApplicationError: LocalizedError {
        case applicationNotFound(String)
        case noRunningApplications
        case windowAccessDenied
        
        var errorDescription: String? {
            switch self {
            case .applicationNotFound(let name):
                return "Application '\(name)' not found. Use --app-list to see running applications."
            case .noRunningApplications:
                return "No running applications found."
            case .windowAccessDenied:
                return "Unable to access window information. Please grant screen recording permissions in System Preferences > Security & Privacy > Privacy > Screen Recording."
            }
        }
    }
    
    /// Lists all running applications with their information
    /// Requirement 6.1: Display all running applications with their identifiers
    func listApplications() throws {
        let applications = try getAllApplications()
        
        if applications.isEmpty {
            throw ApplicationError.noRunningApplications
        }
        
        print("Available Applications:")
        print("======================")
        
        for (index, app) in applications.enumerated() {
            let windowCount = app.windows.count
            let windowText = windowCount == 1 ? "window" : "windows"
            print("\(index + 1). \(app.name)")
            print("   Bundle ID: \(app.bundleIdentifier)")
            print("   Process ID: \(app.processID)")
            print("   Windows: \(windowCount) \(windowText)")
            
            // Show window details if there are windows
            if !app.windows.isEmpty {
                for window in app.windows.prefix(3) { // Show first 3 windows
                    let size = "\(Int(window.frame.width))x\(Int(window.frame.height))"
                    let status = window.isOnScreen ? "visible" : "hidden"
                    print("     - \(window.title.isEmpty ? "Untitled" : window.title) (\(size), \(status))")
                }
                if app.windows.count > 3 {
                    print("     ... and \(app.windows.count - 3) more")
                }
            }
            print()
        }
    }
    
    /// Gets application information by name with fuzzy matching
    /// Requirements 6.2, 6.3: Application selection by name with fuzzy matching
    func getApplication(named name: String) throws -> ApplicationInfo {
        let applications = try getAllApplications()
        
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
            // Multiple matches found, show options
            print("Multiple applications match '\(name)':")
            for (index, app) in fuzzyMatches.enumerated() {
                print("\(index + 1). \(app.name) (\(app.bundleIdentifier))")
            }
            throw ApplicationError.applicationNotFound("Multiple matches found for '\(name)'. Please be more specific.")
        }
        
        // No matches found
        throw ApplicationError.applicationNotFound(name)
    }
    
    /// Gets all running applications with their window information
    /// Requirements 6.4, 6.5: Handle multiple windows and application detection
    func getAllApplications() throws -> [ApplicationInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        var applications: [ApplicationInfo] = []
        
        for app in runningApps {
            // Skip system processes and apps without a bundle identifier
            guard let bundleId = app.bundleIdentifier,
                  app.activationPolicy == .regular,
                  !bundleId.hasPrefix("com.apple.") || bundleId.contains("Safari") || bundleId.contains("Finder") else {
                continue
            }
            
            let appName = app.localizedName ?? bundleId
            let processId = app.processIdentifier
            
            // Get windows for this application
            let windows = getWindows(for: processId)
            
            let applicationInfo = ApplicationInfo(
                bundleIdentifier: bundleId,
                name: appName,
                processID: processId,
                windows: windows,
                isRunning: !app.isTerminated
            )
            
            applications.append(applicationInfo)
        }
        
        // Sort applications by name for consistent output
        return applications.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    /// Gets window information for a specific process
    /// Requirement 6.4: Handle multiple windows for single application
    private func getWindows(for processID: pid_t) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [WindowInfo] = []
        
        for windowDict in windowList {
            // Check if this window belongs to our process
            guard let windowPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == processID else {
                continue
            }
            
            // Extract window information
            let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID ?? 0
            let windowTitle = windowDict[kCGWindowName as String] as? String ?? ""
            
            // Get window bounds
            var windowFrame = CGRect.zero
            if let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] {
                windowFrame = CGRect(
                    x: boundsDict["X"] as? CGFloat ?? 0,
                    y: boundsDict["Y"] as? CGFloat ?? 0,
                    width: boundsDict["Width"] as? CGFloat ?? 0,
                    height: boundsDict["Height"] as? CGFloat ?? 0
                )
            }
            
            // Check if window is on screen
            let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? false
            
            // Skip windows that are too small (likely system windows)
            guard windowFrame.width > 50 && windowFrame.height > 50 else {
                continue
            }
            
            let windowInfo = WindowInfo(
                windowID: windowID,
                title: windowTitle,
                frame: windowFrame,
                isOnScreen: isOnScreen
            )
            
            windows.append(windowInfo)
        }
        
        // Sort windows by title for consistent output
        return windows.sorted { $0.title.lowercased() < $1.title.lowercased() }
    }
    
    /// Validates that an application is suitable for recording
    /// Requirement 6.5: Error handling for minimized or hidden applications
    func validateApplicationForRecording(_ application: ApplicationInfo) throws {
        // Check if application is still running
        guard application.isRunning else {
            throw ApplicationError.applicationNotFound("Application '\(application.name)' is no longer running")
        }
        
        // Check if application has any windows
        guard !application.windows.isEmpty else {
            print("Warning: Application '\(application.name)' has no visible windows")
            return
        }
        
        // Check if any windows are visible
        let visibleWindows = application.windows.filter { $0.isOnScreen }
        if visibleWindows.isEmpty {
            print("Warning: All windows for '\(application.name)' are minimized or hidden")
        }
    }
}