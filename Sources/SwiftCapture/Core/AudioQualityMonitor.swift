import Foundation
import AVFoundation
import Accelerate

/// Audio quality metrics for monitoring and analysis
struct AudioMetrics {
    /// Peak level in dBFS (decibels relative to full scale)
    let peakLevel: Float
    
    /// RMS (Root Mean Square) level in dBFS
    let rmsLevel: Float
    
    /// Total Harmonic Distortion + Noise percentage (0.0 to 1.0)
    let thd: Float
    
    /// Dynamic range in dB
    let dynamicRange: Float
    
    /// Whether clipping was detected in this buffer
    let clippingDetected: Bool
    
    /// Frequency spectrum data (magnitude values for frequency bins)
    let frequencySpectrum: [Float]
    
    /// Timestamp when metrics were captured
    let timestamp: Date
    
    /// Initialize with default values
    init(
        peakLevel: Float = -Float.infinity,
        rmsLevel: Float = -Float.infinity,
        thd: Float = 0.0,
        dynamicRange: Float = 0.0,
        clippingDetected: Bool = false,
        frequencySpectrum: [Float] = [],
        timestamp: Date = Date()
    ) {
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
        self.thd = thd
        self.dynamicRange = dynamicRange
        self.clippingDetected = clippingDetected
        self.frequencySpectrum = frequencySpectrum
        self.timestamp = timestamp
    }
}

/// Protocol for audio quality monitoring callbacks
protocol AudioQualityMonitorDelegate: AnyObject {
    /// Called when audio quality metrics are updated
    /// - Parameter metrics: Current audio metrics
    func audioQualityUpdated(_ metrics: AudioMetrics)
    
    /// Called when audio quality issues are detected
    /// - Parameters:
    ///   - issue: Description of the quality issue
    ///   - severity: Severity level (0.0 = minor, 1.0 = critical)
    func audioQualityIssueDetected(_ issue: String, severity: Float)
    
    /// Called when clipping is detected
    /// - Parameter level: Peak level that caused clipping
    func clippingDetected(at level: Float)
    
    /// Called when quality degradation is detected and fallback is recommended
    /// - Parameters:
    ///   - originalMetrics: Quality metrics before processing
    ///   - processedMetrics: Quality metrics after processing
    ///   - recommendedAction: Suggested corrective action
    func qualityDegradationDetected(originalMetrics: AudioMetrics, processedMetrics: AudioMetrics, recommendedAction: QualityProtectionAction)
    
    /// Called when lossless mode should be activated
    /// - Parameter reason: Reason for activating lossless mode
    func losslessModeRecommended(reason: String)
}

/// Quality protection actions that can be recommended
enum QualityProtectionAction {
    case reduceGain(amount: Float)
    case disableCompression
    case enableLosslessMode
    case fallbackToOriginal
    case adjustCompressionRatio(newRatio: Float)
    case adjustLimiterThreshold(newThreshold: Float)
}

/// Monitors audio quality in real-time, detecting distortion, clipping, and other issues
class AudioQualityMonitor {
    
    // MARK: - Error Types
    
    enum QualityMonitorError: LocalizedError {
        case invalidBufferFormat
        case fftSetupFailed
        case processingFailed(String)
        case insufficientData
        
