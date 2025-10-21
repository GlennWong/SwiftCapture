import Foundation
import AVFoundation

/// Real-time audio monitoring display for command-line interface
class AudioMonitoringDisplay {
    
    // MARK: - Properties
    
    /// Whether monitoring display is enabled
    var isEnabled: Bool = false
    
    /// Update interval for display refresh
    var updateInterval: TimeInterval = 0.2 // 200ms updates
    
    /// Display width in characters
    var displayWidth: Int = 80
    
    /// Whether to use Unicode characters for better visualization
    var useUnicode: Bool = true
    
    /// Level meter for audio levels
    private var levelMeter: AudioLevelMeter?
    
    /// Spectrum analyzer for frequency display
    private var spectrumAnalyzer: AudioSpectrumAnalyzer?
    
    /// Quality monitor for audio quality metrics
    private var qualityMonitor: AudioQualityMonitor?
    
    /// Timer for display updates
    private var displayTimer: Timer?
    
    /// Last display update timestamp
    private var lastUpdate: Date = Date()
    
    /// Current audio enhancement settings
    private var currentSettings: AudioEnhancementSettings
    
    /// Display statistics
    private var displayStats = DisplayStatistics()
    
    /// Console cursor control
    private let consoleCursor = ConsoleCursor()
    
    // MARK: - Display Statistics
    
    private struct DisplayStatistics {
        var totalUpdates: Int = 0
        var qualityIssues: Int = 0
        var clippingEvents: Int = 0
        var lastClippingTime: Date?
        var peakHold: Float = -Float.infinity
        var peakHoldTime: Date?
    }
    
    // MARK: - Initialization
    
    /// Initialize audio monitoring display
    /// - Parameter settings: Audio enhancement settings
    init(settings: AudioEnhancementSettings = AudioEnhancementSettings()) {
        self.currentSettings = settings
        setupMonitoringComponents()
    }
    
    deinit {
        stopDisplay()
    }
    
    // MARK: - Public Methods
    
    /// Start real-time monitoring display
    func startDisplay() {
        guard !isEnabled else { return }
        
        isEnabled = true
        
        // Clear screen and setup display
        consoleCursor.clearScreen()
        consoleCursor.hideCursor()
        
        // Start display timer
        displayTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        
        print("📊 Real-time audio monitoring started")
        print("Press Ctrl+C to stop monitoring\n")
    }
    
    /// Stop monitoring display
    func stopDisplay() {
        guard isEnabled else { return }
        
        isEnabled = false
        
        // Stop timer
        displayTimer?.invalidate()
        displayTimer = nil
        
        // Restore cursor and clear screen
        consoleCursor.showCursor()
        consoleCursor.clearScreen()
        
        // Print final statistics
        printFinalStatistics()
    }
    
