import Foundation
import ArgumentParser

/// Provides enhanced help formatting and examples for the CLI
struct HelpFormatter {
    
    /// Generates comprehensive usage examples
    static let usageExamples = """
    
    EXAMPLES:
    
    🎬 Quick Start:
      screenrecorder                                    # Record for 10 seconds to timestamped file
      screenrecorder --duration 5000                   # Record for 5 seconds
      screenrecorder --output ~/Desktop/demo.mov        # Save to specific location
      screenrecorder --help                             # Show this help message
    
    📺 Screen and Area Selection:
      screenrecorder --screen-list                      # List available screens
      screenrecorder --screen 2                         # Record from secondary display
      screenrecorder --area 0:0:1920:1080              # Record specific area (full HD)
      screenrecorder --area 100:100:800:600            # Record 800x600 area at position 100,100
      screenrecorder --screen 1 --area 0:0:1280:720    # Record 720p area on primary screen
    
    📱 Application Recording:
      screenrecorder --app-list                         # List running applications
      screenrecorder --app Safari                       # Record Safari windows only
      screenrecorder --app "Final Cut Pro"             # Record app with spaces in name
      screenrecorder --app Terminal --duration 15000   # Record Terminal for 15 seconds
    
    🎵 Audio and Quality Options:
      screenrecorder --enable-microphone                # Include microphone audio
      screenrecorder --fps 60 --quality high           # High quality 60fps recording
      screenrecorder --format mp4                       # Output as MP4 instead of MOV
      screenrecorder --fps 15 --quality low            # Low quality for longer recordings
      screenrecorder --enable-microphone --quality high --fps 30  # High quality with audio
    
    ⚡ Advanced Features:
      screenrecorder --countdown 3 --show-cursor        # 3-second countdown with cursor visible
      screenrecorder --countdown 5 --duration 30000    # 5-second countdown, 30-second recording
      screenrecorder --show-cursor --fps 60            # Smooth cursor recording
    
    💾 Preset Management:
      screenrecorder --save-preset "meeting"           # Save current settings as preset
      screenrecorder --preset "meeting"                # Use saved preset
      screenrecorder --list-presets                     # Show all saved presets
      screenrecorder --delete-preset "old-config"      # Delete unused preset
    
    🔧 Complex Recording Scenarios:
      # High-quality presentation recording with countdown
      screenrecorder --screen 2 --area 0:0:1920:1080 --enable-microphone --fps 30 --quality high --countdown 5 --show-cursor
      
      # Application demo with custom output
      screenrecorder --app Safari --duration 30000 --output ~/Desktop/safari-demo.mp4 --show-cursor --fps 60
      
      # Quick screen capture with preset
      screenrecorder --preset "demo-setup" --duration 10000 --output ~/Desktop/quick-demo.mov
      
      # Multi-screen setup recording
      screenrecorder --screen 1 --area 0:0:2560:1440 --quality high --format mp4 --countdown 3
    
    📋 Information Commands:
      screenrecorder --screen-list                      # Show available displays
      screenrecorder --app-list                         # Show running applications  
      screenrecorder --list-presets                     # Show saved configurations
      screenrecorder --version                          # Show version information
    """
    