        var errorDescription: String? {
            switch self {
            case .invalidBufferFormat:
                return "Invalid audio buffer format for quality monitoring"
            case .fftSetupFailed:
                return "Failed to setup FFT for frequency analysis"
            case .processingFailed(let reason):
                return "Audio quality processing failed: \(reason)"
            case .insufficientData:
                return "Insufficient audio data for quality analysis"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Delegate for quality monitoring callbacks
    weak var delegate: AudioQualityMonitorDelegate?
    
    /// Whether quality monitoring is enabled
    var isEnabled: Bool = true
    
    /// Quality protection settings
    private let maxTHD: Float
    private let clippingThreshold: Float
    
    /// FFT setup for frequency analysis
    private var fftSetup: FFTSetup?
    private let fftSize: Int = 1024
    private var fftBuffer: [Float]
    private var magnitudeBuffer: [Float]
    
    /// Peak and RMS tracking
    private var peakHoldTime: TimeInterval = 1.0
    private var peakHistory: [(level: Float, timestamp: Date)] = []
    private var rmsHistory: [Float] = []
    private let historySize: Int = 100
    
    /// Clipping detection
    private var clippingCount: Int = 0
    private var totalSamples: Int = 0
    
    /// Quality metrics accumulation
    private var metricsUpdateInterval: TimeInterval = 0.1 // 100ms
    private var lastMetricsUpdate: Date = Date()
    
    /// Quality comparison and analysis
    private var originalAudioBuffer: [Float] = []
    private var processedAudioBuffer: [Float] = []
    private var qualityComparisonEnabled: Bool = false
    private var qualityDegradationThreshold: Float = 0.05 // 5% degradation threshold
    
    /// Lossless mode detection
    private var losslessModeActive: Bool = false
    private var qualityDegradationCount: Int = 0
    private var maxQualityDegradationCount: Int = 5
    
    /// Quality protection state
    private var protectionHistory: [QualityProtectionEvent] = []
    private let maxProtectionHistorySize: Int = 100
    
    // MARK: - Initialization
    
    /// Initialize audio quality monitor
    /// - Parameters:
    ///   - maxTHD: Maximum allowed THD+N (default: 0.001 = 0.1%)
    ///   - clippingThreshold: Clipping detection threshold in dBFS (default: -0.1)
    init(maxTHD: Float = 0.001, clippingThreshold: Float = -0.1) {
        self.maxTHD = maxTHD
        self.clippingThreshold = clippingThreshold
        self.fftBuffer = Array(repeating: 0.0, count: fftSize)
        self.magnitudeBuffer = Array(repeating: 0.0, count: fftSize / 2)
        
        setupFFT()
    }
    
    deinit {
        cleanupFFT()
    }
    
    // MARK: - Public Methods
    
    /// Process audio buffer and update quality metrics
    /// - Parameter buffer: Audio buffer to analyze
    /// - Throws: QualityMonitorError if processing fails
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard isEnabled else { return }
        
        // Validate buffer format
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            throw QualityMonitorError.invalidBufferFormat
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Process each channel (or mix to mono for analysis)
        var combinedSamples: [Float] = []
        
        if channelCount == 1 {
            // Mono audio
            let samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
            combinedSamples = samples
        } else {
            // Mix stereo/multi-channel to mono for analysis
            combinedSamples = Array(repeating: 0.0, count: frameCount)
            for frame in 0..<frameCount {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += floatChannelData[channel][frame]
                }
                combinedSamples[frame] = sum / Float(channelCount)
            }
        }
        
        // Calculate audio metrics
        let metrics = try calculateMetrics(from: combinedSamples, sampleRate: buffer.format.sampleRate)
        
        // Check for quality issues
        checkQualityIssues(metrics)
        
        // Update delegate if enough time has passed
        let now = Date()
        if now.timeIntervalSince(lastMetricsUpdate) >= metricsUpdateInterval {
            delegate?.audioQualityUpdated(metrics)
            lastMetricsUpdate = now
        }
    }
    
    /// Get current audio quality metrics
    /// - Returns: Latest audio metrics
    func getCurrentMetrics() -> AudioMetrics {
        let now = Date()
        
        // Calculate current peak from history
        let recentPeaks = peakHistory.filter { now.timeIntervalSince($0.timestamp) <= peakHoldTime }
        let currentPeak = recentPeaks.max(by: { $0.level < $1.level })?.level ?? -Float.infinity
        
        // Calculate average RMS from recent history
        let recentRMS = Array(rmsHistory.suffix(10))
        let avgRMS = recentRMS.isEmpty ? -Float.infinity : recentRMS.reduce(0, +) / Float(recentRMS.count)
        
        // Calculate dynamic range
        let dynamicRange = currentPeak - avgRMS
        
        // Calculate clipping percentage
        let clippingPercentage = totalSamples > 0 ? Float(clippingCount) / Float(totalSamples) : 0.0
        
        return AudioMetrics(
            peakLevel: currentPeak,
            rmsLevel: avgRMS,
            thd: 0.0, // Will be calculated in real processing
            dynamicRange: max(0, dynamicRange),
            clippingDetected: clippingPercentage > 0.001, // 0.1% threshold
            frequencySpectrum: magnitudeBuffer,
            timestamp: now
        )
    }
    
