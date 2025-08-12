import Foundation

/// Information about a running application
struct ApplicationInfo {
    /// Application bundle identifier
    let bundleIdentifier: String
    
    /// Application display name
    let name: String
    
    /// Process ID
    let processID: pid_t
    
    /// Application windows
    let windows: [WindowInfo]
    
    /// Whether the application is currently running
    let isRunning: Bool
}

extension ApplicationInfo: Equatable {
    static func == (lhs: ApplicationInfo, rhs: ApplicationInfo) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.processID == rhs.processID
    }
}

extension ApplicationInfo: CustomStringConvertible {
    var description: String {
        let windowCount = windows.count
        let windowText = windowCount == 1 ? "window" : "windows"
        return "\(name) (\(bundleIdentifier)) - \(windowCount) \(windowText)"
    }
}