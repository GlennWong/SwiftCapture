import Foundation
import AVFoundation

/// Enhanced audio status display for command-line interface
/// Provides real-time audio processing feedback and detailed logging
class AudioStatusDisplay {
    
    // MARK: - Properties
    
    /// Whether status display is enabled
    var isEnabled: Bool = false
    
    /// Update interval for status refresh
    var updateInterval: TimeInterval = 1.0 // 1 second updates for status
    
    /// Display width in characters
    var displayWidth: Int = 80
    
    /// Whether to show detailed audio processing information
    var showDetailedInfo: Bool = false
    
    /// Whether to show real-time audio levels
    var showAudioLevels: Bool = false
    
    /// Whether to show spectrum analysis
    var showSpectrum: Bool = false
    
    /// Timer for status updates
    private var statusTimer: Timer?
    
    /// Current audio enhancement settings
    private var currentSettings: AudioEnhancementSettings
    
    /// Audio processing statistics
    private var processingStats = AudioProcessingStatistics()
    
    /// Status update callbacks
    private var statusUpdateCallbacks: [(String) -> Void] = []
    
    /// Error log entries
    private var errorLog: [AudioErrorEntry] = []
    private let maxErrorLogSize: Int = 50
    
    // MARK: - Audio Processing Statistics
    
    private struct AudioProcessingStatistics {
        var totalBuffersProcessed: Int = 0
        var averageProcessingTime: Double = 0.0
        var peakProcessingTime: Double = 0.0
        var qualityIssuesDetected: Int = 0
        var clippingEventsDetected: Int = 0
        var gainAdjustments: Int = 0
        var currentGain: Float = 0.0
        var currentPeakLevel: Float = -Float.infinity
        var currentRMSLevel: Float = -Float.infinity
        var currentTHD: Float = 0.0
        var processingEnabled: Bool = false
        var autoGainActive: Bool = false
        var qualityProtectionActive: Bool = false
        var startTime: Date = Date()
    }
    
    // MARK: - Audio Error Entry
    
    private struct AudioErrorEntry {
        let timestamp: Date
        let level: AudioErrorLevel
        let message: String
        let context: [String: Any]?
    }
    
    private enum AudioErrorLevel {
        case info
        case warning
        case error
        case critical
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
        