    /// Reset quality monitoring statistics
    func reset() {
        peakHistory.removeAll()
        rmsHistory.removeAll()
        clippingCount = 0
        totalSamples = 0
        lastMetricsUpdate = Date()
    }
    
    /// Configure quality monitoring parameters
    /// - Parameters:
    ///   - updateInterval: How often to send metrics updates (default: 0.1s)
    ///   - peakHoldTime: How long to hold peak values (default: 1.0s)
    func configure(updateInterval: TimeInterval = 0.1, peakHoldTime: TimeInterval = 1.0) {
        self.metricsUpdateInterval = updateInterval
        self.peakHoldTime = peakHoldTime
    }
    
    /// Enable quality comparison between original and processed audio
    /// - Parameter enabled: Whether to enable quality comparison
    func enableQualityComparison(_ enabled: Bool) {
        qualityComparisonEnabled = enabled
        if enabled {
            print("🔍 Audio quality comparison enabled")
        } else {
            originalAudioBuffer.removeAll()
            processedAudioBuffer.removeAll()
            print("🔍 Audio quality comparison disabled")
        }
    }
    
    /// Store original audio for quality comparison
    /// - Parameter samples: Original audio samples before processing
    func storeOriginalAudio(_ samples: [Float]) {
        guard qualityComparisonEnabled else { return }
        
        // Keep a rolling buffer of recent samples for comparison
        let maxBufferSize = 4096 // About 85ms at 48kHz
        originalAudioBuffer.append(contentsOf: samples)
        
        if originalAudioBuffer.count > maxBufferSize {
            originalAudioBuffer.removeFirst(originalAudioBuffer.count - maxBufferSize)
        }
    }
    
    /// Compare processed audio with original and detect quality degradation
    /// - Parameter processedSamples: Processed audio samples
    /// - Returns: Quality comparison result
    func compareAudioQuality(_ processedSamples: [Float]) -> AudioQualityComparison? {
        guard qualityComparisonEnabled,
              !originalAudioBuffer.isEmpty,
              processedSamples.count <= originalAudioBuffer.count else {
            return nil
        }
        
        // Store processed samples
        processedAudioBuffer.append(contentsOf: processedSamples)
        let maxBufferSize = 4096
        if processedAudioBuffer.count > maxBufferSize {
            processedAudioBuffer.removeFirst(processedAudioBuffer.count - maxBufferSize)
        }
        
        // Compare the most recent samples
        let compareLength = min(processedSamples.count, originalAudioBuffer.count)
        let originalSegment = Array(originalAudioBuffer.suffix(compareLength))
        let processedSegment = Array(processedSamples)
        
        return performQualityComparison(original: originalSegment, processed: processedSegment)
    }
    
    /// Enable or disable lossless mode
    /// - Parameter enabled: Whether to enable lossless mode
    func enableLosslessMode(_ enabled: Bool) {
        losslessModeActive = enabled
        if enabled {
            qualityDegradationCount = 0
            recordProtectionEvent(.losslessModeActivated, severity: 0.0, description: "Lossless mode activated")
            print("🔒 Lossless audio mode activated")
        } else {
            print("🔓 Lossless audio mode deactivated")
        }
    }
    
    /// Check if lossless mode is active
    var isLosslessModeActive: Bool {
        return losslessModeActive
    }
    
    /// Get quality protection history
    /// - Parameter limit: Maximum number of events to return (default: 50)
    /// - Returns: Array of recent quality protection events
    func getProtectionHistory(limit: Int = 50) -> [QualityProtectionEvent] {
        return Array(protectionHistory.suffix(limit))
    }
    
    /// Clear quality protection history
    func clearProtectionHistory() {
        protectionHistory.removeAll()
        qualityDegradationCount = 0
        print("🗑️ Quality protection history cleared")
    }
    
