import Foundation

/// Comprehensive error types for screen recording operations
/// Requirements 10.4, 10.5: Clear error messages and suggested solutions
enum ComprehensiveError: LocalizedError {
    
    // MARK: - System and Setup Errors
    case systemRequirementsNotMet(String)
    case permissionsRequired(String)
    case screenCaptureKitUnavailable
    
    // MARK: - Configuration Errors
    case invalidDuration(Int)
    case invalidArea(String)
    case invalidScreen(Int, availableScreens: [String])
    case invalidApplication(String, availableApps: [String])
    case invalidOutputPath(String, reason: String)
    case invalidPresetName(String)
    case presetNotFound(String, availablePresets: [String])
    case presetAlreadyExists(String)
    
    // MARK: - Recording Errors
    case recordingInitializationFailed(Error)
    case captureStartFailed(Error)
    case captureStopFailed(Error)
    case recordingInterrupted(Error, partialFile: String?)
    case audioSetupFailed(Error, fallbackUsed: Bool)
    case videoWriterFailed(Error)
    case diskSpaceInsufficient(availableSpace: Int64, estimatedNeeded: Int64)
    
    // MARK: - Application Recording Errors
    case applicationNotRunning(String)
    case applicationNotRecordable(String, reason: String)
    case noWindowsFound(String)
    case windowAccessDenied(String)
    
    // MARK: - File System Errors
    case outputDirectoryNotWritable(String)
    case fileAlreadyExists(String)
    case fileWritePermissionDenied(String)
    
    // MARK: - Network and External Errors
    case externalToolMissing(String, installCommand: String?)
    
    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        // System and Setup Errors
        case .systemRequirementsNotMet(let details):
            return "System requirements not met: \(details)"
        case .permissionsRequired(let permission):
            return "Permission required: \(permission)"
        case .screenCaptureKitUnavailable:
            return "ScreenCaptureKit is not available on this system"
            
