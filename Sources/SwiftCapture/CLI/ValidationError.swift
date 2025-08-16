import Foundation
import ArgumentParser

/// Custom validation error for CLI arguments
struct ValidationError: Error, LocalizedError {
    let message: String
    let suggestion: String?
    
    init(_ message: String, suggestion: String? = nil) {
        self.message = message
        self.suggestion = suggestion
    }
    
    var errorDescription: String? {
        var description = "❌ \(message)"
        if let suggestion = suggestion {
            description += "\n💡 \(suggestion)"
        }
        return description
    }
}

/// Extension to provide helpful error messages for common validation scenarios
extension ValidationError {
    static func invalidDuration(_ duration: Int) -> ValidationError {
        let suggestion: String
        if duration <= 0 {
            suggestion = "Duration must be positive. Try --duration 1000 (1 second) or --duration 5000 (5 seconds)"
        } else if duration < 100 {
            suggestion = "Duration too short. Minimum is 100ms. Try --duration 1000 (1 second) for testing"
        } else {
            suggestion = "Try using a duration like --duration 1000 (1 second) or --duration 5000 (5 seconds)"
        }
        
        return ValidationError(
            "Invalid duration: \(duration)ms. Duration must be at least 100ms.",
            suggestion: suggestion
        )
    }
    
    static func invalidFPS(_ fps: Int) -> ValidationError {
        let suggestion: String
        if fps < 15 {
            suggestion = "FPS too low. Use --fps 15 for static content, --fps 30 for standard recording"
        } else if fps > 60 {
            suggestion = "FPS too high. Use --fps 60 for smooth motion, --fps 30 for standard recording"
        } else {
            suggestion = "Valid options are 15, 30, or 60. Use --fps 30 for most recordings"
        }
        
        return ValidationError(
            "Invalid frame rate: \(fps). FPS must be 15, 30, or 60.",
            suggestion: suggestion
        )
    }
    
    static func invalidQuality(_ quality: String) -> ValidationError {
        let suggestion: String
        let lowercased = quality.lowercased()
        
        if lowercased.contains("low") || lowercased.contains("small") {
            suggestion = "Did you mean --quality low? Use 'low', 'medium', or 'high'"
        } else if lowercased.contains("high") || lowercased.contains("best") {
            suggestion = "Did you mean --quality high? Use 'low', 'medium', or 'high'"
        } else if lowercased.contains("med") {
            suggestion = "Did you mean --quality medium? Use 'low', 'medium', or 'high'"
        } else {
            suggestion = "Use --quality low (smaller files), --quality medium (balanced), or --quality high (best quality)"
        }
        
        return ValidationError(
            "Invalid quality setting: '\(quality)'. Quality must be 'low', 'medium', or 'high'.",
            suggestion: suggestion
        )
    }
    
    static func formatNotSupported() -> ValidationError {
        ValidationError(
            "Output format is fixed to MOV for optimal quality and compatibility.",
            suggestion: "SwiftCapture always outputs high-quality MOV files. Use .mov extension for output files."
        )
    }
    
    static func invalidScreen(_ screen: Int) -> ValidationError {
        let suggestion: String
        if screen <= 0 {
            suggestion = "Screen indices start at 1. Use --screen-list to see available screens, then --screen 1, --screen 2, etc."
        } else {
            suggestion = "Screen \(screen) may not exist. Use --screen-list to see available screens"
        }
        
        return ValidationError(
            "Invalid screen index: \(screen). Screen index must be 1 or greater.",
            suggestion: suggestion
        )
    }
    
    static func invalidCountdown(_ countdown: Int) -> ValidationError {
        ValidationError(
            "Invalid countdown: \(countdown). Countdown must be 0 or greater.",
            suggestion: "Use --countdown 3 for a 3-second countdown, --countdown 0 for immediate recording, or omit the option"
        )
    }
    
    static func invalidAreaFormat(_ area: String) -> ValidationError {
        let suggestion: String
        let components = area.split(separator: ":")
        
        if components.count < 4 {
            suggestion = "Area needs 4 values separated by colons. Example: --area 0:0:1920:1080 (x:y:width:height)"
        } else if components.count > 4 {
            suggestion = "Too many values. Use format: --area x:y:width:height like --area 0:0:1920:1080"
        } else {
            suggestion = "Check that all values are numbers. Example: --area 0:0:1920:1080 or --area 100:100:800:600"
        }
        
        return ValidationError(
            "Invalid area format: '\(area)'. Area must be in format x:y:width:height.",
            suggestion: suggestion
        )
    }
    
    static func invalidAreaCoordinates(_ area: String) -> ValidationError {
        ValidationError(
            "Invalid area coordinates: '\(area)'. All coordinates must be positive integers.",
            suggestion: "Ensure all values are non-negative numbers. Example: --area 0:0:1920:1080 or --area 100:100:800:600"
        )
    }
    
    static func invalidArea(_ message: String) -> ValidationError {
        ValidationError(
            message,
            suggestion: "Use format x:y:width:height (e.g., --area 0:0:1920:1080) or center:width:height (e.g., --area center:800:600)"
        )
    }
    
    static func conflictingOptions(_ option1: String, _ option2: String) -> ValidationError {
        ValidationError(
            "Conflicting options: \(option1) and \(option2) cannot be used together.",
            suggestion: "Choose either \(option1) or \(option2), but not both. See --help for valid combinations"
        )
    }
    
    static func systemRequirementsNotMet() -> ValidationError {
        ValidationError(
            "System requirements not met. macOS 12.3+ is required for ScreenCaptureKit.",
            suggestion: "Update to macOS 12.3 or later through System Preferences > Software Update"
        )
    }
    
    // Additional specific error types for better user experience
    static func presetNotFound(_ name: String) -> ValidationError {
        ValidationError(
            "Preset '\(name)' not found.",
            suggestion: "Use --list-presets to see available presets, or create one with --save-preset '\(name)'"
        )
    }
    
    static func presetAlreadyExists(_ name: String) -> ValidationError {
        ValidationError(
            "Preset '\(name)' already exists.",
            suggestion: "Use --preset '\(name)' to load it, --delete-preset '\(name)' to remove it, or choose a different name"
        )
    }
    
    static func invalidPresetName(_ name: String) -> ValidationError {
        ValidationError(
            "Invalid preset name: '\(name)'. Preset names can only contain letters, numbers, hyphens, and underscores.",
            suggestion: "Try a name like 'meeting-setup' or 'demo_config' without spaces or special characters"
        )
    }
    
    static func outputFileExists(_ path: String) -> ValidationError {
        ValidationError(
            "Output file already exists: '\(path)'.",
            suggestion: "Use a different filename, or the file will be overwritten. Add timestamp with --output ~/Desktop/recording-$(date +%s).mov"
        )
    }
    
    static func invalidOutputDirectory(_ path: String) -> ValidationError {
        ValidationError(
            "Cannot create output directory: '\(path)'.",
            suggestion: "Check directory permissions or use a different location like ~/Desktop/ or ~/Documents/"
        )
    }
    
    static func invalidOutputPath(_ path: String) -> ValidationError {
        ValidationError(
            "Invalid output path: '\(path)'.",
            suggestion: "Check the file path and permissions, or use a different location like ~/Desktop/ or ~/Documents/"
        )
    }
    
    static func diskSpaceWarning(_ availableGB: Double) -> ValidationError {
        ValidationError(
            "Low disk space warning: Only \(String(format: "%.1f", availableGB))GB available.",
            suggestion: "Free up disk space or use --quality low to reduce file size. High quality recordings can use 1GB+ per minute"
        )
    }
}