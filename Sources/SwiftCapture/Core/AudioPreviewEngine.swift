import Foundation
import AVFoundation

/// Audio preview engine for real-time audio effect preview
class AudioPreviewEngine {
    
    // MARK: - Error Types
    
    enum PreviewError: LocalizedError {
        case audioEngineSetupFailed(Error)
        case audioFormatNotSupported
        case previewAlreadyActive
        case previewNotActive
        case audioProcessingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .audioEngineSetupFailed(let error):
                return "Audio engine setup failed: \(error.localizedDescription)"
            case .audioFormatNotSupported:
                return "Audio format not supported for preview"
            case .previewAlreadyActive:
                return "Audio preview is already active"
            case .previewNotActive:
                return "Audio preview is not active"
            case .audioProcessingFailed(let error):
                return "Audio processing failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Audio engine for preview playback
    private var audioEngine: AVAudioEngine?
    
    /// Audio processor for effects
    private var audioProcessor: AudioProcessor?
    
    /// Level meter for monitoring
    private var levelMeter: AudioLevelMeter?
    
    /// Spectrum analyzer for visualization
    private var spectrumAnalyzer: AudioSpectrumAnalyzer?
    
    /// Quality monitor for real-time feedback
    private var qualityMonitor: AudioQualityMonitor?
    
    /// Current enhancement settings
    private var currentSettings: AudioEnhancementSettings
    
    /// Whether preview is currently active
    private(set) var isPreviewActive: Bool = false
    
    /// Preview volume (0.0 to 1.0)
    var previewVolume: Float = 0.5 {
        didSet {
            updatePreviewVolume()
        }
    }
    
    /// Delegate for preview updates
    weak var delegate: AudioPreviewEngineDelegate?
    
    /// Audio format for preview
    private let previewFormat: AVAudioFormat
    
    /// Player node for preview playback
    private var playerNode: AVAudioPlayerNode?
    
    /// Mixer node for volume control
    private var mixerNode: AVAudioMixerNode?
    
    /// Audio unit for real-time processing
    private var processingUnit: AVAudioUnit?
    
    // MARK: - Initialization
    
    /// Initialize audio preview engine
    /// - Parameter settings: Initial audio enhancement settings
    init(settings: AudioEnhancementSettings = AudioEnhancementSettings()) throws {
        self.currentSettings = settings
        
        // Create standard preview format (48kHz, stereo, float)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) else {
            throw PreviewError.audioFormatNotSupported
        }
        self.previewFormat = format
        
        try setupAudioEngine()
        setupMonitoring()
    }
    