    /// Generates detailed option descriptions
    static let detailedHelp = """
    
    📖 DETAILED OPTIONS:
    
    ⏱️  Duration Control:
      --duration, -d <ms>        Recording duration in milliseconds
                                 • Minimum: 100ms (0.1 seconds)
                                 • Default: 10000ms (10 seconds)  
                                 • Maximum: No limit (limited by disk space)
                                 • Examples: 1000 (1s), 5000 (5s), 30000 (30s), 120000 (2min)
                                 • Tip: Use shorter durations for testing, longer for presentations
    
    📁 Output Options:
      --output, -o <path>        Output file path and name
                                 • Default: Current directory with timestamp (YYYY-MM-DD_HH-MM-SS.mov)
                                 • Supports absolute paths: /Users/username/Desktop/video.mov
                                 • Supports relative paths: ./recordings/demo.mp4
                                 • Supports home directory: ~/Desktop/recording.mov
                                 • Auto-creates directories if they don't exist
                                 • File extension should match --format option
    
    🖥️  Screen Selection:
      --screen-list, -l          List all available screens with detailed information
                                 • Shows index, resolution, name, and primary status
                                 • Use this first to identify available displays
      --screen, -s <index>       Screen to record from (1-based indexing)
                                 • 1 = Primary display (default)
                                 • 2+ = Secondary displays
                                 • Cannot be used with --app option
    
    📐 Area Selection:
      --area, -a <x:y:w:h>       Record specific rectangular area
                                 • Format: x:y:width:height (all values in pixels)
                                 • x,y = top-left corner coordinates (0,0 = screen top-left)
                                 • width,height = dimensions of recording area
                                 • Examples: 0:0:1920:1080 (full HD), 100:100:800:600 (centered area)
                                 • Coordinates must be within screen bounds
                                 • Cannot be used with --app option
    
    📱 Application Recording:
      --app-list, -L             List all running applications
                                 • Shows application names exactly as they should be typed
                                 • Only shows applications with visible windows
      --app, -A <name>           Record specific application windows
                                 • Use exact name from --app-list (case-sensitive)
                                 • Quote names with spaces: "Final Cut Pro", "System Preferences"
                                 • Records all windows of the specified application
                                 • Cannot be used with --screen or --area options
                                 • Application must be running and visible
    
    🎵 Audio Options:
      --enable-microphone, -m    Include microphone audio in recording
                                 • System audio is always included by default
                                 • Requires microphone permission in System Preferences
                                 • Uses default microphone input device
                                 • Audio quality matches video quality setting
                                 • Gracefully continues without microphone if unavailable
    
    ⚙️  Quality Settings:
      --fps <rate>               Frame rate (frames per second)
                                 • Options: 15, 30, 60 (default: 30)
                                 • 15fps: Good for static content, smaller files
                                 • 30fps: Standard for most recordings
                                 • 60fps: Smooth motion, larger files
      --quality <preset>         Video quality preset
                                 • low: Smaller files, lower bitrate (~2Mbps)
                                 • medium: Balanced quality/size (~5Mbps) [default]
                                 • high: Best quality, larger files (~10Mbps)
      --format <type>            Output file format
                                 • mov: QuickTime format, best macOS compatibility [default]
                                 • mp4: MP4 format, broader platform compatibility
                                 • File extension in --output should match format
    
    👁️  Visual Options:
      --show-cursor              Include mouse cursor in recording
                                 • Default: cursor is hidden for cleaner recordings
                                 • Useful for tutorials and demonstrations
                                 • Cursor appearance depends on system settings
      --countdown <seconds>      Countdown timer before recording starts
                                 • Default: 0 (no countdown)
                                 • Range: 0-60 seconds
                                 • Displays visual countdown in terminal
                                 • Can be cancelled with Ctrl+C during countdown
    
    💾 Preset Management:
      --save-preset <name>       Save current CLI options as named preset
                                 • Stores all current settings for reuse
                                 • Name can contain letters, numbers, hyphens, underscores
                                 • Overwrites existing preset with same name
      --preset <name>            Load and use saved preset
                                 • Applies all saved settings from preset
                                 • Individual CLI options override preset values
                                 • Preset must exist (use --list-presets to check)
      --list-presets             Display all saved presets with their settings
                                 • Shows preset name, creation date, and key settings
                                 • Helps identify which preset to use
      --delete-preset <name>     Remove a saved preset permanently
                                 • Cannot be undone
                                 • Must be used alone (no other options)
    
    📝 USAGE NOTES:
    • Options can be combined in any order
    • Short flags can be combined: -msc (same as --enable-microphone --show-cursor)
    • Presets override individual options when loaded, but CLI options override presets
    • Use Ctrl+C to stop recording early (saves partial recording)
    • Recording requires Screen Recording permission in System Preferences
    • Microphone recording requires Microphone permission in System Preferences
    • Large recordings may take time to finalize after stopping
    
    🔧 SYSTEM REQUIREMENTS:
    • macOS 12.3 or later (for ScreenCaptureKit support)
    • Screen Recording permission in System Preferences > Security & Privacy
    • Microphone permission (only if using --enable-microphone)
    • Sufficient disk space for recording (varies by duration and quality)
    """
    
