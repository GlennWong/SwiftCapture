import Foundation
import CoreGraphics

/// Information about an application window
struct WindowInfo {
    /// Core Graphics window ID
    let windowID: CGWindowID
    
    /// Window title
    let title: String
    
    /// Window frame in global coordinates
    let frame: CGRect
    
    /// Whether the window is currently visible on screen
    let isOnScreen: Bool
}

extension WindowInfo: Equatable {
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.windowID == rhs.windowID
    }
}

extension WindowInfo: CustomStringConvertible {
    var description: String {
        let visibilityText = isOnScreen ? "visible" : "hidden"
        return "Window: \(title) (\(Int(frame.width))x\(Int(frame.height)), \(visibilityText))"
    }
}