        // Configuration Errors
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration)ms. Duration must be at least 100ms and at most 1 hour"
        case .invalidArea(let area):
            return "Invalid area format: '\(area)'. Expected format: x:y:width:height (e.g., 0:0:1920:1080)"
        case .invalidScreen(let index, let availableScreens):
            return "Screen \(index) not found. Available screens: \(availableScreens.joined(separator: ", "))"
        case .invalidApplication(let name, let availableApps):
            let appList = availableApps.isEmpty ? "none running" : availableApps.prefix(5).joined(separator: ", ")
            return "Application '\(name)' not found. Available applications: \(appList)"
        case .invalidOutputPath(let path, let reason):
            return "Invalid output path '\(path)': \(reason)"
        case .invalidPresetName(let name):
            return "Invalid preset name '\(name)'. Use only letters, numbers, hyphens, and underscores"
        case .presetNotFound(let name, let availablePresets):
            let presetList = availablePresets.isEmpty ? "none saved" : availablePresets.joined(separator: ", ")
            return "Preset '\(name)' not found. Available presets: \(presetList)"
        case .presetAlreadyExists(let name):
            return "Preset '\(name)' already exists"
            
        // Recording Errors
        case .recordingInitializationFailed(let error):
            return "Failed to initialize recording: \(error.localizedDescription)"
        case .captureStartFailed(let error):
            return "Failed to start capture: \(error.localizedDescription)"
        case .captureStopFailed(let error):
            return "Failed to stop capture cleanly: \(error.localizedDescription)"
        case .recordingInterrupted(let error, let partialFile):
            var message = "Recording was interrupted: \(error.localizedDescription)"
            if let file = partialFile {
                message += ". Partial recording saved to: \(file)"
            }
            return message
        case .audioSetupFailed(let error, let fallbackUsed):
            var message = "Audio setup failed: \(error.localizedDescription)"
            if fallbackUsed {
                message += ". Continuing with system audio only"
            }
            return message
        case .videoWriterFailed(let error):
            return "Video writing failed: \(error.localizedDescription)"
        case .diskSpaceInsufficient(let available, let needed):
            let availableMB = available / (1024 * 1024)
            let neededMB = needed / (1024 * 1024)
            return "Insufficient disk space. Available: \(availableMB)MB, Estimated needed: \(neededMB)MB"
            
        // Application Recording Errors
        case .applicationNotRunning(let name):
            return "Application '\(name)' is not currently running"
        case .applicationNotRecordable(let name, let reason):
            return "Application '\(name)' cannot be recorded: \(reason)"
        case .noWindowsFound(let name):
            return "No recordable windows found for application '\(name)'"
        case .windowAccessDenied(let name):
            return "Access denied to windows of application '\(name)'"
            
        // File System Errors
        case .outputDirectoryNotWritable(let path):
            return "Output directory is not writable: \(path)"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"
        case .fileWritePermissionDenied(let path):
            return "Permission denied writing to: \(path)"
            
        // Network and External Errors
        case .externalToolMissing(let tool, _):
            return "Required external tool missing: \(tool)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        // System and Setup Errors
        case .systemRequirementsNotMet:
            return "Upgrade to macOS 12.3 or later to use ScreenCaptureKit features"
        case .permissionsRequired(let permission):
            return "Grant \(permission) permission in System Preferences > Security & Privacy"
        case .screenCaptureKitUnavailable:
            return "Update to macOS 12.3 or later, or use legacy recording mode"
            
        // Configuration Errors
        case .invalidDuration:
            return "Use a duration between 100ms and 3600000ms (1 hour). Example: --duration 10000"
        case .invalidArea:
            return "Use format x:y:width:height. Example: --area 0:0:1920:1080"
        case .invalidScreen(_, let availableScreens):
            if availableScreens.isEmpty {
                return "Use --screen-list to see available screens"
            } else {
                return "Use --screen 1 for primary display or --screen-list to see all options"
            }
        case .invalidApplication(_, let availableApps):
            if availableApps.isEmpty {
                return "Start the application you want to record, then try again"
            } else {
                return "Use --app-list to see all running applications, or start the target application"
            }
        case .invalidOutputPath(_, let reason):
            if reason.contains("permission") {
                return "Choose a different directory or check file permissions"
            } else {
                return "Use an absolute path or ensure the directory exists"
            }
        case .invalidPresetName:
            return "Use only letters, numbers, hyphens, and underscores. Example: 'meeting-setup'"
        case .presetNotFound(_, let availablePresets):
            if availablePresets.isEmpty {
                return "Create a preset first with --save-preset <name>"
            } else {
                return "Use --list-presets to see all saved presets"
            }
        case .presetAlreadyExists(let name):
            return "Use --delete-preset '\(name)' first, or choose a different name"
            
        // Recording Errors
        case .recordingInitializationFailed:
            return "Check system permissions and try restarting the application"
        case .captureStartFailed:
            return "Ensure no other screen recording software is running and check permissions"
        case .captureStopFailed:
            return "The recording may have been saved despite this error. Check the output file"
        case .recordingInterrupted(_, let partialFile):
            if partialFile != nil {
                return "Check the partial recording file - it may still be usable"
            } else {
                return "Try recording again with shorter duration or lower quality settings"
            }
        case .audioSetupFailed(_, let fallbackUsed):
            if fallbackUsed {
                return "Check microphone permissions in System Preferences > Security & Privacy"
            } else {
                return "Try recording without microphone using system audio only"
            }
        case .videoWriterFailed:
            return "Check available disk space and file permissions"
        case .diskSpaceInsufficient:
            return "Free up disk space or use lower quality settings (--quality low --fps 15)"
            
        // Application Recording Errors
        case .applicationNotRunning:
            return "Start the application first, then try recording again"
        case .applicationNotRecordable(_, let reason):
            if reason.contains("system") {
                return "System applications cannot be recorded. Try recording the screen instead"
            } else {
                return "Try using screen recording mode instead: remove --app option"
            }
        case .noWindowsFound:
            return "Ensure the application has visible windows, or try screen recording mode"
        case .windowAccessDenied:
            return "Grant screen recording permission in System Preferences > Security & Privacy"
            
        // File System Errors
        case .outputDirectoryNotWritable:
            return "Choose a different output directory or check folder permissions"
        case .fileAlreadyExists:
            return "Use a different filename, or delete the existing file first"
        case .fileWritePermissionDenied:
            return "Check file and directory permissions, or choose a different location"
            
        // Network and External Errors
        case .externalToolMissing(_, let installCommand):
            if let command = installCommand {
                return "Install using: \(command)"
            } else {
                return "Install the required tool and try again"
            }
        }
    }
    
    var failureReason: String? {
        switch self {
        case .systemRequirementsNotMet:
            return "ScreenCaptureKit requires macOS 12.3 or later"
        case .permissionsRequired:
            return "Screen recording permission is required"
        case .diskSpaceInsufficient:
            return "Not enough free disk space for the recording"
        case .applicationNotRecordable(_, let reason):
            return reason
        default:
            return nil
        }
    }
    
    /// Get the appropriate exit code for this error
    var exitCode: Int32 {
        switch self {
        case .systemRequirementsNotMet, .screenCaptureKitUnavailable:
            return 2 // System incompatibility
        case .permissionsRequired, .windowAccessDenied, .fileWritePermissionDenied:
            return 3 // Permission denied
        case .invalidDuration, .invalidArea, .invalidScreen, .invalidApplication, .invalidOutputPath, .invalidPresetName:
            return 4 // Invalid arguments
        case .diskSpaceInsufficient, .outputDirectoryNotWritable:
            return 5 // Storage issues
        case .externalToolMissing:
            return 6 // Missing dependencies
        default:
            return 1 // General error
        }
    }
}

// MARK: - Error Formatting and Display

extension ComprehensiveError {
    /// Format the error for display with emoji and colors
    func formattedDescription() -> String {
        var output = "❌ \(errorDescription ?? "Unknown error")"
        
        if let reason = failureReason {
            output += "\n📋 Reason: \(reason)"
        }
        
        if let suggestion = recoverySuggestion {
            output += "\n💡 Solution: \(suggestion)"
        }
        
        return output
    }
    
    /// Display the error to the user with proper formatting
    func display() {
        print(formattedDescription())
        print("")
        print("Use --help for detailed usage information.")
    }
}