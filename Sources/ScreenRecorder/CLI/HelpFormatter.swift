import Foundation
import ArgumentParser

/// Provides simplified help formatting for the CLI
struct HelpFormatter {
    
    /// Generates basic usage information
    static let usageExamples = """
    
    • Use --help for this comprehensive help information
    • Use --screen-list to identify available displays
    • Use --app-list to see recordable applications
    • Use --list-presets to see saved configurations
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