    /// Generates troubleshooting information
    static let troubleshooting = """
    
    🔧 TROUBLESHOOTING:
    
    ❌ Common Issues and Solutions:
    
    Permission Errors:
      • "Screen Recording permission denied"
        → Go to System Preferences > Security & Privacy > Privacy > Screen Recording
        → Add Terminal (or your terminal app) and enable it
        → Restart your terminal application
      
      • "Microphone permission denied" (when using --enable-microphone)
        → Go to System Preferences > Security & Privacy > Privacy > Microphone
        → Add Terminal (or your terminal app) and enable it
        → Restart your terminal application
    
    Screen/Display Issues:
      • "Screen X not found" or "Invalid screen index"
        → Use --screen-list to see all available screens
        → Screen indices start at 1 (not 0)
        → External displays may change indices when disconnected/reconnected
      
      • "Invalid area coordinates" or "Area exceeds screen bounds"
        → Check screen resolution with --screen-list
        → Ensure x:y coordinates are within screen bounds
        → Ensure width and height don't exceed screen dimensions
        → Example: For 1920x1080 screen, max area is 0:0:1920:1080
    
    Application Recording Issues:
      • "Application 'X' not found"
        → Use --app-list to see exact application names (case-sensitive)
        → Application must be running and have visible windows
        → Use quotes for names with spaces: "Final Cut Pro"
      
      • "No windows found for application"
        → Ensure application has visible, non-minimized windows
        → Some system applications may not be recordable
        → Try bringing the application to the foreground
    
    Audio Issues:
      • "Audio setup failed" or "Microphone unavailable"
        → Check microphone permissions (see above)
        → Ensure microphone is connected and working
        → Try without --enable-microphone flag (system audio only)
        → Check Audio MIDI Setup for device conflicts
    
    File Output Issues:
      • "Permission denied" when saving file
        → Check write permissions for output directory
        → Ensure output directory exists or can be created
        → Try saving to ~/Desktop or ~/Documents
      
      • "Invalid output path" or "File extension mismatch"
        → Ensure file extension matches --format option (.mov or .mp4)
        → Use absolute paths or ~/path for home directory
        → Avoid special characters in filenames
    
    Performance Issues:
      • Recording is choppy or drops frames
        → Lower --fps setting (try 15 or 30 instead of 60)
        → Use --quality low for better performance
        → Close unnecessary applications
        → Ensure sufficient disk space
      
      • Large file sizes
        → Use --quality low or medium instead of high
        → Lower --fps setting
        → Record smaller --area instead of full screen
        → Use --format mp4 for better compression
    
    System Requirements Issues:
      • "System requirements not met" or "macOS version too old"
        → Requires macOS 12.3 or later
        → Update macOS through System Preferences > Software Update
        → Older macOS versions are not supported due to ScreenCaptureKit requirements
    
    💡 Performance Tips:
    • Use --quality low for longer recordings to save disk space
    • Use --fps 15 for screen recordings with minimal motion (presentations, code)
    • Use --fps 30 for standard recordings (most use cases)
    • Use --fps 60 only for smooth motion capture (games, animations)
    • Specify smaller --area to reduce file size and improve performance
    • Close unnecessary applications before recording
    • Ensure sufficient free disk space (at least 1GB for short recordings)
    
    🆘 Getting Help:
    • Use --help for this comprehensive help information
    • Use --screen-list to identify available displays
    • Use --app-list to see recordable applications
    • Use --list-presets to see saved configurations
    • Check system permissions in System Preferences > Security & Privacy
    """
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