        var description: String {
            switch self {
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize audio status display
    /// - Parameters:
    ///   - settings: Audio enhancement settings
    ///   - showLevels: Whether to show real-time audio levels
    ///   - showSpectrum: Whether to show spectrum analysis
    ///   - verbose: Whether to show detailed processing information
    init(settings: AudioEnhancementSettings = AudioEnhancementSettings(),
         showLevels: Bool = false,
         showSpectrum: Bool = false,
         verbose: Bool = false) {
        self.currentSettings = settings
        self.showAudioLevels = showLevels
        self.showSpectrum = showSpectrum
        self.showDetailedInfo = verbose
        
        processingStats.processingEnabled = settings.processingEnabled
        processingStats.autoGainActive = settings.autoGainEnabled
        processingStats.qualityProtectionActive = settings.qualityProtectionEnabled
        processingStats.currentGain = settings.masterGain
    }
    
    deinit {
        stopStatusDisplay()
    }
    
    // MARK: - Public Methods
    
    /// Start real-time status display
    func startStatusDisplay() {
        guard !isEnabled else { return }
        
        isEnabled = true
        processingStats.startTime = Date()
        
        // Show initial status
        showInitialStatus()
        
        // Start status timer
        statusTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateStatusDisplay()
        }
        
        logInfo("Audio status display started")
    }
    
    /// Stop status display
    func stopStatusDisplay() {
        guard isEnabled else { return }
        
        isEnabled = false
        
        // Stop timer
        statusTimer?.invalidate()
        statusTimer = nil
        
        // Show final summary
        showFinalSummary()
        
        logInfo("Audio status display stopped")
    }
    
    /// Update audio processing statistics
    /// - Parameters:
    ///   - processingTime: Time taken to process buffer (in seconds)
    ///   - peakLevel: Current peak audio level (dBFS)
    ///   - rmsLevel: Current RMS audio level (dBFS)
    ///   - thd: Current total harmonic distortion
    ///   - gain: Current applied gain (dB)
    func updateProcessingStats(processingTime: Double, peakLevel: Float, rmsLevel: Float, thd: Float, gain: Float) {
        processingStats.totalBuffersProcessed += 1
        
        // Update processing time statistics
        let alpha = 0.1 // Smoothing factor for exponential moving average
        processingStats.averageProcessingTime = (1 - alpha) * processingStats.averageProcessingTime + alpha * processingTime
        processingStats.peakProcessingTime = max(processingStats.peakProcessingTime, processingTime)
        
        // Update audio level statistics
        processingStats.currentPeakLevel = peakLevel
        processingStats.currentRMSLevel = rmsLevel
        processingStats.currentTHD = thd
        
        // Track gain changes
        if abs(gain - processingStats.currentGain) > 0.1 {
            processingStats.gainAdjustments += 1
            processingStats.currentGain = gain
        }
    }
    
    /// Report a quality issue
    /// - Parameters:
    ///   - issue: Description of the quality issue
    ///   - severity: Severity level (0.0 to 1.0)
    func reportQualityIssue(_ issue: String, severity: Float) {
        processingStats.qualityIssuesDetected += 1
        
        let level: AudioErrorLevel = severity > 0.8 ? .critical : (severity > 0.5 ? .error : .warning)
        logMessage(level: level, message: "Quality issue: \(issue)", context: ["severity": severity])
        
        // Immediate display for critical issues
        if severity > 0.8 {
            print("\n🚨 CRITICAL AUDIO QUALITY ISSUE: \(issue)")
        }
    }
    
    /// Report clipping detection
    /// - Parameter level: Clipping level (dBFS)
    func reportClipping(at level: Float) {
        processingStats.clippingEventsDetected += 1
        
        logMessage(level: .warning, message: "Audio clipping detected", context: ["level": level])
        
        // Immediate display for clipping
        if showDetailedInfo {
            print("\n📢 CLIPPING at \(String(format: "%.1f", level)) dBFS")
        }
    }
    
    /// Add status update callback
    /// - Parameter callback: Callback function to receive status updates
    func addStatusUpdateCallback(_ callback: @escaping (String) -> Void) {
        statusUpdateCallbacks.append(callback)
    }
    
    /// Get current processing statistics
    /// - Returns: Dictionary with current statistics
    func getCurrentStatistics() -> [String: Any] {
        let uptime = Date().timeIntervalSince(processingStats.startTime)
        
        return [
            "uptime": uptime,
            "totalBuffersProcessed": processingStats.totalBuffersProcessed,
            "averageProcessingTime": processingStats.averageProcessingTime,
            "peakProcessingTime": processingStats.peakProcessingTime,
            "qualityIssuesDetected": processingStats.qualityIssuesDetected,
            "clippingEventsDetected": processingStats.clippingEventsDetected,
            "gainAdjustments": processingStats.gainAdjustments,
            "currentGain": processingStats.currentGain,
            "currentPeakLevel": processingStats.currentPeakLevel,
            "currentRMSLevel": processingStats.currentRMSLevel,
            "currentTHD": processingStats.currentTHD,
            "processingEnabled": processingStats.processingEnabled,
            "autoGainActive": processingStats.autoGainActive,
            "qualityProtectionActive": processingStats.qualityProtectionActive
        ]
    }
    
    /// Get error log entries
    /// - Parameter maxEntries: Maximum number of entries to return
    /// - Returns: Array of recent error log entries
    func getErrorLog(maxEntries: Int = 10) -> [String] {
        let recentEntries = Array(errorLog.suffix(maxEntries))
        return recentEntries.map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timestamp = formatter.string(from: entry.timestamp)
            return "[\(timestamp)] \(entry.level.emoji) \(entry.level.description): \(entry.message)"
        }
    }
    
    // MARK: - Private Methods
    
