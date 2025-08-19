import Foundation
import CoreGraphics
import ScreenCaptureKit
import IOKit.graphics

/// Manages display detection, selection, and screen information
class DisplayManager {
    
    /// Lists all available screens to the console
    /// Used for the --screen-list command
    /// - Parameter jsonOutput: Whether to output in JSON format
    func listScreens(jsonOutput: Bool = false) throws {
        let screens = try getAllScreens()
        
        if screens.isEmpty {
            if jsonOutput {
                let output = ScreenListJSON(screens: [])
                print(try output.toJSONString())
            } else {
                print("No screens detected.")
            }
            return
        }
        
        if jsonOutput {
            let output = ScreenListJSON(screens: screens)
            print(try output.toJSONString())
        } else {
            print("Available screens:")
            for screen in screens {
                print("  \(screen)")
            }
            print("")
        }
    }
    
    /// Gets information for a specific screen by index
    /// - Parameter index: 1-based screen index
    /// - Returns: ScreenInfo for the specified screen
    /// - Throws: SwiftCaptureError if screen not found
    func getScreen(at index: Int) throws -> ScreenInfo {
        let screens = try getAllScreens()
        
        guard let screen = screens.first(where: { $0.index == index }) else {
            throw SwiftCaptureError.screenNotFound(index)
        }
        
        return screen
    }
    
    /// Gets all available screens
    /// - Returns: Array of ScreenInfo objects
    /// - Throws: SwiftCaptureError if screen detection fails
    func getAllScreens() throws -> [ScreenInfo] {
        // Get all online displays
        let maxDisplays: UInt32 = 32
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        
        let result = CGGetOnlineDisplayList(maxDisplays, &displayIDs, &displayCount)
        guard result == .success else {
            throw SwiftCaptureError.systemRequirementsNotMet
        }
        
        var screens: [ScreenInfo] = []
        let primaryDisplayID = CGMainDisplayID()
        
        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let frame = CGDisplayBounds(displayID)
            let name = getDisplayName(for: displayID)
            let isPrimary = displayID == primaryDisplayID
            let scaleFactor = getDisplayScaleFactor(for: displayID)
            
            let screenInfo = ScreenInfo(
                index: i + 1, // 1-based indexing for user display
                displayID: displayID,
                frame: frame,
                name: name,
                isPrimary: isPrimary,
                scaleFactor: scaleFactor
            )
            
            screens.append(screenInfo)
        }
        
        // Sort screens with primary first, then by index
        screens.sort { lhs, rhs in
            if lhs.isPrimary && !rhs.isPrimary {
                return true
            } else if !lhs.isPrimary && rhs.isPrimary {
                return false
            } else {
                return lhs.index < rhs.index
            }
        }
        
        // Re-index after sorting to maintain 1-based indexing
        for (index, _) in screens.enumerated() {
            screens[index] = ScreenInfo(
                index: index + 1,
                displayID: screens[index].displayID,
                frame: screens[index].frame,
                name: screens[index].name,
                isPrimary: screens[index].isPrimary,
                scaleFactor: screens[index].scaleFactor
            )
        }
        
