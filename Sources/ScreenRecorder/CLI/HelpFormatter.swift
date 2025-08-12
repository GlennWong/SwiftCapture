import Foundation
import ArgumentParser

/// Provides simplified help formatting for the CLI
struct HelpFormatter {
    
    /// Generates basic usage information
    static let usageExamples = """
    
    EXAMPLES:
      screenrecorder --duration 30000 --fps 60                    # 30 second recording at 60fps
      screenrecorder --output video.mov --force                   # Force overwrite existing file
      screenrecorder -f -o video.mov --duration 5000              # Short form: force overwrite
      screenrecorder --area 0:0:1920:1080 --screen 2             # Record specific area on second screen
      screenrecorder --app Safari --duration 15000                # Record Safari for 15 seconds
    
    QUICK REFERENCE:
      • Use --screen-list to identify available displays
      • Use --app-list to see recordable applications  
      • Use --list-presets to see saved configurations
      • Use --force (-f) to skip file conflict prompts
      • Check system permissions in System Preferences > Security & Privacy
    """
    
    /// Generates basic help information
    static let detailedHelp = ""
    
    /// Generates basic troubleshooting information
    static let troubleshooting = ""
}

/// Extension to provide custom help text
extension ScreenRecorderCommand {
    static var helpText: String {
        return """
        \(configuration.abstract)
        
        \(HelpFormatter.usageExamples)
        \(HelpFormatter.detailedHelp)
        \(HelpFormatter.troubleshooting)
        """
    }
}