    /// Show initial status when starting
    private func showInitialStatus() {
        print("🎵 Audio Enhancement Status")
        print("════════════════════════════════════════════════════════════════")
        print("   Processing: \(processingStats.processingEnabled ? "✅ Enabled" : "❌ Disabled")")
        print("   Preset: \(currentSettings.preset.rawValue.uppercased())")
        print("   Master Gain: \(String(format: "%.1f", currentSettings.masterGain)) dB")
        print("   Auto Gain: \(processingStats.autoGainActive ? "✅ Active" : "❌ Inactive")")
        print("   Quality Protection: \(processingStats.qualityProtectionActive ? "✅ Active" : "❌ Inactive")")
        
        if showAudioLevels {
            print("   Real-time Levels: ✅ Enabled")
        }
        
        if showSpectrum {
            print("   Spectrum Analysis: ✅ Enabled")
        }
        
        if showDetailedInfo {
            print("   Detailed Logging: ✅ Enabled")
        }
        
        print("════════════════════════════════════════════════════════════════")
        print("")
    }
    
    /// Update the status display
    private func updateStatusDisplay() {
        guard isEnabled else { return }
        
        let statusLine = buildStatusLine()
        
        // Send to callbacks
        for callback in statusUpdateCallbacks {
            callback(statusLine)
        }
        
        // Show detailed status if enabled
        if showDetailedInfo {
            showDetailedStatus()
        }
    }
    
    /// Build a single line status update
    /// - Returns: Formatted status line
    private func buildStatusLine() -> String {
        let uptime = Date().timeIntervalSince(processingStats.startTime)
        let uptimeStr = String(format: "%.0fs", uptime)
        
        let peakStr = processingStats.currentPeakLevel == -Float.infinity ? 
            "Silent" : String(format: "%.1f dBFS", processingStats.currentPeakLevel)
        
        let gainStr = String(format: "%.1f dB", processingStats.currentGain)
        
        let qualityStatus = processingStats.qualityIssuesDetected == 0 ? "✅" : "⚠️"
        
        return "🎵 Audio: Peak:\(peakStr) | Gain:\(gainStr) | Quality:\(qualityStatus) | Uptime:\(uptimeStr)"
    }
    
    /// Show detailed status information
    private func showDetailedStatus() {
        let uptime = Date().timeIntervalSince(processingStats.startTime)
        let bufferRate = processingStats.totalBuffersProcessed > 0 ? 
            Double(processingStats.totalBuffersProcessed) / uptime : 0.0
        
        print("\n📊 Audio Processing Status:")
        print("   Uptime: \(String(format: "%.1f", uptime))s")
        print("   Buffers Processed: \(processingStats.totalBuffersProcessed) (\(String(format: "%.1f", bufferRate))/s)")
        print("   Avg Processing Time: \(String(format: "%.3f", processingStats.averageProcessingTime * 1000))ms")
        print("   Peak Processing Time: \(String(format: "%.3f", processingStats.peakProcessingTime * 1000))ms")
        
        if processingStats.currentPeakLevel > -Float.infinity {
            print("   Current Peak: \(String(format: "%.1f", processingStats.currentPeakLevel)) dBFS")
            print("   Current RMS: \(String(format: "%.1f", processingStats.currentRMSLevel)) dBFS")
            print("   Current THD: \(String(format: "%.3f", processingStats.currentTHD * 100))%")
        }
        
        print("   Applied Gain: \(String(format: "%.1f", processingStats.currentGain)) dB")
        print("   Gain Adjustments: \(processingStats.gainAdjustments)")
        print("   Quality Issues: \(processingStats.qualityIssuesDetected)")
        print("   Clipping Events: \(processingStats.clippingEventsDetected)")
        
        // Show recent errors if any
        if !errorLog.isEmpty {
            print("   Recent Issues:")
            let recentErrors = getErrorLog(maxEntries: 3)
            for error in recentErrors {
                print("     \(error)")
            }
        }
        
        print("")
    }
    
