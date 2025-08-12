import Foundation
import CoreGraphics

/// Defines the area to be recorded
enum RecordingArea: Equatable {
    /// Record the entire screen
    case fullScreen
    
    /// Record a custom rectangular area (x, y, width, height)
    case customRect(CGRect)
    
    /// Record a centered area with specified dimensions
    case centered(width: Int, height: Int)
    
    /// Convert the recording area to a CGRect for the given screen (using pixel coordinates)
    /// - Parameter screen: The target screen information
    /// - Returns: CGRect representing the recording area in pixel coordinates
    func toCGRect(for screen: ScreenInfo) -> CGRect {
        let screenFrame = screen.frame
        let scaleFactor = screen.scaleFactor
        
        switch self {
        case .fullScreen:
            // Return the full screen in pixel coordinates
            return CGRect(
                x: screenFrame.origin.x * scaleFactor,
                y: screenFrame.origin.y * scaleFactor,
                width: screenFrame.width * scaleFactor,
                height: screenFrame.height * scaleFactor
            )
            
        case .customRect(let rect):
            // Custom rect is already in pixel coordinates, return as-is
            return rect
            
        case .centered(let width, let height):
            // Calculate centered position in pixel coordinates
            let pixelWidth = screenFrame.width * scaleFactor
            let pixelHeight = screenFrame.height * scaleFactor
            let x = screenFrame.origin.x * scaleFactor + (pixelWidth - CGFloat(width)) / 2
            let y = screenFrame.origin.y * scaleFactor + (pixelHeight - CGFloat(height)) / 2
            return CGRect(x: x, y: y, width: CGFloat(width), height: CGFloat(height))
        }
    }
    
    /// Convert the recording area to a CGRect for ScreenCaptureKit (using logical coordinates)
    /// - Parameter screen: The target screen information
    /// - Returns: CGRect representing the recording area in logical coordinates for SCStreamConfiguration
    func toLogicalRect(for screen: ScreenInfo) -> CGRect {
        let screenFrame = screen.frame
        let scaleFactor = screen.scaleFactor
        
        switch self {
        case .fullScreen:
            // Return the full screen in logical coordinates
            return screenFrame
            
        case .customRect(let rect):
            // Convert pixel coordinates to logical coordinates
            return CGRect(
                x: rect.origin.x / scaleFactor,
                y: rect.origin.y / scaleFactor,
                width: rect.width / scaleFactor,
                height: rect.height / scaleFactor
            )
            
        case .centered(let width, let height):
            // Calculate centered position in logical coordinates
            let logicalWidth = screenFrame.width
            let logicalHeight = screenFrame.height
            let x = screenFrame.origin.x + (logicalWidth - CGFloat(width) / scaleFactor) / 2
            let y = screenFrame.origin.y + (logicalHeight - CGFloat(height) / scaleFactor) / 2
            return CGRect(x: x, y: y, width: CGFloat(width) / scaleFactor, height: CGFloat(height) / scaleFactor)
        }
    }
    
