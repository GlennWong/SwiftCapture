import Foundation
import ArgumentParser
import Dispatch

/// Error thrown when countdown is cancelled
struct CancellationError: Error {}

@main
struct SwiftCaptureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scap",
        abstract: "Professional screen recording tool for macOS using ScreenCaptureKit",
        discussion: HelpFormatter.usageExamples,
        version: "2.1.11",
        helpNames: [.short, .long, .customLong("help")]
    )
    
    // MARK: - Duration Control
    @Option(name: [.short, .long], help: "Recording duration in milliseconds (default: 10000)")
    var duration: Int = 10000
    
    // MARK: - Output Options
    @Option(name: [.short, .long], help: ArgumentHelp(
        "Output file path with .mov extension. Always outputs high-quality MOV format.",
        discussion: """
        Examples:
          --output recording.mov     # High-quality MOV format
          --output /path/to/file.mov # Full path with MOV format
        
        If no extension is provided, defaults to .mov format.
        If no output is specified, creates timestamped file in current directory.
        """,
        valueName: "path"
    ))
    var output: String?
    
    @Flag(name: [.customShort("f"), .customLong("force")], help: "Force overwrite existing output file without prompting")
    var force: Bool = false
    
    // MARK: - Screen/Area Selection
    @Option(name: [.short, .long], help: "Recording area in format x:y:width:height (default: full screen)")
    var area: String?
    
    @Flag(name: [.customShort("l"), .customLong("screen-list")], help: "List all available screens with their indices")
    var screenList: Bool = false
    
    @Option(name: [.short, .long], help: "Screen index to record from (1=primary, 2+=secondary)")
    var screen: Int = 1
    
    // MARK: - Application Recording
    @Flag(name: [.customShort("L"), .customLong("app-list")], help: "List all running applications")
    var appList: Bool = false
    
    @Option(name: [.customShort("A"), .long], help: "Application name to record (instead of screen)")
    var app: String?
    
    // MARK: - Audio Options
    @Flag(name: [.short, .long], help: "Enable microphone recording")
    var enableMicrophone: Bool = false
    
    @Option(help: "Audio quality: low, medium, or high (default: medium)")
    var audioQuality: String = "medium"
    
    @Flag(name: [.customLong("system-audio-only")], help: "Force system-wide audio recording (ignores app-specific audio when recording apps)")
    var systemAudioOnly: Bool = false
    
    // MARK: - Advanced Recording Options
    @Option(help: "Frame rate: 15, 30, or 60 fps (default: 30)")
    var fps: Int = 30
    
    @Option(help: "Quality preset: low, medium, or high (default: medium)")
    var quality: String = "medium"
    

    
    @Flag(help: "Show cursor in recording")
    var showCursor: Bool = false
    
    @Option(help: "Countdown seconds before recording starts (default: 0)")
    var countdown: Int = 0
    
    // MARK: - Preset Management
    @Option(help: "Save current settings as a named preset")
    var savePreset: String?
    
    @Option(help: "Load settings from a saved preset")
    var preset: String?
    
    @Flag(help: "List all saved presets")
    var listPresets: Bool = false
    
    @Option(help: "Delete a saved preset")
    var deletePreset: String?
    
    // MARK: - Output Format Options
    @Flag(help: "Output list results in JSON format for programmatic use")
    var json: Bool = false
    
    // MARK: - Validation
    func validate() throws {
        // Check system requirements first
        guard #available(macOS 12.3, *) else {
            throw ValidationError.systemRequirementsNotMet()
        }
        
        // Validate individual parameters
        try validateDuration()
        try validateFPS()
        try validateQuality()
        try validateAudioQuality()
        try validateScreen()
        try validateCountdown()
        try validateArea()
        
        // Validate argument combinations and conflicts
        try validateArgumentCombinations()
    }
    
    private func validateDuration() throws {
        if duration < 100 {
            throw ValidationError.invalidDuration(duration)
        }
    }
    
    private func validateFPS() throws {
        if ![15, 30, 60].contains(fps) {
            throw ValidationError.invalidFPS(fps)
        }
    }
    
    private func validateQuality() throws {
        if !["low", "medium", "high"].contains(quality.lowercased()) {
            throw ValidationError.invalidQuality(quality)
        }
    }
    

    
    private func validateAudioQuality() throws {
        if !["low", "medium", "high"].contains(audioQuality.lowercased()) {
            throw ValidationError.invalidQuality(audioQuality)
        }
    }
    
    private func validateScreen() throws {
        if screen < 1 {
            throw ValidationError.invalidScreen(screen)
        }
    }
    
    private func validateCountdown() throws {
        if countdown < 0 {
            throw ValidationError.invalidCountdown(countdown)
        }
    }
    
    /// Get output format - always MOV for optimal quality
    /// - Returns: OutputFormat.mov (fixed format)
    func detectOutputFormat() -> OutputFormat {
        return .mov // Fixed to MOV format for optimal quality and compatibility
    }
    
    private func validateArea() throws {
        guard let areaString = area else { return }
        
        // Parse the area string first
        let components = areaString.split(separator: ":")
        
        // Handle centered area format: center:width:height
        if components.count == 3 && components[0].lowercased() == "center" {
            guard let width = Int(components[1]),
                  let height = Int(components[2]),
                  width > 0, height > 0 else {
                throw ValidationError.invalidArea("Invalid centered area format. Expected: center:width:height")
            }
            return
        }
        
        // Handle standard area format: x:y:width:height
        guard components.count == 4 else {
            throw ValidationError.invalidAreaFormat(areaString)
        }
        
        for component in components {
            guard let value = Int(component), value >= 0 else {
                throw ValidationError.invalidAreaCoordinates(areaString)
            }
        }
        
        // Additional validation: ensure width and height are positive
        let values = components.compactMap { Int($0) }
        if values.count == 4 && (values[2] <= 0 || values[3] <= 0) {
            throw ValidationError(
                "Invalid area dimensions: width and height must be greater than 0.",
                suggestion: "Ensure width (3rd value) and height (4th value) are positive, like --area 0:0:1920:1080"
            )
        }
        
        // Validate area against the specified screen (or default screen 1)
        // This ensures the area fits within the target screen bounds
        if #available(macOS 12.3, *) {
            do {
                let displayManager = DisplayManager()
                let recordingArea = try RecordingArea.parse(from: areaString)
                try displayManager.validateArea(recordingArea, for: screen)
            } catch let error as SwiftCaptureError {
                // Convert SwiftCaptureError to ValidationError for consistent CLI output
                throw ValidationError(error.localizedDescription)
            } catch let error as ValidationError {
                // Re-throw ValidationError as-is
                throw error
            } catch {
                // Handle any other errors
                throw ValidationError("Area validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func validateArgumentCombinations() throws {
        // Check for conflicting screen/app options
        if app != nil && (screen != 1 || area != nil) && !systemAudioOnly {
            throw ValidationError(
                "Application recording conflicts with screen/area selection.",
                suggestion: "Use either --app for application recording OR --screen/--area for screen recording, but not both. Use --system-audio-only with --app to record system-wide audio."
            )
        }
        
        // Check for conflicting list operations
        let listOperations = [screenList, appList, listPresets].filter { $0 }
        if listOperations.count > 1 {
            throw ValidationError(
                "Multiple list operations specified. Only one list operation allowed at a time.",
                suggestion: "Use only one of: --screen-list, --app-list, or --list-presets"
            )
        }
        
        // Check for conflicting preset operations
        let presetOperations = [savePreset != nil, preset != nil, deletePreset != nil].filter { $0 }
        if presetOperations.count > 1 {
            throw ValidationError(
                "Multiple preset operations specified. Only one preset operation allowed at a time.",
                suggestion: "Use only one of: --save-preset, --preset, or --delete-preset"
            )
        }
        
        // Check if recording options are used with list operations
        if screenList || appList || listPresets {
            let hasRecordingOptions = duration != 10000 || output != nil || area != nil || 
                                    screen != 1 || app != nil || enableMicrophone || 
                                    fps != 30 || quality != "medium" || 
                                    audioQuality != "medium" || showCursor || countdown != 0 || force
            
            if hasRecordingOptions {
                throw ValidationError(
                    "Recording options cannot be used with list operations.",
                    suggestion: "Use list operations alone to view available options, then run recording command separately"
                )
            }
        }
        
        // Check if --json is used without list operations
        if json && !screenList && !appList && !listPresets {
            throw ValidationError(
                "The --json flag can only be used with list operations.",
                suggestion: "Use --json with --screen-list, --app-list, or --list-presets"
            )
        }
        
        // Check if preset deletion is used with other options
        if deletePreset != nil {
            let hasOtherOptions = duration != 10000 || output != nil || area != nil || 
                                screen != 1 || app != nil || enableMicrophone || 
                                fps != 30 || quality != "medium" || 
                                audioQuality != "medium" || showCursor || countdown != 0 || force || savePreset != nil || preset != nil
            
            if hasOtherOptions {
                throw ValidationError(
                    "Preset deletion cannot be combined with other options.",
                    suggestion: "Use --delete-preset alone to remove a preset"
                )
            }
        }
        
        // Validate output file extension is supported
        if let outputPath = output {
            let pathExtension = (outputPath as NSString).pathExtension.lowercased()
            if !pathExtension.isEmpty && pathExtension != "mov" {
                throw ValidationError(
                    "Unsupported output file extension '\(pathExtension)'. SwiftCapture only outputs MOV format.",
                    suggestion: "Use .mov extension, like 'recording.mov' or omit extension for automatic naming"
                )
            }
        }
        
        // Validate preset names contain only allowed characters
        if let presetName = savePreset {
            try validatePresetName(presetName)
        }
        if let presetName = preset {
            try validatePresetName(presetName)
        }
        if let presetName = deletePreset {
            try validatePresetName(presetName)
        }
        
        // Validate countdown range
        if countdown > 60 {
            throw ValidationError(
                "Countdown too long: \(countdown) seconds. Maximum is 60 seconds.",
                suggestion: "Use a shorter countdown like --countdown 5 or --countdown 10"
            )
        }
        
        // Validate reasonable duration limits (warn for very long recordings)
        if duration > 3600000 { // 1 hour
            throw ValidationError(
                "Duration very long: \(duration)ms (\(duration/60000) minutes). This may create very large files.",
                suggestion: "Consider shorter recordings or use --quality low to reduce file size"
            )
        }
        
        // Check for potentially problematic area dimensions
        if let areaString = area {
            let components = areaString.split(separator: ":").compactMap { Int($0) }
            if components.count == 4 {
                let width = components[2]
                let height = components[3]
                
                // Warn about very large recording areas
                if width * height > 4096 * 2160 { // Larger than 4K
                    throw ValidationError(
                        "Recording area very large: \(width)×\(height). This may impact performance.",
                        suggestion: "Consider a smaller area or use --quality low and --fps 15 for better performance"
                    )
                }
                
                // Warn about very small recording areas
                if width < 100 || height < 100 {
                    throw ValidationError(
                        "Recording area very small: \(width)×\(height). Minimum recommended size is 100×100.",
                        suggestion: "Use a larger area like --area 0:0:800:600 for better visibility"
                    )
                }
            }
        }
    }
    
    private func validatePresetName(_ name: String) throws {
        // Check for empty name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalidPresetName(name)
        }
        
        // Check for valid characters (letters, numbers, hyphens, underscores)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if name.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            throw ValidationError.invalidPresetName(name)
        }
        
        // Check length
        if name.count > 50 {
            throw ValidationError(
                "Preset name too long: '\(name)'. Maximum length is 50 characters.",
                suggestion: "Use a shorter name like 'meeting' or 'demo-setup'"
            )
        }
    }
    
    // MARK: - Main Execution
    func run() async throws {
        do {
            // System requirements are checked in validate() method
            // For now, delegate to the existing ScreenRecorder implementation
            // This will be refactored in later tasks
            
            // Handle list operations first
            if screenList {
                try await handleScreenList()
                return
            }
            
            if appList {
                try await handleAppList()
                return
            }
            
            if listPresets {
                try await handleListPresets()
                return
            }
            
            // Handle preset deletion
            if let presetName = deletePreset {
                try await handleDeletePreset(presetName)
                return
            }
            
            // Handle preset saving (save current settings and exit)
            if let presetName = savePreset {
                try await handleSavePreset(presetName)
                return
            }
            
            // Show countdown if specified
            if countdown > 0 {
                try await showCountdown()
            }
            
            // Execute recording with the new modular architecture
            if #available(macOS 12.3, *) {
                try await executeRecording()
            }
            
        } catch let error as ComprehensiveError {
            // Handle comprehensive screen recorder errors
            error.display()
            throw ExitCode(error.exitCode)
            
        } catch let error as ValidationError {
            // Handle validation errors with formatted output
            print("❌ \(error.message)")
            if let suggestion = error.suggestion {
                print("💡 \(suggestion)")
            }
            print("")
            print("Use --help for detailed usage information.")
            throw ExitCode.validationFailure
            
        } catch {
            // Handle other unexpected errors
            let comprehensiveError = ComprehensiveError.recordingInitializationFailed(error)
            comprehensiveError.display()
            throw ExitCode.failure
        }
    }
    
    // MARK: - Subcommand Help Methods
    private func showScreenListHelp() {
        print("USAGE: scap --screen-list")
        print("")
        print("List all available screens with their indices and resolutions.")
        print("Use the screen index with --screen option to record from specific display.")
        print("")
        print("EXAMPLES:")
        print("  scap --screen-list                       # Show available screens")
        print("  scap --screen 1                          # Record primary display")
        print("  scap --screen 2                          # Record secondary display")
    }
    
    private func showAppListHelp() {
        print("USAGE: scap --app-list")
        print("")
        print("List all running applications that can be recorded.")
        print("Use the exact application name with --app option.")
        print("")
        print("EXAMPLES:")
        print("  scap --app-list                          # Show running applications")
        print("  scap --app Safari                        # Record Safari windows")
        print("  scap --app \"Final Cut Pro\"             # Record app with spaces")
    }
    
    private func showListPresetsHelp() {
        print("USAGE: scap --list-presets")
        print("")
        print("Show all saved configuration presets.")
        print("Use preset name with --preset option to load saved settings.")
        print("")
        print("EXAMPLES:")
        print("  scap --list-presets                      # Show saved presets")
        print("  scap --preset \"meeting\"                # Use saved preset")
        print("  scap --save-preset \"demo\"              # Save current settings")
    }
    
    // MARK: - Handler Methods (Placeholder implementations)
    private func handleScreenList() async throws {
        if #available(macOS 12.3, *) {
            let recorder = ScreenRecorder()
            try recorder.listScreens(jsonOutput: json)
        } else {
            throw ValidationError.systemRequirementsNotMet()
        }
        
        // Show usage examples after listing screens (only for non-JSON output)
        if !json {
            print("")
            print("USAGE:")
            print("  scap --screen 1                          # Record primary display")
            print("  scap --screen 2                          # Record secondary display")
            print("  scap --screen 1 --area 0:0:1920:1080     # Record specific area")
        }
    }
    
    private func handleAppList() async throws {
        if #available(macOS 12.3, *) {
            let recorder = ScreenRecorder()
            try recorder.listApplications(jsonOutput: json)
        } else {
            throw ValidationError.systemRequirementsNotMet()
        }
        
        // Show usage examples after listing applications (only for non-JSON output)
        if !json {
            print("")
            print("USAGE:")
            print("  scap --app Safari                        # Record Safari windows")
            print("  scap --app \"Final Cut Pro\"             # Record app with spaces")
            print("  scap --app Terminal --duration 15000     # Record for 15 seconds")
        }
    }
    
    private func handleListPresets() async throws {
        do {
            let configManager = try ConfigurationManager()
            try configManager.listPresets(jsonOutput: json)
        } catch {
            if json {
                // For JSON output, print error as JSON
                let errorOutput = ["error": error.localizedDescription]
                if let jsonData = try? JSONSerialization.data(withJSONObject: errorOutput, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } else {
                print("❌ Error listing presets: \(error.localizedDescription)")
            }
        }
        
        // Show usage examples after listing presets (only for non-JSON output)
        if !json {
            print("")
            print("USAGE:")
            print("  scap --save-preset \"meeting\"           # Save current settings")
            print("  scap --preset \"meeting\"               # Use saved preset")
            print("  scap --delete-preset \"old-config\"     # Delete preset")
        }
    }
    
    private func handleDeletePreset(_ name: String) async throws {
        print("🗑️  Deleting preset '\(name)'...")
        print("════════════════════════════════════════════════════════════════")
        
        do {
            let configManager = try ConfigurationManager()
            try configManager.deletePreset(named: name)
        } catch {
            print("❌ Error deleting preset: \(error.localizedDescription)")
            if error.localizedDescription.contains("not found") {
                print("")
                print("💡 Use --list-presets to see available presets")
            }
        }
    }
    
    private func handleSavePreset(_ name: String) async throws {
        print("💾 Saving preset '\(name)'...")
        print("════════════════════════════════════════════════════════════════")
        
        do {
            let configManager = try ConfigurationManager()
            let configuration = try configManager.createConfiguration(from: self)
            try configManager.savePreset(named: name, configuration: configuration)
            
            print("")
            print("📋 Preset '\(name)' saved with the following settings:")
            print("   Duration: \(duration)ms")
            print("   Screen: \(screen)")
            if let area = area {
                print("   Area: \(area)")
            } else {
                print("   Area: Full Screen")
            }
            if let app = app {
                print("   Application: \(app)")
            }
            let detectedFormat = detectOutputFormat()
            print("   Video: \(fps)fps, \(quality) quality, \(detectedFormat.rawValue.uppercased())")
            print("   Audio: \(enableMicrophone ? "microphone + system" : "system only"), \(audioQuality) quality")
            if showCursor {
                print("   Cursor: visible")
            }
            if countdown > 0 {
                print("   Countdown: \(countdown)s")
            }
            print("")
            print("💡 Use --preset '\(name)' to load these settings in future recordings")
            
        } catch {
            print("❌ Error saving preset: \(error.localizedDescription)")
        }
    }
    
    private func showCountdown() async throws {
        print("🎬 Recording will start in:")
        print("   (Press Ctrl+C to cancel)")
        
        // Set up signal handling for countdown cancellation
        var cancelled = false
        SignalHandler.shared.setupForCountdown {
            cancelled = true
        }
        
        // Perform countdown with cancellation support
        for i in (1...countdown).reversed() {
            if cancelled {
                throw CancellationError()
            }
            
            print("   \(i)...")
            
            // Sleep in smaller intervals to check for cancellation more frequently
            for _ in 0..<10 {
                if cancelled {
                    throw CancellationError()
                }
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
        
        // Clean up signal handler after countdown
        SignalHandler.shared.cleanup()
        
        if !cancelled {
            print("🔴 Recording started!")
        }
    }
    
    @available(macOS 12.3, *)
    private func executeRecording() async throws {
        do {
            // Create configuration using ConfigurationManager (handles preset loading)
            let configManager = try ConfigurationManager()
            let configuration = try configManager.createConfiguration(from: self)
            
            // If preset was loaded, show which preset is being used
            if let presetName = preset {
                print("📋 Using preset '\(presetName)'")
                print("════════════════════════════════════════════════════════════════")
            }
            
            // Use the new modular ScreenRecorder
            let recorder = ScreenRecorder()
            
            // Validate configuration before recording
            try recorder.validateConfiguration(configuration)
            
            // Execute recording with the new modular architecture
            try await recorder.record(with: configuration)
            
        } catch {
            print("❌ Recording error: \(error.localizedDescription)")
            
            // Re-throw the error for proper error handling
            throw error
        }
    }
    

    
    private func validateAudioSetup() {
        let audioManager = AudioManager()
        
        print("🔊 Audio System Status:")
        print("════════════════════════════════════════════════════════════════")
        
        // Check microphone availability
        let micAvailable = audioManager.checkMicrophoneAvailability()
        print("   Microphone: \(micAvailable ? "✅ Available" : "❌ Not Available")")
        
        // Check system audio support
        if #available(macOS 13.0, *) {
            print("   System Audio: ✅ Available (ScreenCaptureKit)")
        } else {
            print("   System Audio: ❌ Requires macOS 13.0+")
        }
        
        // Show current audio settings
        if enableMicrophone {
            if micAvailable {
                print("   Current Setup: 🎤 Microphone + 🔊 System Audio")
            } else {
                print("   Current Setup: ⚠️ Microphone requested but not available, using System Audio only")
            }
        } else {
            print("   Current Setup: 🔊 System Audio only")
        }
        
        print("   Audio Quality: \(audioQuality)")
        print("")
        
        // Validate audio devices
        do {
            try audioManager.validateAudioDevices()
        } catch {
            print("⚠️ Audio validation warning: \(error.localizedDescription)")
        }
    }
    
    private func generateOutputPath() -> String {
        if let customOutput = output {
            return customOutput
        }
        
        // Generate timestamp-based filename with detected format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let detectedFormat = detectOutputFormat()
        let filename = "\(timestamp).\(detectedFormat.fileExtension)"
        
        return FileManager.default.currentDirectoryPath + "/" + filename
    }

}