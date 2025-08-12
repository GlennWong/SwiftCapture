import Foundation
import CoreGraphics

/// Information about a display screen
struct ScreenInfo {
    /// Screen index (1-based for user display)
    let index: Int
    
    /// Core Graphics display ID
    let displayID: CGDirectDisplayID
    
    /// Screen frame in global coordinates
    let frame: CGRect
    
    /// Display name
    let name: String
    
    /// Whether this is the primary display
    let isPrimary: Bool
    
    /// Display scale factor (e.g., 2.0 for Retina)
    let scaleFactor: CGFloat
}

extension ScreenInfo: Equatable {
    static func == (lhs: ScreenInfo, rhs: ScreenInfo) -> Bool {
        return lhs.displayID == rhs.displayID
    }
}

extension ScreenInfo: CustomStringConvertible {
    var description: String {
        let primaryText = isPrimary ? " (Primary)" : ""
        // Display pixel resolution only
        let pixelWidth = Int(frame.width * scaleFactor)
        let pixelHeight = Int(frame.height * scaleFactor)
        return "Screen \(index): \(name) - \(pixelWidth)x\(pixelHeight)\(primaryText)"
    }
}