    /// Validates that the recording area is within screen bounds (using pixel coordinates)
    /// - Parameter screen: The target screen information
    /// - Throws: ValidationError if the area is outside screen bounds
    func validate(against screen: ScreenInfo) throws {
        let recordingRect = self.toCGRect(for: screen)
        let screenFrame = screen.frame
        let pixelWidth = screenFrame.width * screen.scaleFactor
        let pixelHeight = screenFrame.height * screen.scaleFactor
        
        // For custom rectangles, validate against the pixel coordinate space
        let isWithinBounds: Bool
        switch self {
        case .fullScreen:
            // Full screen is always valid for the target screen
            isWithinBounds = true
            
        case .customRect(let rect):
            // For custom rectangles, check if the area fits within the screen's pixel bounds
            // All coordinates are now treated as pixel coordinates
            isWithinBounds = rect.origin.x >= 0 &&
                           rect.origin.y >= 0 &&
                           rect.maxX <= pixelWidth &&
                           rect.maxY <= pixelHeight
            
        case .centered(let width, let height):
            // For centered areas, check if the dimensions fit within the screen pixel dimensions
            isWithinBounds = CGFloat(width) <= pixelWidth && CGFloat(height) <= pixelHeight
        }
        
        guard isWithinBounds else {
            let errorMessage: String
            let suggestion: String
            let pixelWidthInt = Int(pixelWidth)
            let pixelHeightInt = Int(pixelHeight)
            
            switch self {
            case .fullScreen:
                // Full screen should always be valid, but just in case
                errorMessage = "Full screen recording area is invalid"
                suggestion = "This should not happen. Please report this issue."
                
            case .customRect(let rect):
                errorMessage = "Recording area \(Int(rect.origin.x)):\(Int(rect.origin.y)):\(Int(rect.width)):\(Int(rect.height)) extends beyond screen \(screen.index) bounds"
                suggestion = "Screen \(screen.index) (\(screen.name)) has dimensions \(pixelWidthInt)x\(pixelHeightInt) (pixels). Adjust coordinates to fit within screen bounds."
                
            case .centered(let width, let height):
                errorMessage = "Centered area \(width)x\(height) is too large for screen \(screen.index)"
                suggestion = "Screen \(screen.index) (\(screen.name)) has dimensions \(pixelWidthInt)x\(pixelHeightInt) (pixels). Use smaller dimensions or try --area 0:0:\(pixelWidthInt):\(pixelHeightInt) for full screen."
            }
            
            throw ValidationError(errorMessage, suggestion: suggestion)
        }
        
        // Additional validation for minimum size
        guard recordingRect.width >= 1 && recordingRect.height >= 1 else {
            throw ValidationError(
                "Recording area must be at least 1x1 pixels",
                suggestion: "Increase the width and height values in your area specification"
            )
        }
        
        // Warn about very small recording areas
        if recordingRect.width < 100 || recordingRect.height < 100 {
            print("⚠️  Warning: Recording area is very small (\(Int(recordingRect.width))x\(Int(recordingRect.height))). This may result in poor quality recordings.")
        }
        
        // Warn about very large recording areas that might impact performance
        let totalPixels = recordingRect.width * recordingRect.height
        let screenPixels = screenFrame.width * screenFrame.height
        if totalPixels > screenPixels * 0.8 {
            print("ℹ️  Info: Recording large area (\(Int(recordingRect.width))x\(Int(recordingRect.height))). This may impact performance on older systems.")
        }
    }
    
    /// Parse area string from CLI input (format: "x:y:width:height" or "center:width:height")
    /// - Parameter areaString: String representation of the area
    /// - Returns: RecordingArea enum case
    /// - Throws: ValidationError if the format is invalid
    static func parse(from areaString: String) throws -> RecordingArea {
        let components = areaString.split(separator: ":").map(String.init)
        
        if components.count == 3 && components[0].lowercased() == "center" {
            guard let width = Int(components[1]),
                  let height = Int(components[2]),
                  width > 0, height > 0 else {
                throw ValidationError.invalidArea("Invalid centered area format. Expected: center:width:height")
            }
            return .centered(width: width, height: height)
        }
        
        if components.count == 4 {
            guard let x = Int(components[0]),
                  let y = Int(components[1]),
                  let width = Int(components[2]),
                  let height = Int(components[3]),
                  width > 0, height > 0 else {
                throw ValidationError.invalidArea("Invalid area coordinates. Expected: x:y:width:height")
            }
            return .customRect(CGRect(x: CGFloat(x), y: CGFloat(y), 
                                   width: CGFloat(width), height: CGFloat(height)))
        }
        
        throw ValidationError.invalidArea("Invalid area format. Expected: x:y:width:height or center:width:height")
    }
}

extension RecordingArea: CustomStringConvertible {
    var description: String {
        switch self {
        case .fullScreen:
            return "Full Screen"
        case .customRect(let rect):
            return "Custom Area: \(Int(rect.origin.x)):\(Int(rect.origin.y)):\(Int(rect.width)):\(Int(rect.height))"
        case .centered(let width, let height):
            return "Centered Area: \(width)x\(height)"
        }
    }
}