    deinit {
        stopPreview()
        cleanupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// Start audio preview with current settings
    /// - Throws: PreviewError if preview cannot be started
    func startPreview() throws {
        guard !isPreviewActive else {
            throw PreviewError.previewAlreadyActive
        }
        
        guard let audioEngine = audioEngine else {
            throw PreviewError.audioEngineSetupFailed(
                NSError(domain: "AudioPreviewEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
            )
        }
        
        do {
            // Start audio engine
            try audioEngine.start()
            isPreviewActive = true
            
            print("🎧 Audio preview started")
            print("   Format: \(previewFormat.sampleRate) Hz, \(previewFormat.channelCount) channels")
            print("   Volume: \(Int(previewVolume * 100))%")
            
            // Notify delegate
            delegate?.previewEngineStarted()
            
        } catch {
            throw PreviewError.audioEngineSetupFailed(error)
        }
    }
    
    /// Stop audio preview
    func stopPreview() {
        guard isPreviewActive else { return }
        
        audioEngine?.stop()
        isPreviewActive = false
        
        // Reset monitoring components
        levelMeter?.reset()
        spectrumAnalyzer?.reset()
        qualityMonitor?.reset()
        
        print("🔇 Audio preview stopped")
        
        // Notify delegate
        delegate?.previewEngineStopped()
    }
    
    /// Update preview settings
    /// - Parameter settings: New audio enhancement settings
    /// - Throws: PreviewError if settings update fails
    func updateSettings(_ settings: AudioEnhancementSettings) throws {
        currentSettings = settings
        
        // Update audio processor if available
        if let processor = audioProcessor {
            do {
                try processor.updateSettings(settings)
                print("⚙️ Preview settings updated: \(settings.preset.rawValue)")
                
                // Notify delegate
                delegate?.previewSettingsUpdated(settings)
                
            } catch {
                throw PreviewError.audioProcessingFailed(error)
            }
        }
    }
    
    /// Process audio buffer for preview (used by capture system)
    /// - Parameter buffer: Audio buffer to process and preview
    /// - Throws: PreviewError if processing fails
    func processPreviewBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard isPreviewActive else { return }
        
        // Process with audio processor if available and enabled
        var processedBuffer = buffer
        if let processor = audioProcessor, currentSettings.processingEnabled {
            do {
                processedBuffer = try processor.processAudioBuffer(buffer, settings: currentSettings)
            } catch {
                throw PreviewError.audioProcessingFailed(error)
            }
        }
        
        // Update monitoring components
        levelMeter?.processBuffer(processedBuffer)
        spectrumAnalyzer?.processBuffer(processedBuffer)
        
        do {
            try qualityMonitor?.processAudioBuffer(processedBuffer)
        } catch {
            print("⚠️ Quality monitoring error: \(error.localizedDescription)")
        }
        
        // Schedule buffer for playback if player node is available
        if let playerNode = playerNode, playerNode.isPlaying {
            playerNode.scheduleBuffer(processedBuffer, completionHandler: nil)
        }
    }
    
    /// Get current preview status
    /// - Returns: Dictionary with preview status information
    func getPreviewStatus() -> [String: Any] {
        var status: [String: Any] = [
            "isActive": isPreviewActive,
            "volume": previewVolume,
            "format": [
                "sampleRate": previewFormat.sampleRate,
                "channels": previewFormat.channelCount
            ],
            "settings": [
                "preset": currentSettings.preset.rawValue,
                "processingEnabled": currentSettings.processingEnabled,
                "masterGain": currentSettings.masterGain
            ]
        ]
        
        // Add monitoring data if available
        if let levelMeter = levelMeter {
            status["levels"] = [
                "peak": levelMeter.peakLevel,
                "rms": levelMeter.rmsLevel,
                "description": levelMeter.getLevelsDescription()
            ]
        }
        
        if let spectrumAnalyzer = spectrumAnalyzer {
            let bandSpectrum = spectrumAnalyzer.getBandSpectrum()
            status["spectrum"] = bandSpectrum
        }
        
        if let qualityMonitor = qualityMonitor {
            let metrics = qualityMonitor.getCurrentMetrics()
            status["quality"] = [
                "thd": metrics.thd,
                "clippingDetected": metrics.clippingDetected,
                "dynamicRange": metrics.dynamicRange
            ]
        }
        
        return status
    }
    
    /// Get real-time monitoring display
    /// - Returns: Formatted string with real-time audio information
    func getMonitoringDisplay() -> String {
        var display = "🎧 Audio Preview Monitor\n"
        
        // Status
        display += "Status: \(isPreviewActive ? "🟢 Active" : "🔴 Inactive")\n"
        display += "Volume: \(Int(previewVolume * 100))% | Preset: \(currentSettings.preset.rawValue)\n"
        
        // Level meters
        if let levelMeter = levelMeter {
            display += "\n📊 Audio Levels:\n"
            display += "   \(levelMeter.getLevelsDescription())\n"
            display += "   \(levelMeter.getLevelBar(width: 30))\n"
        }
        
        // Quality metrics
        if let qualityMonitor = qualityMonitor {
            let metrics = qualityMonitor.getCurrentMetrics()
            display += "\n🔍 Quality Metrics:\n"
            display += "   THD: \(String(format: "%.3f", metrics.thd * 100))% | "
            display += "Dynamic Range: \(String(format: "%.1f", metrics.dynamicRange)) dB\n"
            display += "   Clipping: \(metrics.clippingDetected ? "⚠️ YES" : "✅ NO")\n"
        }
        
        // Spectrum analyzer
        if let spectrumAnalyzer = spectrumAnalyzer {
            display += "\n🌈 Frequency Spectrum:\n"
            let bandSpectrum = spectrumAnalyzer.getBandSpectrum()
            let sortedBands = bandSpectrum.keys.sorted()
            
            for band in sortedBands {
                let magnitude = bandSpectrum[band] ?? -80.0
                let barLength = max(0, Int((magnitude + 60.0) / 60.0 * 20)) // -60dB to 0dB range
                let bar = String(repeating: "█", count: barLength) + String(repeating: "░", count: 20 - barLength)
                
                let freqStr = band >= 1000 ? String(format: "%.0fk", band / 1000) : String(format: "%.0f", band)
                display += "   \(String(format: "%5s", freqStr)): [\(bar)] \(String(format: "%5.1f", magnitude))dB\n"
            }
        }
        
        return display
    }
    
    // MARK: - Private Methods
    
    /// Setup audio engine for preview
    /// - Throws: PreviewError if setup fails
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            throw PreviewError.audioEngineSetupFailed(
                NSError(domain: "AudioPreviewEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
            )
        }
        
        // Create nodes
        playerNode = AVAudioPlayerNode()
        mixerNode = AVAudioMixerNode()
        
        guard let playerNode = playerNode,
              let mixerNode = mixerNode else {
            throw PreviewError.audioEngineSetupFailed(
                NSError(domain: "AudioPreviewEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio nodes"])
            )
        }
        