    /// Process audio buffer for monitoring
    /// - Parameter buffer: Audio buffer to monitor
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return }
        
        // Update monitoring components
        levelMeter?.processBuffer(buffer)
        spectrumAnalyzer?.processBuffer(buffer)
        
        do {
            try qualityMonitor?.processAudioBuffer(buffer)
        } catch {
            print("⚠️ Quality monitoring error: \(error.localizedDescription)")
        }
        
        // Update statistics
        displayStats.totalUpdates += 1
        
        // Update peak hold
        if let peak = levelMeter?.peakLevel, peak > displayStats.peakHold {
            displayStats.peakHold = peak
            displayStats.peakHoldTime = Date()
        }
    }
    
    /// Update monitoring settings
    /// - Parameter settings: New audio enhancement settings
    func updateSettings(_ settings: AudioEnhancementSettings) {
        currentSettings = settings
        print("⚙️ Monitoring settings updated: \(settings.preset.rawValue)")
    }
    
    /// Get current monitoring status
    /// - Returns: Dictionary with monitoring status
    func getMonitoringStatus() -> [String: Any] {
        return [
            "isEnabled": isEnabled,
            "updateInterval": updateInterval,
            "totalUpdates": displayStats.totalUpdates,
            "qualityIssues": displayStats.qualityIssues,
            "clippingEvents": displayStats.clippingEvents,
            "peakHold": displayStats.peakHold,
            "settings": [
                "preset": currentSettings.preset.rawValue,
                "processingEnabled": currentSettings.processingEnabled
            ]
        ]
    }
    
    // MARK: - Private Methods
    
    /// Setup monitoring components
    private func setupMonitoringComponents() {
        // Initialize level meter
        levelMeter = AudioLevelMeter()
        levelMeter?.delegate = self
        
        // Initialize spectrum analyzer
        spectrumAnalyzer = AudioSpectrumAnalyzer()
        spectrumAnalyzer?.delegate = self
        
        // Initialize quality monitor
        qualityMonitor = AudioQualityMonitor()
        qualityMonitor?.delegate = self
    }
    
    /// Update the real-time display
    private func updateDisplay() {
        guard isEnabled else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastUpdate) >= updateInterval else { return }
        
        // Move cursor to top of display area
        consoleCursor.moveTo(row: 1, column: 1)
        
        // Build display content
        var display = buildDisplayContent()
        
        // Ensure display fits terminal width
        display = formatDisplayForTerminal(display)
        
        // Print display
        print(display, terminator: "")
        fflush(stdout)
        
        lastUpdate = now
    }
    
    /// Build the complete display content
    /// - Returns: Formatted display string
    private func buildDisplayContent() -> String {
        var content = ""
        
        // Header
        content += buildHeader()
        content += "\n"
        
        // Audio levels section
        content += buildLevelsSection()
        content += "\n"
        
        // Spectrum analyzer section
        content += buildSpectrumSection()
        content += "\n"
        
        // Quality metrics section
        content += buildQualitySection()
        content += "\n"
        
        // Statistics section
        content += buildStatisticsSection()
        
        return content
    }
    
    /// Build display header
    /// - Returns: Header string
    private func buildHeader() -> String {
        let timestamp = DateFormatter.timeFormatter.string(from: Date())
        let preset = currentSettings.preset.rawValue.uppercased()
        let processing = currentSettings.processingEnabled ? "ON" : "OFF"
        
        let separator = String(repeating: "═", count: displayWidth)
        
        return """
        \(separator)
        🎵 SWIFTCAPTURE AUDIO MONITOR - \(timestamp)
        Preset: \(preset) | Processing: \(processing) | Updates: \(displayStats.totalUpdates)
        \(separator)
        """
    }
    
    /// Build audio levels section
    /// - Returns: Levels display string
    private func buildLevelsSection() -> String {
        guard let levelMeter = levelMeter else {
            return "📊 Audio Levels: Not available"
        }
        
        let peak = levelMeter.peakLevel
        let rms = levelMeter.rmsLevel
        
        let peakStr = peak == -Float.infinity ? "Silent" : String(format: "%6.1f dBFS", peak)
        let rmsStr = rms == -Float.infinity ? "Silent" : String(format: "%6.1f dBFS", rms)
        
        let levelBar = levelMeter.getLevelBar(width: displayWidth - 20, useUnicode: useUnicode)
        
        // Peak hold display
        let peakHoldStr = displayStats.peakHold == -Float.infinity ? "N/A" : String(format: "%.1f dBFS", displayStats.peakHold)
        
        return """
        📊 AUDIO LEVELS
        Peak: \(peakStr) | RMS: \(rmsStr) | Peak Hold: \(peakHoldStr)
        \(levelBar)
        """
    }
    
    /// Build spectrum analyzer section
    /// - Returns: Spectrum display string
    private func buildSpectrumSection() -> String {
        guard let spectrumAnalyzer = spectrumAnalyzer else {
            return "🌈 Frequency Spectrum: Not available"
        }
        
        let bandSpectrum = spectrumAnalyzer.getBandSpectrum()
        let sortedBands = bandSpectrum.keys.sorted()
        
        var spectrumDisplay = "🌈 FREQUENCY SPECTRUM (dB)\n"
        
        // Create horizontal bar chart
        for band in sortedBands {
            let magnitude = bandSpectrum[band] ?? -80.0
            let normalizedMag = max(0, (magnitude + 60.0) / 60.0) // -60dB to 0dB range
            let barLength = Int(normalizedMag * 30) // 30 character bars
            
            let freqLabel = formatFrequency(band)
            let bar = String(repeating: useUnicode ? "█" : "#", count: barLength)
            let padding = String(repeating: useUnicode ? "░" : ".", count: 30 - barLength)
            
            spectrumDisplay += String(format: "%6s: [%@%@] %5.1f\n", freqLabel, bar, padding, magnitude)
        }
        
        return spectrumDisplay
    }
    
    /// Build quality metrics section
    /// - Returns: Quality display string
    private func buildQualitySection() -> String {
        guard let qualityMonitor = qualityMonitor else {
            return "🔍 Audio Quality: Not available"
        }
        
        let metrics = qualityMonitor.getCurrentMetrics()
        
        let thdPercent = metrics.thd * 100.0
        let thdStatus = thdPercent > currentSettings.maxTHD * 100.0 ? "⚠️" : "✅"
        
        let clippingStatus = metrics.clippingDetected ? "⚠️ YES" : "✅ NO"
        let dynamicRange = String(format: "%.1f dB", metrics.dynamicRange)
        
        // Quality indicators
        let qualityIndicators = buildQualityIndicators(metrics)
        
        return """
        🔍 AUDIO QUALITY METRICS
        THD+N: \(String(format: "%.3f", thdPercent))% \(thdStatus) | Dynamic Range: \(dynamicRange) | Clipping: \(clippingStatus)
        \(qualityIndicators)
        """
    }
    
    /// Build quality indicators bar
    /// - Parameter metrics: Audio quality metrics
    /// - Returns: Quality indicators string
    private func buildQualityIndicators(_ metrics: AudioMetrics) -> String {
        let indicators = [
            ("THD", metrics.thd < currentSettings.maxTHD),
            ("Levels", metrics.peakLevel < -3.0),
            ("Range", metrics.dynamicRange > 6.0),
            ("Clip", !metrics.clippingDetected)
        ]
        
        var indicatorDisplay = "Quality: "
        
        for (name, isGood) in indicators {
            let status = isGood ? (useUnicode ? "🟢" : "OK") : (useUnicode ? "🔴" : "!!")
            indicatorDisplay += "\(name):\(status) "
        }
        
        return indicatorDisplay
    }
    
    /// Build statistics section
    /// - Returns: Statistics display string
    private func buildStatisticsSection() -> String {
        let uptime = Date().timeIntervalSince(lastUpdate)
        let uptimeStr = String(format: "%.1fs", uptime)
        
        let clippingRate = displayStats.totalUpdates > 0 ? 
            Float(displayStats.clippingEvents) / Float(displayStats.totalUpdates) * 100.0 : 0.0
        
        let lastClippingStr = displayStats.lastClippingTime?.timeIntervalSinceNow ?? 0 < -5 ? 
            "None recent" : "Recent"
        
        return """
        📈 STATISTICS
        Uptime: \(uptimeStr) | Quality Issues: \(displayStats.qualityIssues) | Clipping Rate: \(String(format: "%.1f", clippingRate))%
        Last Clipping: \(lastClippingStr)
        """
    }
    
    /// Format display content for terminal width
    /// - Parameter content: Raw display content
    /// - Returns: Formatted content that fits terminal
    private func formatDisplayForTerminal(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var formattedLines: [String] = []
        
        for line in lines {
            if line.count > displayWidth {
                // Truncate long lines
                let truncated = String(line.prefix(displayWidth - 3)) + "..."
                formattedLines.append(truncated)
            } else {
                // Pad short lines to clear previous content
                let padded = line.padding(toLength: displayWidth, withPad: " ", startingAt: 0)
                formattedLines.append(padded)
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    /// Format frequency for display
    /// - Parameter frequency: Frequency in Hz
    /// - Returns: Formatted frequency string
    private func formatFrequency(_ frequency: Float) -> String {
        if frequency >= 1000 {
            return String(format: "%.0fk", frequency / 1000.0)
        } else {
            return String(format: "%.0f", frequency)
        }
    }
    
    /// Print final statistics when stopping
    private func printFinalStatistics() {
        print("\n📊 Final Audio Monitoring Statistics:")
        print("   Total Updates: \(displayStats.totalUpdates)")
        print("   Quality Issues: \(displayStats.qualityIssues)")
        print("   Clipping Events: \(displayStats.clippingEvents)")
        
        if displayStats.peakHold > -Float.infinity {
            print("   Peak Hold: \(String(format: "%.1f", displayStats.peakHold)) dBFS")
        }
        
        print("Audio monitoring stopped.\n")
    }
}

// MARK: - Console Cursor Control

/// Helper class for console cursor control
private class ConsoleCursor {
    
    /// Clear the entire screen
    func clearScreen() {
        print("\u{001B}[2J", terminator: "")
    }
    
    /// Move cursor to specific position
    /// - Parameters:
    ///   - row: Row number (1-based)
    ///   - column: Column number (1-based)
    func moveTo(row: Int, column: Int) {
        print("\u{001B}[\(row);\(column)H", terminator: "")
    }
    
    /// Hide cursor
    func hideCursor() {
        print("\u{001B}[?25l", terminator: "")
    }
    
    /// Show cursor
    func showCursor() {
        print("\u{001B}[?25h", terminator: "")
    }
    
    /// Move cursor up by specified lines
    /// - Parameter lines: Number of lines to move up
    func moveUp(_ lines: Int) {
        print("\u{001B}[\(lines)A", terminator: "")
    }
    
    /// Clear current line
    func clearLine() {
        print("\u{001B}[2K", terminator: "")
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Monitoring Delegates

extension AudioMonitoringDisplay: AudioLevelMeterDelegate {
    func levelMeterUpdated(peak: Float, rms: Float) {
        // Level updates are handled in the display timer
        // This delegate method can be used for immediate alerts if needed
    }
}

extension AudioMonitoringDisplay: AudioSpectrumAnalyzerDelegate {
    func spectrumAnalyzerUpdated(magnitudes: [Float], frequencies: [Float]) {
        // Spectrum updates are handled in the display timer
        // This delegate method can be used for frequency-specific alerts if needed
    }
}

extension AudioMonitoringDisplay: AudioQualityMonitorDelegate {
    func audioQualityUpdated(_ metrics: AudioMetrics) {
        // Quality updates are handled in the display timer
        // This delegate method can be used for quality-specific processing if needed
    }
    
    func audioQualityIssueDetected(_ issue: String, severity: Float) {
        displayStats.qualityIssues += 1
        
        // For high severity issues, we might want to show immediate alerts
        if severity > 0.8 {
            print("\n🚨 CRITICAL AUDIO ISSUE: \(issue)")
        }
    }
    
    func clippingDetected(at level: Float) {
        displayStats.clippingEvents += 1
        displayStats.lastClippingTime = Date()
        
        // Immediate clipping alert
        print("\n📢 CLIPPING at \(String(format: "%.1f", level)) dBFS")
    }
    
    func qualityDegradationDetected(originalMetrics: AudioMetrics, processedMetrics: AudioMetrics, recommendedAction: QualityProtectionAction) {
        displayStats.qualityIssues += 1
        
        // Show quality degradation warning
        print("\n🔍 Quality degradation detected - action: \(recommendedAction)")
    }
    
    func losslessModeRecommended(reason: String) {
        // Show lossless mode recommendation
        print("\n🔒 Lossless mode recommended: \(reason)")
    }
}