import Foundation
import ArgumentParser

/// Provides simplified help formatting for the CLI
struct HelpFormatter {
    
    /// Generates basic usage information
    static let usageExamples = """
    
    EXAMPLES:
      scap                                                # Continuous recording (press Ctrl+C to stop)
      scap --output video.mov                             # Continuous recording with custom output
      scap --duration 30000 --fps 60                      # 30 second recording at 60fps
      scap --duration 5000 -f -o video.mov                # 5 second recording, force overwrite
      scap --area 0:0:1920:1080 --screen 2                # Record specific area on second screen
      scap --app Safari --duration 15000                  # Record Safari for 15 seconds
      scap --screen-list --json                           # List screens in JSON format
      scap --app-list --json                              # List applications in JSON format
      scap --duration 30000 --verbose                     # Show detailed configuration and debug info
    
    RECORDING MODES:
      • Default: Continuous recording until Ctrl+C is pressed
      • Timed: Specify --duration in milliseconds for fixed-length recordings
      • Early termination: Ctrl+C stops recording (requires confirmation for timed recordings)
    
    OUTPUT FORMAT:
      • Always outputs high-quality MOV format (macOS native)
      • Use .mov extension or omit for automatic naming
      • Optimized encoding with H.264/HEVC codecs
    
    QUICK REFERENCE:
      • Use --screen-list to identify available displays
      • Use --app-list to see recordable applications  
      • Use --list-presets to see saved configurations
      • Add --json to list commands for programmatic output
      • Use --force (-f) to skip file conflict prompts
      • Check system permissions in System Preferences > Security & Privacy
    """
    
    /// Generates basic help information
    static let detailedHelp = ""
    
    /// Generates basic troubleshooting information
    static let troubleshooting = ""
}

/// Extension to provide custom help text
extension SwiftCaptureCommand {
    static var helpText: String {
        return """
        \(configuration.abstract)
        
        \(HelpFormatter.usageExamples)
        \(HelpFormatter.detailedHelp)
        \(HelpFormatter.troubleshooting)
        """
    }
}