        // Attach nodes to engine
        audioEngine.attach(playerNode)
        audioEngine.attach(mixerNode)
        
        // Connect nodes: player -> mixer -> output
        audioEngine.connect(playerNode, to: mixerNode, format: previewFormat)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: previewFormat)
        
        // Set initial volume
        updatePreviewVolume()
        
        // Prepare audio engine
        audioEngine.prepare()
        
        print("🔧 Audio preview engine setup complete")
    }
    
    /// Setup monitoring components
    private func setupMonitoring() {
        // Initialize audio processor
        audioProcessor = AudioProcessor(settings: currentSettings)
        
        // Initialize level meter
        levelMeter = AudioLevelMeter()
        levelMeter?.delegate = self
        
        // Initialize spectrum analyzer
        spectrumAnalyzer = AudioSpectrumAnalyzer()
        spectrumAnalyzer?.delegate = self
        
        // Initialize quality monitor
        qualityMonitor = AudioQualityMonitor()
        qualityMonitor?.delegate = self
        
        print("📊 Audio monitoring components initialized")
    }
    
    /// Update preview volume
    private func updatePreviewVolume() {
        mixerNode?.outputVolume = previewVolume
    }
    
    /// Cleanup audio engine resources
    private func cleanupAudioEngine() {
        stopPreview()
        audioEngine = nil
        playerNode = nil
        mixerNode = nil
        processingUnit = nil
    }
}

// MARK: - AudioPreviewEngineDelegate

/// Delegate protocol for audio preview engine events
protocol AudioPreviewEngineDelegate: AnyObject {
    /// Called when preview engine starts
    func previewEngineStarted()
    
    /// Called when preview engine stops
    func previewEngineStopped()
    
    /// Called when preview settings are updated
    /// - Parameter settings: New audio enhancement settings
    func previewSettingsUpdated(_ settings: AudioEnhancementSettings)
    
    /// Called when real-time monitoring data is updated
    /// - Parameter monitoringData: Dictionary with current monitoring information
    func previewMonitoringUpdated(_ monitoringData: [String: Any])
}

// MARK: - Monitoring Delegates

extension AudioPreviewEngine: AudioLevelMeterDelegate {
    func levelMeterUpdated(peak: Float, rms: Float) {
        let monitoringData: [String: Any] = [
            "type": "levels",
            "peak": peak,
            "rms": rms,
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
    }
}

extension AudioPreviewEngine: AudioSpectrumAnalyzerDelegate {
    func spectrumAnalyzerUpdated(magnitudes: [Float], frequencies: [Float]) {
        let monitoringData: [String: Any] = [
            "type": "spectrum",
            "magnitudes": magnitudes,
            "frequencies": frequencies,
            "bandSpectrum": spectrumAnalyzer?.getBandSpectrum() ?? [:],
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
    }
}

extension AudioPreviewEngine: AudioQualityMonitorDelegate {
    func audioQualityUpdated(_ metrics: AudioMetrics) {
        let monitoringData: [String: Any] = [
            "type": "quality",
            "metrics": [
                "peak": metrics.peakLevel,
                "rms": metrics.rmsLevel,
                "thd": metrics.thd,
                "dynamicRange": metrics.dynamicRange,
                "clippingDetected": metrics.clippingDetected
            ],
            "timestamp": metrics.timestamp
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
    }
    
    func audioQualityIssueDetected(_ issue: String, severity: Float) {
        let monitoringData: [String: Any] = [
            "type": "qualityIssue",
            "issue": issue,
            "severity": severity,
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
        
        print("🚨 Preview Quality Issue (\(String(format: "%.0f", severity * 100))%): \(issue)")
    }
    
    func clippingDetected(at level: Float) {
        let monitoringData: [String: Any] = [
            "type": "clipping",
            "level": level,
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
        
        print("📢 Preview Clipping detected at \(String(format: "%.1f", level)) dBFS")
    }
    
    func qualityDegradationDetected(originalMetrics: AudioMetrics, processedMetrics: AudioMetrics, recommendedAction: QualityProtectionAction) {
        let monitoringData: [String: Any] = [
            "type": "qualityDegradation",
            "originalTHD": originalMetrics.thd,
            "processedTHD": processedMetrics.thd,
            "recommendedAction": String(describing: recommendedAction),
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
        
        print("🔍 Preview Quality degradation detected - action: \(recommendedAction)")
    }
    
    func losslessModeRecommended(reason: String) {
        let monitoringData: [String: Any] = [
            "type": "losslessModeRecommended",
            "reason": reason,
            "timestamp": Date()
        ]
        
        delegate?.previewMonitoringUpdated(monitoringData)
        
        print("🔒 Preview Lossless mode recommended: \(reason)")
    }
}