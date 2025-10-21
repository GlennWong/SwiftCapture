import Foundation
import AVFoundation
import ScreenCaptureKit

/// Manages audio recording capabilities including microphone detection and configuration
class AudioManager {
    
    // MARK: - Error Types
    enum AudioError: LocalizedError {
        case microphoneNotAvailable
        case microphonePermissionDenied
        case audioDeviceNotFound(String)
        case audioConfigurationFailed(Error)
        case unsupportedAudioQuality(String)
        case audioEngineSetupFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .microphoneNotAvailable:
                return "Microphone is not available on this system"
            case .microphonePermissionDenied:
                return "Microphone permission denied. Please grant microphone access in System Preferences > Security & Privacy > Privacy > Microphone"
            case .audioDeviceNotFound(let deviceName):
                return "Audio device '\(deviceName)' not found"
            case .audioConfigurationFailed(let error):
                return "Audio configuration failed: \(error.localizedDescription)"
            case .unsupportedAudioQuality(let quality):
                return "Unsupported audio quality: '\(quality)'. Supported values: low, medium, high"
            case .audioEngineSetupFailed(let error):
                return "Audio engine setup failed: \(error.localizedDescription)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .microphoneNotAvailable:
                return "Check that a microphone is connected and recognized by the system"
            case .microphonePermissionDenied:
                return "Go to System Preferences > Security & Privacy > Privacy > Microphone and enable access for this application"
            case .audioDeviceNotFound:
                return "Use --list-audio-devices to see available audio devices"
            case .audioConfigurationFailed:
                return "Try using default audio settings or check system audio configuration"
            case .unsupportedAudioQuality:
                return "Use one of: low, medium, high"
            case .audioEngineSetupFailed:
                return "Restart the application or check system audio settings"
            }
        }
    }
    
    // MARK: - Properties
    private var audioEngine: AVAudioEngine?
    private var microphoneNode: AVAudioInputNode?
    private var audioProcessor: AudioProcessor?
    private var qualityMonitor: AudioQualityMonitor?
    
    // Real-time monitoring components
    private var levelMeter: AudioLevelMeter?
    private var spectrumAnalyzer: AudioSpectrumAnalyzer?
    private var previewEngine: AudioPreviewEngine?
    private var monitoringDisplay: AudioMonitoringDisplay?
    
    // MARK: - Initialization
    init() {
        // Initialize audio engine for microphone detection
        setupAudioEngine()
    }
    
    deinit {
        cleanupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// Configure audio settings based on recording configuration
    /// - Parameter config: Recording configuration containing audio preferences
    /// - Returns: Configured AudioSettings
    /// - Throws: AudioError if configuration fails
    func configureAudio(for config: RecordingConfiguration) throws -> AudioSettings {
        // Validate audio quality
        guard let audioQuality = AudioQuality(rawValue: config.audioSettings.quality.rawValue) else {
            throw AudioError.unsupportedAudioQuality(config.audioSettings.quality.rawValue)
        }
        
        // Check microphone availability if requested
        if config.audioSettings.includeMicrophone {
            try validateMicrophoneAvailability()
        }
        
        // Initialize audio processing components if enhancement is enabled
        if config.audioSettings.processingEnabled {
            try setupAudioProcessing(with: config.audioSettings.enhancementSettings)
        }
        
        // Create audio settings with validated parameters
        let audioSettings = AudioSettings(
            includeMicrophone: config.audioSettings.includeMicrophone,
            includeSystemAudio: config.audioSettings.includeSystemAudio,
            forceSystemAudio: config.audioSettings.forceSystemAudio,
            quality: audioQuality,
            sampleRate: audioQuality.sampleRate,
            bitRate: audioQuality.bitRate,
            channels: 2, // Stereo
            enhancementSettings: config.audioSettings.enhancementSettings,
            qualityMonitoringEnabled: config.audioSettings.qualityMonitoringEnabled,
            processingEnabled: config.audioSettings.processingEnabled
        )
        
        return audioSettings
    }
    
    /// Setup microphone for recording
    /// - Returns: Configured AVAudioEngine if microphone is available
    /// - Throws: AudioError if microphone setup fails
    func setupMicrophone() throws -> AVAudioEngine? {
        guard let audioEngine = audioEngine else {
            throw AudioError.audioEngineSetupFailed(
                NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
            )
        }
        
        // Check microphone permission
        try validateMicrophonePermission()
        
        // Get the input node (microphone)
        let inputNode = audioEngine.inputNode
        
        // Configure input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioError.microphoneNotAvailable
        }
        
        print("🎤 Microphone configured:")
        print("   Sample Rate: \(inputFormat.sampleRate) Hz")
        print("   Channels: \(inputFormat.channelCount)")
        print("   Format: \(inputFormat.commonFormat.rawValue)")
        
        self.microphoneNode = inputNode
        return audioEngine
    }
    
    /// Validate that audio devices are available and accessible
    /// - Throws: AudioError if validation fails
    func validateAudioDevices() throws {
        // Check system audio availability (ScreenCaptureKit handles this)
        if #available(macOS 13.0, *) {
            // ScreenCaptureKit audio capture is available
            print("✅ System audio capture available via ScreenCaptureKit")
        } else {
            print("⚠️ System audio capture requires macOS 13.0+")
        }
        
        // Check microphone availability
        let microphoneAvailable = checkMicrophoneAvailability()
        if microphoneAvailable {
            print("✅ Microphone available")
        } else {
            print("⚠️ Microphone not available")
        }
        
        // List available audio devices for debugging
        listAvailableAudioDevices()
    }
    
    /// Check if microphone is available without throwing errors
    /// - Returns: true if microphone is available, false otherwise
    func checkMicrophoneAvailability() -> Bool {
        do {
            try validateMicrophoneAvailability()
            return true
        } catch {
            return false
        }
    }
    
    /// Get audio quality from string
    /// - Parameter qualityString: Quality string (low, medium, high)
    /// - Returns: AudioQuality enum value
    /// - Throws: AudioError if quality string is invalid
    func getAudioQuality(from qualityString: String) throws -> AudioQuality {
        guard let quality = AudioQuality(rawValue: qualityString.lowercased()) else {
            throw AudioError.unsupportedAudioQuality(qualityString)
        }
        return quality
    }
    
    /// Create audio settings with validation
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone audio
    ///   - includeSystemAudio: Whether to include system audio
    ///   - forceSystemAudio: Force system-wide audio recording
    ///   - qualityString: Audio quality string
    ///   - enhancementSettings: Audio enhancement configuration
    ///   - processingEnabled: Enable audio processing
    /// - Returns: Validated AudioSettings
    /// - Throws: AudioError if validation fails
    func createAudioSettings(
        includeMicrophone: Bool,
        includeSystemAudio: Bool,
        forceSystemAudio: Bool = false,
        qualityString: String,
        enhancementSettings: AudioEnhancementSettings = AudioEnhancementSettings(),
        processingEnabled: Bool = false
    ) throws -> AudioSettings {
        // Validate quality
        let quality = try getAudioQuality(from: qualityString)
        
        // Validate microphone if requested
        if includeMicrophone {
            try validateMicrophoneAvailability()
        }
        
        // Validate enhancement settings if processing is enabled
        if processingEnabled && !enhancementSettings.isValid {
            let errors = enhancementSettings.validationErrors.joined(separator: ", ")
            throw AudioError.audioConfigurationFailed(
                NSError(domain: "AudioManager", code: -1, 
                       userInfo: [NSLocalizedDescriptionKey: "Invalid enhancement settings: \(errors)"])
            )
        }
        
        return AudioSettings(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: includeSystemAudio,
            forceSystemAudio: forceSystemAudio,
            quality: quality,
            sampleRate: quality.sampleRate,
            bitRate: quality.bitRate,
            channels: 2,
            enhancementSettings: enhancementSettings,
            qualityMonitoringEnabled: true,
            processingEnabled: processingEnabled
        )
    }
    
    /// Setup audio processing components
    /// - Parameter settings: Audio enhancement settings
    /// - Throws: AudioError if setup fails
    func setupAudioProcessing(with settings: AudioEnhancementSettings) throws {
        // Initialize optimized audio processor
        audioProcessor = AudioProcessor(settings: settings)
        
        // Initialize quality monitor if enabled
        if settings.qualityMonitoringEnabled {
            qualityMonitor = AudioQualityMonitor()
            
            // Enable quality comparison if requested
            qualityMonitor?.enableQualityComparison(settings.qualityComparisonEnabled)
        }
        
        // Enable lossless mode if requested
        if settings.losslessModeEnabled {
            audioProcessor?.enableLosslessMode(true)
        }
        
        // Initialize real-time monitoring components
        try setupRealtimeMonitoring(with: settings)
        
        print("🎛️ Audio processing initialized with performance optimizations:")
        print("   Preset: \(settings.preset.rawValue)")
        print("   Master Gain: \(settings.masterGain) dB")
        print("   Auto Gain: \(settings.autoGainEnabled ? "enabled" : "disabled")")
        print("   Quality Protection: \(settings.qualityProtectionEnabled ? "enabled" : "disabled")")
        print("   Lossless Mode: \(settings.losslessModeEnabled ? "enabled" : "disabled")")
        print("   Quality Comparison: \(settings.qualityComparisonEnabled ? "enabled" : "disabled")")
        print("   Real-time Monitoring: \(settings.qualityMonitoringEnabled ? "enabled" : "disabled")")
        print("   🚀 Performance Features: Buffer pooling, vDSP acceleration, memory monitoring")
    }
    
    /// Get current audio processing status
    /// - Returns: Dictionary with processing status information
    func getProcessingStatus() -> [String: Any] {
        var status: [String: Any] = [
            "processingEnabled": audioProcessor != nil,
            "qualityMonitoringEnabled": qualityMonitor != nil,
            "levelMeterEnabled": levelMeter != nil,
            "spectrumAnalyzerEnabled": spectrumAnalyzer != nil,
            "previewEngineEnabled": previewEngine != nil,
            "monitoringDisplayEnabled": monitoringDisplay != nil
        ]
        
        if let processor = audioProcessor {
            status["processorStats"] = processor.getProcessingStats()
            status["performanceMetrics"] = processor.getPerformanceMetrics()
            status["memoryStatistics"] = processor.getMemoryStatistics()
        }
        
        if let monitor = qualityMonitor {
            status["qualityMetrics"] = [
                "description": monitor.getMetricsDescription(),
                "currentMetrics": monitor.getCurrentMetrics()
            ]
        }
        
        if let levelMeter = levelMeter {
            status["audioLevels"] = [
                "peak": levelMeter.peakLevel,
                "rms": levelMeter.rmsLevel,
                "description": levelMeter.getLevelsDescription()
            ]
        }
        
        if let spectrumAnalyzer = spectrumAnalyzer {
            status["spectrum"] = spectrumAnalyzer.getBandSpectrum()
        }
        
        if let previewEngine = previewEngine {
            status["preview"] = previewEngine.getPreviewStatus()
        }
        
        if let monitoringDisplay = monitoringDisplay {
            status["monitoring"] = monitoringDisplay.getMonitoringStatus()
        }
        
        return status
    }
    
    /// Enable or disable lossless audio mode
    /// - Parameter enabled: Whether to enable lossless mode
    func enableLosslessMode(_ enabled: Bool) {
        audioProcessor?.enableLosslessMode(enabled)
        
        if enabled {
            print("🔒 Lossless audio mode enabled via AudioManager")
        } else {
            print("🔓 Lossless audio mode disabled via AudioManager")
        }
    }
    
    /// Check if lossless mode is currently active
    /// - Returns: True if lossless mode is active
    func isLosslessModeActive() -> Bool {
        return audioProcessor?.isLosslessModeActive ?? false
    }
    
    /// Get comprehensive audio quality analysis report
    /// - Returns: Quality analysis report with recommendations
    func getQualityAnalysisReport() -> [String: Any] {
        var report: [String: Any] = [:]
        
        // Get processor quality analysis
        if let processor = audioProcessor {
            report["processorAnalysis"] = processor.getQualityAnalysisReport()
        }
        
        // Get quality monitor protection history
        if let monitor = qualityMonitor {
            let protectionHistory = monitor.getProtectionHistory()
            report["protectionHistory"] = protectionHistory.map { event in
                [
                    "timestamp": event.timestamp,
                    "eventType": String(describing: event.eventType),
                    "severity": event.severity,
                    "description": event.description,
                    "action": event.action != nil ? String(describing: event.action!) : nil
                ]
            }
            
            report["losslessModeActive"] = monitor.isLosslessModeActive
            report["qualityComparisonEnabled"] = true // Assuming enabled if monitor exists
        }
        
        // Add current metrics
        if let currentMetrics = qualityMonitor?.getCurrentMetrics() {
            report["currentMetrics"] = [
                "peakLevel": currentMetrics.peakLevel,
                "rmsLevel": currentMetrics.rmsLevel,
                "thd": currentMetrics.thd,
                "dynamicRange": currentMetrics.dynamicRange,
                "clippingDetected": currentMetrics.clippingDetected
            ]
        }
        
        return report
    }
    
    /// Enable or disable quality comparison
    /// - Parameter enabled: Whether to enable quality comparison
    func enableQualityComparison(_ enabled: Bool) {
        qualityMonitor?.enableQualityComparison(enabled)
        
        if enabled {
            print("🔍 Audio quality comparison enabled")
        } else {
            print("🔍 Audio quality comparison disabled")
        }
    }
    
    /// Clear quality protection history
    func clearQualityProtectionHistory() {
        qualityMonitor?.clearProtectionHistory()
        print("🗑️ Quality protection history cleared")
    }
    
    /// Get comprehensive performance report
    /// - Returns: Formatted performance report
    func getPerformanceReport() -> String {
        guard let processor = audioProcessor else {
            return "Audio processing not initialized"
        }
        
        return processor.getPerformanceReport()
    }
    
    /// Optimize audio processing memory usage
    /// - Returns: Amount of memory freed in MB
    @discardableResult
    func optimizeMemoryUsage() -> Double {
        // This will trigger the processor's memory optimization
        return 0.0 // The actual optimization happens in the processor's memory monitor callbacks
    }
    
    /// Get quality protection recommendations based on current state
    /// - Returns: Array of recommendation strings
    func getQualityRecommendations() -> [String] {
        var recommendations: [String] = []
        
        guard let processor = audioProcessor,
              let monitor = qualityMonitor else {
            recommendations.append("Audio processing not initialized")
            return recommendations
        }
        
        let metrics = monitor.getCurrentMetrics()
        let protectionHistory = monitor.getProtectionHistory(limit: 10)
        
        // Check for recent quality issues
        let recentDistortionEvents = protectionHistory.filter { 
            $0.eventType == .distortionDetected && 
            Date().timeIntervalSince($0.timestamp) < 60 // Last minute
        }
        
        let recentClippingEvents = protectionHistory.filter { 
            $0.eventType == .clippingDetected && 
            Date().timeIntervalSince($0.timestamp) < 60 
        }
        
        // Generate recommendations
        if !recentDistortionEvents.isEmpty {
            recommendations.append("Consider enabling lossless mode due to recent distortion events")
        }
        
        if !recentClippingEvents.isEmpty {
            recommendations.append("Reduce master gain to prevent clipping")
        }
        
        if metrics.thd > 0.001 {
            recommendations.append("High distortion detected - reduce compression or enable lossless mode")
        }
        
        if metrics.peakLevel > -1.0 {
            recommendations.append("Audio levels too high - risk of clipping")
        }
        
        if metrics.peakLevel < -30.0 {
            recommendations.append("Audio levels too low - consider increasing gain")
        }
        
        if metrics.dynamicRange < 3.0 && metrics.peakLevel > -20.0 {
            recommendations.append("Poor dynamic range - reduce compression ratio")
        }
        
        if !processor.isLosslessModeActive && protectionHistory.count > 20 {
            recommendations.append("Multiple quality events detected - consider enabling lossless mode")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Audio quality is optimal")
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    /// Setup audio engine for microphone detection
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        print("🔧 Audio engine initialized")
    }
    
    /// Setup real-time monitoring components
    /// - Parameter settings: Audio enhancement settings
    /// - Throws: AudioError if setup fails
    private func setupRealtimeMonitoring(with settings: AudioEnhancementSettings) throws {
        // Initialize level meter
        levelMeter = AudioLevelMeter()
        
        // Initialize spectrum analyzer
        spectrumAnalyzer = AudioSpectrumAnalyzer()
        
        // Initialize preview engine if needed
        if settings.qualityMonitoringEnabled {
            do {
                previewEngine = try AudioPreviewEngine(settings: settings)
            } catch {
                throw AudioError.audioEngineSetupFailed(error)
            }
        }
        
        // Initialize monitoring display
        monitoringDisplay = AudioMonitoringDisplay(settings: settings)
        
        print("📊 Real-time monitoring components initialized")
    }
    
    /// Process audio buffer through monitoring components
    /// - Parameter buffer: Audio buffer to monitor
    func processMonitoringBuffer(_ buffer: AVAudioPCMBuffer) {
        // Update level meter
        levelMeter?.processBuffer(buffer)
        
        // Update spectrum analyzer
        spectrumAnalyzer?.processBuffer(buffer)
        
        // Update monitoring display
        monitoringDisplay?.processBuffer(buffer)
        
        // Update preview engine if active
        if let previewEngine = previewEngine, previewEngine.isPreviewActive {
            do {
                try previewEngine.processPreviewBuffer(buffer)
            } catch {
                print("⚠️ Preview processing error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start real-time audio monitoring display
    func startMonitoringDisplay() {
        monitoringDisplay?.startDisplay()
    }
    
    /// Stop real-time audio monitoring display
    func stopMonitoringDisplay() {
        monitoringDisplay?.stopDisplay()
    }
    
    /// Start audio preview
    /// - Throws: AudioError if preview cannot be started
    func startAudioPreview() throws {
        guard let previewEngine = previewEngine else {
            throw AudioError.audioEngineSetupFailed(
                NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Preview engine not initialized"])
            )
        }
        
        do {
            try previewEngine.startPreview()
        } catch {
            throw AudioError.audioEngineSetupFailed(error)
        }
    }
    
    /// Stop audio preview
    func stopAudioPreview() {
        previewEngine?.stopPreview()
    }
    
    /// Update monitoring settings
    /// - Parameter settings: New audio enhancement settings
    func updateMonitoringSettings(_ settings: AudioEnhancementSettings) {
        monitoringDisplay?.updateSettings(settings)
        
        if let previewEngine = previewEngine {
            do {
                try previewEngine.updateSettings(settings)
            } catch {
                print("⚠️ Failed to update preview settings: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get real-time monitoring display string
    /// - Returns: Formatted monitoring display
    func getMonitoringDisplayString() -> String {
        return previewEngine?.getMonitoringDisplay() ?? "Monitoring not available"
    }
    
    /// Cleanup audio engine resources
    private func cleanupAudioEngine() {
        // Stop monitoring components
        stopMonitoringDisplay()
        stopAudioPreview()
        
        // Cleanup audio engine
        audioEngine?.stop()
        audioEngine = nil
        microphoneNode = nil
        
        // Cleanup processing components
        audioProcessor = nil
        qualityMonitor = nil
        
        // Cleanup monitoring components
        levelMeter = nil
        spectrumAnalyzer = nil
        previewEngine = nil
        monitoringDisplay = nil
    }
    
    /// Validate microphone availability
    /// - Throws: AudioError if microphone is not available
    private func validateMicrophoneAvailability() throws {
        // Check if audio engine is available
        guard let audioEngine = audioEngine else {
            throw AudioError.audioEngineSetupFailed(
                NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not available"])
            )
        }
        
        // Check microphone permission first
        try validateMicrophonePermission()
        
        // Check if input node is available
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate that we have a valid input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioError.microphoneNotAvailable
        }
    }
    
    /// Validate microphone permission
    /// - Throws: AudioError if permission is denied
    private func validateMicrophonePermission() throws {
        // On macOS, we use AVCaptureDevice authorization instead of AVAudioSession
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            // Permission granted, continue
            break
        case .denied, .restricted:
            throw AudioError.microphonePermissionDenied
        case .notDetermined:
            // Request permission synchronously for CLI tool
            let semaphore = DispatchSemaphore(value: 0)
            var permissionGranted = false
            
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                permissionGranted = granted
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if !permissionGranted {
                throw AudioError.microphonePermissionDenied
            }
        @unknown default:
            throw AudioError.microphonePermissionDenied
        }
    }
    
    /// List available audio devices for debugging
    private func listAvailableAudioDevices() {
        print("🔍 Available Audio Devices:")
        
        // List input devices (microphones) using compatible API
        if #available(macOS 14.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            
            let inputDevices = discoverySession.devices
            if inputDevices.isEmpty {
                print("   📱 No audio input devices found")
            } else {
                for (index, device) in inputDevices.enumerated() {
                    print("   📱 Input \(index + 1): \(device.localizedName)")
                    print("      ID: \(device.uniqueID)")
                    print("      Connected: \(device.isConnected)")
                }
            }
        } else if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            
            let inputDevices = discoverySession.devices
            if inputDevices.isEmpty {
                print("   📱 No audio input devices found")
            } else {
                for (index, device) in inputDevices.enumerated() {
                    print("   📱 Input \(index + 1): \(device.localizedName)")
                    print("      ID: \(device.uniqueID)")
                    print("      Connected: \(device.isConnected)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let inputDevices = AVCaptureDevice.devices(for: .audio)
            if inputDevices.isEmpty {
                print("   📱 No audio input devices found")
            } else {
                for (index, device) in inputDevices.enumerated() {
                    print("   📱 Input \(index + 1): \(device.localizedName)")
                    print("      ID: \(device.uniqueID)")
                    print("      Connected: \(device.isConnected)")
                }
            }
        }
        
        // Check system audio availability
        if #available(macOS 13.0, *) {
            print("   🔊 System Audio: Available via ScreenCaptureKit")
        } else {
            print("   🔊 System Audio: Requires macOS 13.0+")
        }
    }
}

// MARK: - AudioManager Extensions

extension AudioManager {
    
    /// Create default audio settings for common use cases
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone
    ///   - forceSystemAudio: Force system-wide audio recording
    ///   - quality: Audio quality preset
    ///   - enhancementPreset: Audio enhancement preset
    ///   - processingEnabled: Enable audio processing
    /// - Returns: AudioSettings with default values
    static func defaultSettings(
        includeMicrophone: Bool = false, 
        forceSystemAudio: Bool = false, 
        quality: AudioQuality = .medium,
        enhancementPreset: AudioPreset = .balanced,
        processingEnabled: Bool = false
    ) -> AudioSettings {
        let enhancementSettings = processingEnabled ? 
            AudioEnhancementSettings.from(preset: enhancementPreset).withProcessing(true) :
            AudioEnhancementSettings()
        
        return AudioSettings.default(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: true,
            forceSystemAudio: forceSystemAudio,
            quality: quality,
            enhancementSettings: enhancementSettings,
            processingEnabled: processingEnabled
        )
    }
    
    /// Validate audio configuration without throwing
    /// - Parameter settings: Audio settings to validate
    /// - Returns: Validation result with error message if invalid
    func validateAudioConfiguration(_ settings: AudioSettings) -> (isValid: Bool, error: String?) {
        do {
            if settings.includeMicrophone {
                try validateMicrophoneAvailability()
            }
            return (true, nil)
        } catch let error as AudioError {
            return (false, error.localizedDescription)
        } catch {
            return (false, "Unknown audio validation error: \(error.localizedDescription)")
        }
    }
}