        return screens
    }
    
    /// Validates that a screen index exists
    /// - Parameter index: 1-based screen index to validate
    /// - Throws: SwiftCaptureError if screen not found
    func validateScreen(_ index: Int) throws {
        _ = try getScreen(at: index)
    }
    
    /// Validates a recording area against a specific screen
    /// - Parameters:
    ///   - area: The recording area to validate
    ///   - screenIndex: 1-based screen index to validate against (defaults to 1 if not specified)
    /// - Throws: SwiftCaptureError or ValidationError if validation fails
    func validateArea(_ area: RecordingArea, for screenIndex: Int) throws {
        let screen = try getScreen(at: screenIndex)
        try area.validate(against: screen)
    }
    
    /// Parses and validates an area string against a specific screen
    /// - Parameters:
    ///   - areaString: String representation of the area (e.g., "0:0:1920:1080" or "center:800:600")
    ///   - screenIndex: 1-based screen index to validate against
    /// - Returns: Validated RecordingArea
    /// - Throws: ValidationError or SwiftCaptureError if parsing or validation fails
    func parseAndValidateArea(_ areaString: String, for screenIndex: Int) throws -> RecordingArea {
        let area = try RecordingArea.parse(from: areaString)
        try validateArea(area, for: screenIndex)
        return area
    }
    
    /// Gets the effective recording area for a screen, with bounds checking
    /// - Parameters:
    ///   - area: The recording area specification
    ///   - screenIndex: 1-based screen index
    /// - Returns: CGRect representing the actual recording area
    /// - Throws: SwiftCaptureError if screen not found or area is invalid
    func getEffectiveRecordingArea(_ area: RecordingArea, for screenIndex: Int) throws -> CGRect {
        let screen = try getScreen(at: screenIndex)
        try area.validate(against: screen)
        return area.toCGRect(for: screen)
    }
    
    // MARK: - Private Methods
    
    /// Gets the display name for a given display ID
    /// - Parameter displayID: Core Graphics display ID
    /// - Returns: Human-readable display name
    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        // Try to get the display name from IOKit
        if let name = getIODisplayName(for: displayID) {
            return name
        }
        
        // Fallback to generic naming
        let isPrimary = displayID == CGMainDisplayID()
        return isPrimary ? "Built-in Display" : "External Display"
    }
    
    /// Gets display name from IOKit registry
    /// - Parameter displayID: Core Graphics display ID
    /// - Returns: Display name if available
    private func getIODisplayName(for displayID: CGDirectDisplayID) -> String? {
        // Get the display mode for resolution info
        guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        
        // Get basic display information
        let width = mode.pixelWidth
        let height = mode.pixelHeight
        let refreshRate = mode.refreshRate
        let scaleFactor = getDisplayScaleFactor(for: displayID)
        
        // Get additional display properties
        let isBuiltin = CGDisplayIsBuiltin(displayID) == 1
        let isMain = displayID == CGMainDisplayID()
        
        // Build clean display name for both text and JSON output
        let baseType = isBuiltin ? "Built-in Display" : "External Display"
        let resolution = "\(width)x\(height)"
        let refresh = "@\(Int(refreshRate))Hz"
        let scale = "(\(String(format: "%.1fx", scaleFactor)) scale)"
        
        var components = [baseType, resolution, refresh, scale]
        
        if isMain {
            components.append("Primary")
        }
        
        return components.joined(separator: " - ")
    }
    
    /// Gets the display scale factor for a given display ID
    /// - Parameter displayID: Core Graphics display ID
    /// - Returns: Scale factor (1.0 for non-Retina, 2.0+ for Retina)
    private func getDisplayScaleFactor(for displayID: CGDirectDisplayID) -> CGFloat {
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            let pixelWidth = mode.pixelWidth
            let pointWidth = Int(CGDisplayBounds(displayID).width)
            return CGFloat(pixelWidth) / CGFloat(pointWidth)
        }
        return 1.0
    }
}

/// Screen recorder specific errors
enum SwiftCaptureError: LocalizedError {
    case screenNotFound(Int)
    case systemRequirementsNotMet
    case invalidArea(String)
    case applicationNotFound(String)
    case invalidOutputPath(String)
    case recordingFailed(Error)
    case audioSetupFailed(Error)
    case presetNotFound(String)
    case presetAlreadyExists(String)
    case invalidDuration(Int)
    
    var errorDescription: String? {
        switch self {
        case .screenNotFound(let index):
            return "Screen \(index) not found. Use --screen-list to see available screens."
        case .systemRequirementsNotMet:
            return "System requirements not met. macOS 12.3+ required for ScreenCaptureKit."
        case .invalidArea(let area):
            return "Invalid area format: '\(area)'. Expected format: x:y:width:height"
        case .applicationNotFound(let name):
            return "Application '\(name)' not found. Use --app-list to see running applications."
        case .invalidOutputPath(let path):
            return "Invalid output path: '\(path)'. Check directory permissions."
        case .recordingFailed(let error):
            return "Recording failed: \(error.localizedDescription)"
        case .audioSetupFailed(let error):
            return "Audio setup failed: \(error.localizedDescription)"
        case .presetNotFound(let name):
            return "Preset '\(name)' not found. Use --list-presets to see available presets."
        case .presetAlreadyExists(let name):
            return "Preset '\(name)' already exists. Use a different name or delete the existing preset."
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration)ms. Duration must be at least 100ms."
        }
    }
}