    // MARK: - Private Methods
    
    /// Setup FFT for frequency analysis
    private func setupFFT() {
        // Use a simpler FFT setup that's more compatible
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        
        if fftSetup == nil {
            print("⚠️ Failed to setup FFT for audio quality monitoring")
        }
    }
    
    /// Cleanup FFT resources
    private func cleanupFFT() {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }
    }
    
    /// Calculate comprehensive audio metrics from samples
    /// - Parameters:
    ///   - samples: Audio samples to analyze
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: Calculated audio metrics
    /// - Throws: QualityMonitorError if calculation fails
    private func calculateMetrics(from samples: [Float], sampleRate: Double) throws -> AudioMetrics {
        guard !samples.isEmpty else {
            throw QualityMonitorError.insufficientData
        }
        
        let frameCount = samples.count
        totalSamples += frameCount
        
        // Calculate peak level
        var peak: Float = 0.0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(frameCount))
        let peakdB = peak > 0 ? 20.0 * log10(peak) : -Float.infinity
        
        // Track peak history
        let now = Date()
        peakHistory.append((level: peakdB, timestamp: now))
        
        // Clean old peak history
        peakHistory = peakHistory.filter { now.timeIntervalSince($0.timestamp) <= peakHoldTime }
        
        // Calculate RMS level
        var rms: Float = 0.0
        var sumSquares: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(frameCount))
        rms = sqrt(sumSquares / Float(frameCount))
        let rmsdB = rms > 0 ? 20.0 * log10(rms) : -Float.infinity
        
        // Track RMS history
        rmsHistory.append(rmsdB)
        if rmsHistory.count > historySize {
            rmsHistory.removeFirst()
        }
        
        // Detect clipping
        let clippingThresholdLinear = pow(10.0, clippingThreshold / 20.0)
        let clippedSamples = samples.filter { abs($0) >= clippingThresholdLinear }.count
        clippingCount += clippedSamples
        let clippingDetected = clippedSamples > 0
        
        // Calculate frequency spectrum if FFT is available
        var spectrum: [Float] = []
        if let fftSetup = fftSetup, frameCount >= fftSize {
            spectrum = try calculateFrequencySpectrum(from: samples, setup: fftSetup)
        }
        
        // Estimate THD (simplified calculation)
        let thd = estimateTHD(from: spectrum, sampleRate: sampleRate)
        
        // Calculate dynamic range
        let dynamicRange = peakdB - rmsdB
        
        return AudioMetrics(
            peakLevel: peakdB,
            rmsLevel: rmsdB,
            thd: thd,
            dynamicRange: max(0, dynamicRange),
            clippingDetected: clippingDetected,
            frequencySpectrum: spectrum,
            timestamp: now
        )
    }
    
    /// Calculate frequency spectrum using FFT
    /// - Parameters:
    ///   - samples: Audio samples
    ///   - setup: FFT setup
    /// - Returns: Magnitude spectrum
    /// - Throws: QualityMonitorError if FFT fails
    private func calculateFrequencySpectrum(from samples: [Float], setup: FFTSetup) throws -> [Float] {
        let frameCount = min(samples.count, fftSize)
        
        // Copy samples to FFT buffer with zero padding
        fftBuffer = Array(repeating: 0.0, count: fftSize)
        for i in 0..<frameCount {
            fftBuffer[i] = samples[i]
        }
        
        // Apply window function (Hann window)
        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(fftBuffer, 1, window, 1, &fftBuffer, 1, vDSP_Length(fftSize))
        
        // Prepare complex buffer for FFT
        let halfSize = fftSize / 2
        var complexBuffer = DSPSplitComplex(
            realp: UnsafeMutablePointer<Float>.allocate(capacity: halfSize),
            imagp: UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
        )
        
        defer {
            complexBuffer.realp.deallocate()
            complexBuffer.imagp.deallocate()
        }
        
        // Convert real input to complex format
        fftBuffer.withUnsafeBufferPointer { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else { return }
            vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(baseAddress)), 2, &complexBuffer, 1, vDSP_Length(halfSize))
        }
        
        // Perform FFT
        vDSP_fft_zrip(setup, &complexBuffer, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(kFFTDirection_Forward))
        
        // Calculate magnitude spectrum
        magnitudeBuffer = Array(repeating: 0.0, count: halfSize)
        
        for i in 0..<halfSize {
            let magnitude = sqrt(complexBuffer.realp[i] * complexBuffer.realp[i] + complexBuffer.imagp[i] * complexBuffer.imagp[i])
            magnitudeBuffer[i] = magnitude > 0 ? 20.0 * log10(magnitude) : -Float.infinity
        }
        
        return magnitudeBuffer
    }
    
    /// Estimate Total Harmonic Distortion from frequency spectrum
    /// - Parameters:
    ///   - spectrum: Frequency spectrum
    ///   - sampleRate: Sample rate
    /// - Returns: Estimated THD percentage (0.0 to 1.0)
    private func estimateTHD(from spectrum: [Float], sampleRate: Double) -> Float {
        guard spectrum.count > 10 else { return 0.0 }
        
        // This is a simplified THD estimation
        // In a real implementation, you would need to identify fundamental frequency
        // and measure harmonic content relative to the fundamental
        
        let spectrumSize = spectrum.count
        let nyquist = Float(sampleRate / 2.0)
        let binWidth = nyquist / Float(spectrumSize)
        
        // Find the dominant frequency (fundamental)
        var maxBin = 0
        var maxMagnitude: Float = -Float.infinity
        
        // Look for fundamental in typical audio range (80Hz - 8kHz)
        let minBin = max(1, Int(80.0 / binWidth))
        let maxBin_search = min(spectrumSize - 1, Int(8000.0 / binWidth))
        
        for i in minBin..<maxBin_search {
            if spectrum[i] > maxMagnitude {
                maxMagnitude = spectrum[i]
                maxBin = i
            }
        }
        
        guard maxBin > 0 && maxMagnitude > -60.0 else { return 0.0 } // Too quiet to measure
        
        // Measure harmonic content (2nd, 3rd, 4th harmonics)
        var harmonicPower: Float = 0.0
        let fundamentalPower = pow(10.0, maxMagnitude / 10.0)
        
        for harmonic in 2...4 {
            let harmonicBin = maxBin * harmonic
            if harmonicBin < spectrumSize {
                let harmonicMagnitude = spectrum[harmonicBin]
                if harmonicMagnitude > -60.0 {
                    harmonicPower += pow(10.0, harmonicMagnitude / 10.0)
                }
            }
        }
        
        // Calculate THD as ratio of harmonic power to fundamental power
        let thd = fundamentalPower > 0 ? sqrt(harmonicPower / fundamentalPower) : 0.0
        return min(1.0, thd) // Clamp to maximum 100%
    }
    
    /// Check for audio quality issues and notify delegate
    /// - Parameter metrics: Current audio metrics
    private func checkQualityIssues(_ metrics: AudioMetrics) {
        // Check for clipping
        if metrics.clippingDetected {
            recordProtectionEvent(.clippingDetected, severity: 0.8, description: "Audio clipping at \(String(format: "%.1f", metrics.peakLevel)) dBFS")
            delegate?.clippingDetected(at: metrics.peakLevel)
            delegate?.audioQualityIssueDetected("Audio clipping detected at \(String(format: "%.1f", metrics.peakLevel)) dBFS", severity: 0.8)
        }
        
        // Check for excessive distortion
        if metrics.thd > maxTHD {
            let thdPercent = metrics.thd * 100.0
            let severity: Float = min(1.0, metrics.thd / maxTHD)
            recordProtectionEvent(.distortionDetected, severity: severity, description: "THD: \(String(format: "%.2f", thdPercent))%")
            
            delegate?.audioQualityIssueDetected("High distortion detected: \(String(format: "%.2f", thdPercent))% THD", severity: severity)
            
            // Recommend lossless mode if distortion is severe
            if metrics.thd > maxTHD * 2.0 && !losslessModeActive {
                delegate?.losslessModeRecommended(reason: "Excessive distortion detected (\(String(format: "%.2f", thdPercent))% THD)")
            }
        }
        
        // Check for very low levels (might indicate gain issues)
        if metrics.peakLevel < -40.0 && metrics.rmsLevel < -50.0 {
            delegate?.audioQualityIssueDetected("Very low audio levels detected", severity: 0.3)
        }
        
        // Check for very high levels (approaching clipping)
        if metrics.peakLevel > -3.0 {
            let severity = (metrics.peakLevel + 3.0) / 3.0 // 0.0 at -3dB, 1.0 at 0dB
            delegate?.audioQualityIssueDetected("Audio levels approaching clipping threshold", severity: severity)
            
            // Recommend gain reduction
            if metrics.peakLevel > -1.0 {
                let recommendedReduction = abs(metrics.peakLevel) + 3.0
                delegate?.qualityDegradationDetected(
                    originalMetrics: metrics,
                    processedMetrics: metrics,
                    recommendedAction: .reduceGain(amount: recommendedReduction)
                )
            }
        }
        
        // Check for poor dynamic range
        if metrics.dynamicRange < 6.0 && metrics.peakLevel > -20.0 {
            delegate?.audioQualityIssueDetected("Poor dynamic range detected", severity: 0.4)
            
            // Recommend disabling compression if dynamic range is too low
            if metrics.dynamicRange < 3.0 {
                delegate?.qualityDegradationDetected(
                    originalMetrics: metrics,
                    processedMetrics: metrics,
                    recommendedAction: .disableCompression
                )
            }
        }
        
        // Check for quality degradation pattern
        checkQualityDegradationPattern(metrics)
    }
    
    /// Perform detailed quality comparison between original and processed audio
    /// - Parameters:
    ///   - original: Original audio samples
    ///   - processed: Processed audio samples
    /// - Returns: Quality comparison result
    private func performQualityComparison(original: [Float], processed: [Float]) -> AudioQualityComparison {
        guard original.count == processed.count && !original.isEmpty else {
            return AudioQualityComparison(
                snr: 0.0,
                thd: 1.0,
                correlationCoefficient: 0.0,
                frequencyResponseDeviation: 1.0,
                qualityScore: 0.0,
                degradationDetected: true,
                recommendedAction: .fallbackToOriginal
            )
        }
        
        // Calculate Signal-to-Noise Ratio
        let snr = calculateSNR(original: original, processed: processed)
        
        // Calculate correlation coefficient
        let correlation = calculateCorrelation(original: original, processed: processed)
        
        // Estimate THD increase due to processing
        let thdIncrease = estimateTHDIncrease(original: original, processed: processed)
        
        // Calculate frequency response deviation (simplified)
        let freqDeviation = calculateFrequencyResponseDeviation(original: original, processed: processed)
        
        // Calculate overall quality score (0.0 = poor, 1.0 = excellent)
        let qualityScore = calculateQualityScore(snr: snr, correlation: correlation, thdIncrease: thdIncrease, freqDeviation: freqDeviation)
        
        // Determine if degradation is significant
        let degradationDetected = qualityScore < (1.0 - qualityDegradationThreshold)
        
        // Recommend action based on quality analysis
        let recommendedAction = determineRecommendedAction(qualityScore: qualityScore, snr: snr, thdIncrease: thdIncrease)
        
        let comparison = AudioQualityComparison(
            snr: snr,
            thd: thdIncrease,
            correlationCoefficient: correlation,
            frequencyResponseDeviation: freqDeviation,
            qualityScore: qualityScore,
            degradationDetected: degradationDetected,
            recommendedAction: recommendedAction
        )
        
        // Record quality degradation if detected
        if degradationDetected {
            qualityDegradationCount += 1
            recordProtectionEvent(.qualityDegradation, severity: 1.0 - qualityScore, description: "Quality score: \(String(format: "%.2f", qualityScore))")
            
            // Trigger lossless mode if degradation persists
            if qualityDegradationCount >= maxQualityDegradationCount && !losslessModeActive {
                delegate?.losslessModeRecommended(reason: "Persistent quality degradation detected")
            }
        } else {
            // Reset degradation count if quality is good
            if qualityDegradationCount > 0 {
                qualityDegradationCount = max(0, qualityDegradationCount - 1)
            }
        }
        
        return comparison
    }
    
    /// Calculate Signal-to-Noise Ratio between original and processed audio
    private func calculateSNR(original: [Float], processed: [Float]) -> Float {
        var signalPower: Float = 0.0
        var noisePower: Float = 0.0
        
        for i in 0..<original.count {
            let signal = original[i]
            let noise = processed[i] - original[i]
            signalPower += signal * signal
            noisePower += noise * noise
        }
        
        signalPower /= Float(original.count)
        noisePower /= Float(original.count)
        
        return noisePower > 0 ? 10.0 * log10(signalPower / noisePower) : 100.0
    }
    
    /// Calculate correlation coefficient between original and processed audio
    private func calculateCorrelation(original: [Float], processed: [Float]) -> Float {
        let n = Float(original.count)
        
        // Calculate means
        let meanOriginal = original.reduce(0, +) / n
        let meanProcessed = processed.reduce(0, +) / n
        
        // Calculate correlation coefficient
        var numerator: Float = 0.0
        var denomOriginal: Float = 0.0
        var denomProcessed: Float = 0.0
        
        for i in 0..<original.count {
            let diffOriginal = original[i] - meanOriginal
            let diffProcessed = processed[i] - meanProcessed
            
            numerator += diffOriginal * diffProcessed
            denomOriginal += diffOriginal * diffOriginal
            denomProcessed += diffProcessed * diffProcessed
        }
        
        let denominator = sqrt(denomOriginal * denomProcessed)
        return denominator > 0 ? numerator / denominator : 0.0
    }
    
    /// Estimate THD increase due to processing
    private func estimateTHDIncrease(original: [Float], processed: [Float]) -> Float {
        // Calculate RMS of the difference signal (distortion)
        var distortionPower: Float = 0.0
        var signalPower: Float = 0.0
        
        for i in 0..<original.count {
            let distortion = processed[i] - original[i]
            distortionPower += distortion * distortion
            signalPower += processed[i] * processed[i]
        }
        
        distortionPower /= Float(original.count)
        signalPower /= Float(original.count)
        
        return signalPower > 0 ? sqrt(distortionPower / signalPower) : 0.0
    }
    
    /// Calculate frequency response deviation (simplified)
    private func calculateFrequencyResponseDeviation(original: [Float], processed: [Float]) -> Float {
        // Simplified frequency response comparison using high-frequency content
        var originalHF: Float = 0.0
        var processedHF: Float = 0.0
        
        // Simple high-pass filter approximation
        for i in 1..<original.count {
            let originalDiff = original[i] - original[i-1]
            let processedDiff = processed[i] - processed[i-1]
            originalHF += originalDiff * originalDiff
            processedHF += processedDiff * processedDiff
        }
        
        originalHF = sqrt(originalHF / Float(original.count - 1))
        processedHF = sqrt(processedHF / Float(processed.count - 1))
        
        return originalHF > 0 ? abs(processedHF - originalHF) / originalHF : 0.0
    }
    
    /// Calculate overall quality score
    private func calculateQualityScore(snr: Float, correlation: Float, thdIncrease: Float, freqDeviation: Float) -> Float {
        // Weighted combination of quality metrics
        let snrScore = min(1.0, max(0.0, (snr - 20.0) / 40.0)) // 20-60 dB range
        let correlationScore = max(0.0, correlation)
        let thdScore = max(0.0, 1.0 - thdIncrease * 100.0) // THD as percentage
        let freqScore = max(0.0, 1.0 - freqDeviation)
        
        // Weighted average (correlation is most important for audio quality)
        return 0.4 * correlationScore + 0.3 * snrScore + 0.2 * thdScore + 0.1 * freqScore
    }
    
    /// Determine recommended action based on quality analysis
    private func determineRecommendedAction(qualityScore: Float, snr: Float, thdIncrease: Float) -> QualityProtectionAction {
        if qualityScore < 0.3 {
            return .fallbackToOriginal
        } else if qualityScore < 0.5 {
            return .enableLosslessMode
        } else if thdIncrease > 0.01 {
            return .adjustCompressionRatio(newRatio: 2.0)
        } else if snr < 30.0 {
            return .reduceGain(amount: 3.0)
        } else {
            return .adjustLimiterThreshold(newThreshold: -2.0)
        }
    }
    
    /// Check for quality degradation patterns
    private func checkQualityDegradationPattern(_ metrics: AudioMetrics) {
        // Look for patterns in recent protection events
        let recentEvents = protectionHistory.suffix(10)
        let distortionEvents = recentEvents.filter { $0.eventType == .distortionDetected }
        let clippingEvents = recentEvents.filter { $0.eventType == .clippingDetected }
        
        // If we have multiple distortion events in a short time, recommend lossless mode
        if distortionEvents.count >= 3 && !losslessModeActive {
            delegate?.losslessModeRecommended(reason: "Repeated distortion events detected")
        }
        
        // If we have multiple clipping events, recommend aggressive gain reduction
        if clippingEvents.count >= 2 {
            delegate?.qualityDegradationDetected(
                originalMetrics: metrics,
                processedMetrics: metrics,
                recommendedAction: .reduceGain(amount: 6.0)
            )
        }
    }
    
    /// Record a quality protection event
    private func recordProtectionEvent(_ eventType: QualityEventType, severity: Float, description: String, action: QualityProtectionAction? = nil) {
        let event = QualityProtectionEvent(
            timestamp: Date(),
            eventType: eventType,
            severity: severity,
            metrics: getCurrentMetrics(),
            action: action,
            description: description
        )
        
        protectionHistory.append(event)
        
        // Limit history size
        if protectionHistory.count > maxProtectionHistorySize {
            protectionHistory.removeFirst()
        }
    }
}