    /// Show final summary when stopping
    private func showFinalSummary() {
        let uptime = Date().timeIntervalSince(processingStats.startTime)
        
        print("\n🎵 Audio Processing Summary:")
        print("════════════════════════════════════════════════════════════════")
        print("   Total Runtime: \(String(format: "%.1f", uptime))s")
        print("   Buffers Processed: \(processingStats.totalBuffersProcessed)")
        
        if processingStats.totalBuffersProcessed > 0 {
            let bufferRate = Double(processingStats.totalBuffersProcessed) / uptime
            print("   Processing Rate: \(String(format: "%.1f", bufferRate)) buffers/s")
            print("   Avg Processing Time: \(String(format: "%.3f", processingStats.averageProcessingTime * 1000))ms")
            print("   Peak Processing Time: \(String(format: "%.3f", processingStats.peakProcessingTime * 1000))ms")
        }
        
        print("   Quality Issues: \(processingStats.qualityIssuesDetected)")
        print("   Clipping Events: \(processingStats.clippingEventsDetected)")
        print("   Gain Adjustments: \(processingStats.gainAdjustments)")
        
        // Performance assessment
        let performanceAssessment = assessPerformance()
        print("   Performance: \(performanceAssessment)")
        
        print("════════════════════════════════════════════════════════════════")
        print("")
    }
    
    /// Assess overall performance
    /// - Returns: Performance assessment string
    private func assessPerformance() -> String {
        let avgProcessingMs = processingStats.averageProcessingTime * 1000
        let qualityIssueRate = processingStats.totalBuffersProcessed > 0 ? 
            Float(processingStats.qualityIssuesDetected) / Float(processingStats.totalBuffersProcessed) : 0.0
        
        if avgProcessingMs > 10.0 {
            return "⚠️ High latency (\(String(format: "%.1f", avgProcessingMs))ms avg)"
        } else if qualityIssueRate > 0.1 {
            return "⚠️ Quality issues (\(String(format: "%.1f", qualityIssueRate * 100))% rate)"
        } else if processingStats.clippingEventsDetected > 0 {
            return "⚠️ Audio clipping detected"
        } else {
            return "✅ Excellent"
        }
    }
    
    /// Log an informational message
    /// - Parameter message: Message to log
    private func logInfo(_ message: String) {
        logMessage(level: .info, message: message, context: nil)
    }
    
    /// Log a warning message
    /// - Parameter message: Message to log
    private func logWarning(_ message: String) {
        logMessage(level: .warning, message: message, context: nil)
    }
    
    /// Log an error message
    /// - Parameter message: Message to log
    private func logError(_ message: String) {
        logMessage(level: .error, message: message, context: nil)
    }
    
    /// Log a message with specified level
    /// - Parameters:
    ///   - level: Error level
    ///   - message: Message to log
    ///   - context: Additional context information
    private func logMessage(level: AudioErrorLevel, message: String, context: [String: Any]?) {
        let entry = AudioErrorEntry(
            timestamp: Date(),
            level: level,
            message: message,
            context: context
        )
        
        errorLog.append(entry)
        
        // Maintain log size limit
        if errorLog.count > maxErrorLogSize {
            errorLog.removeFirst(errorLog.count - maxErrorLogSize)
        }
        
        // Print to console if detailed info is enabled
        if showDetailedInfo {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timestamp = formatter.string(from: entry.timestamp)
            print("[\(timestamp)] \(level.emoji) \(message)")
        }
    }
}

// MARK: - Extensions

extension AudioStatusDisplay {
    
    /// Create a status display for basic audio monitoring
    /// - Parameters:
    ///   - settings: Audio enhancement settings
    ///   - verbose: Whether to show detailed information
    /// - Returns: Configured AudioStatusDisplay instance
    static func createBasicDisplay(settings: AudioEnhancementSettings, verbose: Bool = false) -> AudioStatusDisplay {
        return AudioStatusDisplay(
            settings: settings,
            showLevels: false,
            showSpectrum: false,
            verbose: verbose
        )
    }
    
    /// Create a status display for full audio monitoring
    /// - Parameters:
    ///   - settings: Audio enhancement settings
    ///   - verbose: Whether to show detailed information
    /// - Returns: Configured AudioStatusDisplay instance
    static func createFullDisplay(settings: AudioEnhancementSettings, verbose: Bool = false) -> AudioStatusDisplay {
        return AudioStatusDisplay(
            settings: settings,
            showLevels: true,
            showSpectrum: true,
            verbose: verbose
        )
    }
}