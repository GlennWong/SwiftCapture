import Foundation

/// Serializable preset for recording configurations
struct RecordingPreset: Codable {
    /// Preset name
    let name: String
    
    /// Recording duration in milliseconds
    let duration: Int
    
    /// Recording area specification (optional)
    let area: String?
    
    /// Screen index
    let screen: Int
    
    /// Application name (optional)
    let app: String?
    
    /// Whether microphone is enabled
    let enableMicrophone: Bool
    
    /// Frame rate
    let fps: Int
    
    /// Video quality
    let quality: String
    
    /// Output format
    let format: String
    
    /// Whether to show cursor
    let showCursor: Bool
    
    /// Countdown duration in seconds
    let countdown: Int
    
    /// Audio quality
    let audioQuality: String
    
    /// When the preset was created
    let createdAt: Date
    
    /// When the preset was last used (mutable for updates)
    var lastUsed: Date?
    
    /// Create a preset from a recording configuration
    /// - Parameters:
    ///   - configuration: RecordingConfiguration to convert
    ///   - name: Preset name
    init(from configuration: RecordingConfiguration, name: String) {
        self.name = name
        self.duration = Int(configuration.duration * 1000) // Convert to milliseconds
        
        // Convert recording area to string representation
        switch configuration.recordingArea {
        case .fullScreen:
            self.area = nil
        case .customRect(let rect):
            self.area = "\(Int(rect.origin.x)):\(Int(rect.origin.y)):\(Int(rect.width)):\(Int(rect.height))"
        case .centered(let width, let height):
            self.area = "center:\(width):\(height)"
        }
        
        self.screen = configuration.targetScreen?.index ?? 1
        self.app = configuration.targetApplication?.name
        self.enableMicrophone = configuration.audioSettings.includeMicrophone
        self.fps = configuration.videoSettings.fps
        self.quality = configuration.videoSettings.quality.rawValue
        self.format = configuration.outputFormat.rawValue
        self.showCursor = configuration.videoSettings.showCursor
        self.countdown = configuration.countdown
        self.audioQuality = configuration.audioSettings.quality.rawValue
        self.createdAt = Date()
        self.lastUsed = nil
    }
    
    /// Convert preset back to recording configuration
    /// - Parameters:
    ///   - outputURL: Output URL for the recording
    ///   - targetScreen: Target screen info (optional)
    ///   - targetApplication: Target application info (optional)
    /// - Returns: RecordingConfiguration
    /// - Throws: ValidationError if preset data is invalid
    func toRecordingConfiguration(outputURL: URL, 
                                targetScreen: ScreenInfo? = nil,
                                targetApplication: ApplicationInfo? = nil) throws -> RecordingConfiguration {
        
        // Parse recording area
        let recordingArea: RecordingArea
        if let areaString = area {
            recordingArea = try RecordingArea.parse(from: areaString)
        } else {
            recordingArea = .fullScreen
        }
        
        // Parse video quality
        guard let videoQuality = VideoQuality(rawValue: quality) else {
            throw ValidationError.invalidQuality(quality)
        }
        
        // Parse output format
        guard let outputFormat = OutputFormat(rawValue: format) else {
            throw ValidationError.invalidFormat(format)
        }
        
        // Parse audio quality
        guard let audioQualityEnum = AudioQuality(rawValue: audioQuality) else {
            throw ValidationError("Invalid audio quality in preset: '\(audioQuality)'",
                                suggestion: "Valid audio qualities are: low, medium, high")
        }
        
        // Create audio settings
        let audioSettings = AudioSettings(
            includeMicrophone: enableMicrophone,
            includeSystemAudio: true, // Always include system audio
            forceSystemAudio: false, // Default to false for presets
            quality: audioQualityEnum,
            sampleRate: audioQualityEnum.sampleRate,
            bitRate: audioQualityEnum.bitRate,
            channels: 2
        )
        
        // Create video settings (resolution will be set based on actual screen/area)
        let videoSettings = VideoSettings(
            fps: fps,
            quality: videoQuality,
            codec: .h264,
            showCursor: showCursor,
            resolution: CGSize(width: 1920, height: 1080) // Placeholder, will be updated
        )
        
        return RecordingConfiguration(
            duration: TimeInterval(duration) / 1000.0, // Convert from milliseconds
            outputURL: outputURL,
            outputFormat: outputFormat,
            recordingArea: recordingArea,
            targetScreen: targetScreen,
            targetApplication: targetApplication,
            audioSettings: audioSettings,
            videoSettings: videoSettings,
            countdown: countdown
        )
    }
}

extension RecordingPreset: CustomStringConvertible {
    var description: String {
        var components: [String] = []
        
        components.append("Name: \(name)")
        components.append("Duration: \(duration)ms")
        
        if let area = area {
            components.append("Area: \(area)")
        } else {
            components.append("Area: Full Screen")
        }
        
        components.append("Screen: \(screen)")
        
        if let app = app {
            components.append("App: \(app)")
        }
        
        components.append("Video: \(fps)fps, \(quality)")
        components.append("Audio: \(enableMicrophone ? "mic + system" : "system only")")
        components.append("Format: \(format.uppercased())")
        
        if showCursor {
            components.append("Cursor: visible")
        }
        
        if countdown > 0 {
            components.append("Countdown: \(countdown)s")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        components.append("Created: \(dateFormatter.string(from: createdAt))")
        
        if let lastUsed = lastUsed {
            components.append("Last used: \(dateFormatter.string(from: lastUsed))")
        }
        
        return components.joined(separator: ", ")
    }
}