// MARK: - AudioQualityMonitor Extensions

extension AudioQualityMonitor {
    
    /// Get a formatted string representation of current metrics
    /// - Returns: Human-readable metrics string
    func getMetricsDescription() -> String {
        let metrics = getCurrentMetrics()
        
        let peakStr = metrics.peakLevel == -Float.infinity ? "Silent" : String(format: "%.1f dBFS", metrics.peakLevel)
        let rmsStr = metrics.rmsLevel == -Float.infinity ? "Silent" : String(format: "%.1f dBFS", metrics.rmsLevel)
        let thdStr = String(format: "%.3f%%", metrics.thd * 100.0)
        let dynamicStr = String(format: "%.1f dB", metrics.dynamicRange)
        let clippingStr = metrics.clippingDetected ? "⚠️ YES" : "✅ NO"
        
        return """
        🎵 Audio Quality Metrics:
           Peak: \(peakStr) | RMS: \(rmsStr)
           THD: \(thdStr) | Dynamic Range: \(dynamicStr)
           Clipping: \(clippingStr)
        """
    }
}

// MARK: - Quality Protection Types

/// Quality protection event for tracking quality issues
struct QualityProtectionEvent {
    let timestamp: Date
    let eventType: QualityEventType
    let severity: Float
    let metrics: AudioMetrics
    let action: QualityProtectionAction?
    let description: String
}

/// Types of quality protection events
enum QualityEventType {
    case distortionDetected
    case clippingDetected
    case qualityDegradation
    case losslessModeActivated
    case fallbackTriggered
    case qualityRestored
}

/// Audio quality comparison result
struct AudioQualityComparison {
    /// Signal-to-Noise Ratio in dB
    let snr: Float
    
    /// Total Harmonic Distortion increase due to processing
    let thd: Float
    
    /// Correlation coefficient between original and processed (0.0 to 1.0)
    let correlationCoefficient: Float
    
    /// Frequency response deviation (0.0 = no change, 1.0 = completely different)
    let frequencyResponseDeviation: Float
    
    /// Overall quality score (0.0 = poor, 1.0 = excellent)
    let qualityScore: Float
    
    /// Whether significant quality degradation was detected
    let degradationDetected: Bool
    
    /// Recommended action to improve quality
    let recommendedAction: QualityProtectionAction
}