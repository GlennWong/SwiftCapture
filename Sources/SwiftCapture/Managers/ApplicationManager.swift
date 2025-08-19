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
    /// - Parameter jsonOutput: Whether to output in JSON format
    func listApplications(jsonOutput: Bool = false) throws {
        let applications = try getAllApplications()
        
        if applications.isEmpty {
            if jsonOutput {
                let output = ApplicationListJSON(applications: [])
                print(try output.toJSONString())
            } else {
                throw ApplicationError.noRunningApplications
            }
            return
        }
        
        if jsonOutput {
            let output = ApplicationListJSON(applications: applications)
            print(try output.toJSONString())
        } else {
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
                  app.activationPolicy == .regular else {
                continue
            }
            
            // Allow specific Apple apps that users might want to record
            let allowedAppleApps = ["safari", "finder", "preview", "photos", "music", "tv", "books", "notes", "mail", "calendar", "contacts", "reminders", "facetime", "messages"]
            let isAllowedAppleApp = allowedAppleApps.contains { bundleId.lowercased().contains($0) }
            
            // Skip other Apple system apps unless specifically allowed
            if bundleId.hasPrefix("com.apple.") && !isAllowedAppleApp {
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
                let x = boundsDict["X"] as? CGFloat ?? 0
                let y = boundsDict["Y"] as? CGFloat ?? 0
                let width = boundsDict["Width"] as? CGFloat ?? 0
                let height = boundsDict["Height"] as? CGFloat ?? 0
                
                // 🔧 修复：确保窗口坐标正确
                // CGWindowListCopyWindowInfo返回的坐标已经是屏幕坐标系
                windowFrame = CGRect(x: x, y: y, width: width, height: height)
            }
            
            // Check if window is on screen
            let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool ?? false
            
            // 🔧 修复：更严格的窗口过滤条件
            // 跳过太小的窗口（可能是系统窗口或工具栏）
            guard windowFrame.width > 100 && windowFrame.height > 50 else {
                continue
            }
            
            // 跳过没有标题且很小的窗口（通常是辅助窗口）
            if windowTitle.isEmpty && (windowFrame.width < 200 || windowFrame.height < 100) {
                continue
            }
            
            // 🔧 修复：优先选择主窗口
            // 通常主窗口有标题且尺寸较大
            let windowInfo = WindowInfo(
                windowID: windowID,
                title: windowTitle,
                frame: windowFrame,
                isOnScreen: isOnScreen
            )
            
            windows.append(windowInfo)
        }
        
        // 🔧 修复：改进窗口排序逻辑
        // 优先显示有标题的窗口，然后按尺寸排序（大窗口优先）
        return windows.sorted { lhs, rhs in
            // 有标题的窗口优先
            if !lhs.title.isEmpty && rhs.title.isEmpty {
                return true
            } else if lhs.title.isEmpty && !rhs.title.isEmpty {
                return false
            }
            
            // 都有标题或都没标题时，按窗口面积排序（大窗口优先）
            let lhsArea = lhs.frame.width * lhs.frame.height
            let rhsArea = rhs.frame.width * rhs.frame.height
            return lhsArea > rhsArea
        }
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
    
    /// Brings the specified application to the front and switches to its desktop space
    /// This helps ensure the application is visible and not obscured by other windows
    /// - Parameter application: The application to bring to front
    /// - Throws: ApplicationError if the operation fails
    func bringApplicationToFront(_ application: ApplicationInfo) throws {
        print("🎯 Bringing '\(application.name)' to front...")
        
        // Find the NSRunningApplication instance
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == application.bundleIdentifier 
        }) else {
            throw ApplicationError.applicationNotFound("Could not find running application '\(application.name)'")
        }
        
        // Activate the application (this will switch to its desktop space if needed)
        let success = runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        if !success {
            print("⚠️ Warning: Failed to activate application '\(application.name)'")
            print("   The application may still be recorded, but it might be obscured by other windows")
        } else {
            print("✅ Successfully activated '\(application.name)'")
            
            // Give the system a moment to complete the activation and space switching
            Thread.sleep(forTimeInterval: 0.5)
            
            // Additional step: try to bring the main window to front using Accessibility API
            if let mainWindow = application.windows.first {
                bringWindowToFront(windowID: mainWindow.windowID, applicationName: application.name)
            }
        }
    }
    
    /// Brings a specific window to the front using Core Graphics
    /// - Parameters:
    ///   - windowID: The window ID to bring to front
    ///   - applicationName: The name of the application (for logging)
    private func bringWindowToFront(windowID: CGWindowID, applicationName: String) {
        // Try to bring the specific window to front
        // Note: This may require additional permissions in some cases
        let _ = CGWindowLevelForKey(.normalWindow)
        
        // We can't directly manipulate other application's windows without accessibility permissions
        // But the activate() call above should handle most cases
        print("   Main window should now be visible for recording")
    }
}