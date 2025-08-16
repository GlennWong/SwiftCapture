import Foundation
import CoreGraphics

/// Validates CLI parameters and converts them to appropriate types
class ParameterValidator {
    private let displayManager: DisplayManager
    
    init(displayManager: DisplayManager = DisplayManager()) {
        self.displayManager = displayManager
    }
    
    /// Validate recording duration
    /// - Parameter duration: Duration in milliseconds
    /// - Throws: ValidationError if invalid
    func validateDuration(_ duration: Int) throws {
        guard duration >= 100 else {
            throw ValidationError.invalidDuration(duration)
        }
    }
    
    /// Validate and parse recording area
    /// - Parameter area: Area string in format "x:y:width:height" or "center:width:height"
    /// - Returns: RecordingArea enum
    /// - Throws: ValidationError if invalid
    func validateArea(_ area: String) throws -> RecordingArea {
        return try RecordingArea.parse(from: area)
    }
    
    /// Validate and parse recording area against a specific screen
    /// - Parameters:
    ///   - area: Area string in format "x:y:width:height" or "center:width:height"
    ///   - screenIndex: 1-based screen index to validate against
    /// - Returns: RecordingArea enum
    /// - Throws: ValidationError if invalid or area exceeds screen bounds
    func validateArea(_ area: String, for screenIndex: Int) throws -> RecordingArea {
        return try displayManager.parseAndValidateArea(area, for: screenIndex)
    }
    
    /// Validate screen index
    /// - Parameter screenIndex: Screen index (1-based)
    /// - Throws: ValidationError if invalid
    func validateScreen(_ screenIndex: Int) throws {
        guard screenIndex >= 1 else {
            throw ValidationError.invalidScreen(screenIndex)
        }
        
        // Use DisplayManager to check if screen actually exists
        try displayManager.validateScreen(screenIndex)
    }
    
    /// Validate application name (basic validation - existence check happens at runtime)
    /// - Parameter appName: Application name
    /// - Throws: ValidationError if invalid
    func validateApplication(_ appName: String) throws {
        guard !appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Application name cannot be empty", 
                                suggestion: "Provide a valid application name like 'Safari' or 'Xcode'")
        }
    }
    
    /// Validate and create output URL with intelligent file naming and conflict resolution
    /// - Parameters:
    ///   - path: Output file path (optional)
    ///   - format: Output format for default naming
    ///   - overwrite: Whether to overwrite existing files without prompting
    /// - Returns: URL for output file with conflict resolution
    /// - Throws: ValidationError if invalid
    func validateOutputPath(_ path: String?, format: OutputFormat = .mov, overwrite: Bool = false) throws -> URL {
        let outputManager = OutputManager()
        
        do {
            return try outputManager.generateOutputURL(from: path, format: format, overwrite: overwrite)
        } catch let error as OutputManager.OutputError {
            // Convert OutputManager errors to ValidationError
            switch error {
            case .invalidOutputPath(let path):
                throw ValidationError.invalidOutputPath(path)
            case .directoryCreationFailed(let underlyingError):
                throw ValidationError.invalidOutputDirectory(underlyingError.localizedDescription)
            default:
                throw ValidationError.invalidOutputPath(error.localizedDescription)
            }
        }
    }
    
    /// Validate frame rate
    /// - Parameter fps: Frames per second
    /// - Throws: ValidationError if invalid
    func validateFPS(_ fps: Int) throws {
        let validFPS = [15, 30, 60]
        guard validFPS.contains(fps) else {
            throw ValidationError.invalidFPS(fps)
        }
    }
    
    /// Validate video quality
    /// - Parameter quality: Quality string
    /// - Returns: VideoQuality enum
    /// - Throws: ValidationError if invalid
    func validateQuality(_ quality: String) throws -> VideoQuality {
        guard let videoQuality = VideoQuality(rawValue: quality.lowercased()) else {
            throw ValidationError.invalidQuality(quality)
        }
        return videoQuality
    }
    
    /// Get fixed output format (always MOV)
    /// - Returns: OutputFormat.mov (fixed format)
    func getOutputFormat() -> OutputFormat {
        return .mov // Fixed to MOV format for optimal quality
    }
    
    /// Validate countdown duration
    /// - Parameter countdown: Countdown in seconds
    /// - Throws: ValidationError if invalid
    func validateCountdown(_ countdown: Int) throws {
        guard countdown >= 0 else {
            throw ValidationError.invalidCountdown(countdown)
        }
    }
    
    /// Validate preset name
    /// - Parameter name: Preset name
    /// - Throws: ValidationError if invalid
    func validatePresetName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Preset name cannot be empty",
                                suggestion: "Use a descriptive name like 'meeting-setup' or 'demo-config'")
        }
        
        // Check for valid characters (letters, numbers, hyphens, underscores)
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.rangeOfCharacter(from: validCharacterSet.inverted) == nil else {
            throw ValidationError.invalidPresetName(trimmed)
        }
    }
    
    /// Check available disk space and warn if low
    /// - Parameter outputURL: Output file URL
    /// - Throws: ValidationError if disk space is critically low
    func checkDiskSpace(for outputURL: URL) throws {
        let directory = outputURL.deletingLastPathComponent()
        
        do {
            let resourceValues = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableCapacity = resourceValues.volumeAvailableCapacity {
                let availableGB = Double(availableCapacity) / (1024 * 1024 * 1024)
                
                // Warn if less than 1GB available
                if availableGB < 1.0 {
                    throw ValidationError.diskSpaceWarning(availableGB)
                }
            }
        } catch {
            // If we can't check disk space, just continue
            // This is not a critical error
        }
    }
}