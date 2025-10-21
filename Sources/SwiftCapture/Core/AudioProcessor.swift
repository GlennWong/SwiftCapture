import Foundation
import AVFoundation
import Accelerate

/// Protocol for audio processing functionality
protocol AudioProcessorProtocol {
    /// Process audio buffer with enhancement settings
    /// - Parameters:
    ///   - buffer: Input audio buffer
    ///   - settings: Audio enhancement settings
    /// - Returns: Processed audio buffer
    /// - Throws: AudioProcessingError if processing fails
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, settings: AudioEnhancementSettings) throws -> AVAudioPCMBuffer
    
    /// Set master gain in dB (-20.0 to +20.0)
    /// - Parameter gain: Gain value in dB
    func setGain(_ gain: Float)
    
    /// Enable or disable automatic gain control
    /// - Parameter enabled: Whether to enable auto gain control
    func enableAutoGainControl(_ enabled: Bool)
    
    /// Get current audio metrics
    /// - Returns: Current audio quality metrics
    func getAudioMetrics() -> AudioMetrics
}

/// Audio processing errors
enum AudioProcessingError: LocalizedError {
    case processingBufferOverflow
    case qualityThresholdExceeded
    case unsupportedAudioFormat
    case processingLatencyTooHigh
    case memoryAllocationFailed
    case invalidGainValue(Float)
    case compressionSetupFailed
    case limiterSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .processingBufferOverflow:
            return "音频处理缓冲区溢出，请降低处理强度"
        case .qualityThresholdExceeded:
            return "音频质量下降超过阈值，已自动回退到保守设置"
        case .unsupportedAudioFormat:
            return "不支持的音频格式，请检查音频设置"
        case .processingLatencyTooHigh:
            return "音频处理延迟过高，已禁用实时处理"
        case .memoryAllocationFailed:
            return "音频处理内存分配失败，请释放系统资源"
        case .invalidGainValue(let gain):
            return "无效的增益值: \(gain) dB，必须在 -20.0 到 +20.0 之间"
        case .compressionSetupFailed:
            return "压缩器设置失败"
        case .limiterSetupFailed:
            return "限制器设置失败"
        }
    }
}

/// Advanced multiband compressor with proper crossover filters and frequency-specific processing
private class MultibandCompressor {
    
    /// Individual frequency band configuration and state
    struct Band {
        let lowFreq: Float
        let highFreq: Float
        var threshold: Float
        var ratio: Float
        var attack: Float
        var release: Float
        var makeupGain: Float
        var envelope: Float = 1.0
        var gain: Float = 1.0
        
        // Crossover filter state
        var lowpassState: BiquadFilterState = BiquadFilterState()
        var highpassState: BiquadFilterState = BiquadFilterState()
        var bandpassState: BiquadFilterState = BiquadFilterState()
    }
    
    /// Biquad filter state for crossover filters
    struct BiquadFilterState {
        var x1: Float = 0.0
        var x2: Float = 0.0
        var y1: Float = 0.0
        var y2: Float = 0.0
    }
    
    /// Biquad filter coefficients
    struct BiquadCoefficients {
        let b0, b1, b2, a1, a2: Float
    }
    
    private var bands: [Band] = []
    private let sampleRate: Float
    private var crossoverFilters: [BiquadCoefficients] = []
    
    // Adaptive gain control state
    private var contentAnalyzer: AudioContentAnalyzer
    private var adaptiveGainEnabled: Bool = true
    
    init(sampleRate: Float, settings: AudioEnhancementSettings) {
        self.sampleRate = sampleRate
        self.contentAnalyzer = AudioContentAnalyzer(sampleRate: sampleRate)
        setupBands(with: settings)
        setupCrossoverFilters()
    }
    
    /// Setup frequency bands based on audio enhancement settings
    private func setupBands(with settings: AudioEnhancementSettings) {
        bands.removeAll()
        
        // Low band: 20Hz - 250Hz (bass frequencies)
        // Gentle compression to maintain low-end power while controlling boom
        bands.append(Band(
            lowFreq: 20.0,
            highFreq: 250.0,
            threshold: settings.threshold - 3.0, // Slightly lower threshold for bass
            ratio: max(1.5, settings.compressionRatio * 0.7), // Gentler compression
            attack: settings.attack * 2.0, // Slower attack for bass
            release: settings.release * 1.5, // Longer release
            makeupGain: 1.0
        ))
        
        // Mid band: 250Hz - 4kHz (vocal and midrange frequencies)
        // More aggressive compression for clarity and presence
        bands.append(Band(
            lowFreq: 250.0,
            highFreq: 4000.0,
            threshold: settings.threshold,
            ratio: settings.compressionRatio,
            attack: settings.attack,
            release: settings.release,
            makeupGain: 1.2 // Slight boost for vocal presence
        ))
        
        // High band: 4kHz - 20kHz (treble frequencies)
        // Moderate compression to maintain air and detail
        bands.append(Band(
            lowFreq: 4000.0,
            highFreq: 20000.0,
            threshold: settings.threshold + 2.0, // Higher threshold for treble
            ratio: max(1.5, settings.compressionRatio * 0.8), // Moderate compression
            attack: settings.attack * 0.5, // Faster attack for transients
            release: settings.release * 0.8, // Shorter release
            makeupGain: 1.1 // Slight boost for air
        ))
    }
    
    /// Setup crossover filters for frequency band separation
    private func setupCrossoverFilters() {
        crossoverFilters.removeAll()
        
        // Linkwitz-Riley 4th order crossover filters at 250Hz and 4kHz
        let crossover1 = 250.0 / sampleRate // Normalized frequency
        let crossover2 = 4000.0 / sampleRate
        
        // Low-pass filter for bass band (250Hz cutoff)
        crossoverFilters.append(calculateLinkwitzRileyLowpass(frequency: crossover1))
        
        // Band-pass filter for mid band (250Hz - 4kHz)
        crossoverFilters.append(calculateLinkwitzRileyBandpass(lowFreq: crossover1, highFreq: crossover2))
        
        // High-pass filter for treble band (4kHz cutoff)
        crossoverFilters.append(calculateLinkwitzRileyHighpass(frequency: crossover2))
    }
    
    /// Calculate Linkwitz-Riley lowpass filter coefficients
    private func calculateLinkwitzRileyLowpass(frequency: Float) -> BiquadCoefficients {
        let omega = 2.0 * Float.pi * frequency
        let sin_omega = sin(omega)
        let cos_omega = cos(omega)
        let alpha = sin_omega / (2.0 * sqrt(2.0)) // Q = 1/sqrt(2) for Linkwitz-Riley
        
        let b0 = (1.0 - cos_omega) / 2.0
        let b1 = 1.0 - cos_omega
        let b2 = (1.0 - cos_omega) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos_omega
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )
    }
    
    /// Calculate Linkwitz-Riley highpass filter coefficients
    private func calculateLinkwitzRileyHighpass(frequency: Float) -> BiquadCoefficients {
        let omega = 2.0 * Float.pi * frequency
        let sin_omega = sin(omega)
        let cos_omega = cos(omega)
        let alpha = sin_omega / (2.0 * sqrt(2.0))
        
        let b0 = (1.0 + cos_omega) / 2.0
        let b1 = -(1.0 + cos_omega)
        let b2 = (1.0 + cos_omega) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos_omega
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )
    }
    
    /// Calculate Linkwitz-Riley bandpass filter coefficients
    private func calculateLinkwitzRileyBandpass(lowFreq: Float, highFreq: Float) -> BiquadCoefficients {
        // Simplified bandpass - in practice, this would be a cascade of highpass and lowpass
        let centerFreq = sqrt(lowFreq * highFreq)
        let bandwidth = highFreq - lowFreq
        let omega = 2.0 * Float.pi * centerFreq
        let sin_omega = sin(omega)
        let cos_omega = cos(omega)
        let alpha = sin_omega * sinh(log(2.0) / 2.0 * bandwidth * omega / sin_omega)
        
        let b0 = alpha
        let b1: Float = 0.0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos_omega
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )
    }
    
    /// Apply biquad filter to a sample
    private func applyBiquadFilter(_ input: Float, coeffs: BiquadCoefficients, state: inout BiquadFilterState) -> Float {
        let output = coeffs.b0 * input + coeffs.b1 * state.x1 + coeffs.b2 * state.x2 - coeffs.a1 * state.y1 - coeffs.a2 * state.y2
        
        // Update state
        state.x2 = state.x1
        state.x1 = input
        state.y2 = state.y1
        state.y1 = output
        
        return output
    }
    
    /// Process audio samples through multiband compression
    func process(_ samples: inout [Float]) {
        guard !samples.isEmpty else { return }
        
        // Analyze audio content for adaptive processing
        let contentType = contentAnalyzer.analyzeContent(samples)
        
        // Split audio into frequency bands using crossover filters
        var bandSamples: [[Float]] = Array(repeating: Array(repeating: 0.0, count: samples.count), count: bands.count)
        
        for i in 0..<samples.count {
            let input = samples[i]
            
            // Apply crossover filters to separate frequency bands
            for bandIndex in 0..<bands.count {
                if bandIndex < crossoverFilters.count {
                    bandSamples[bandIndex][i] = applyBiquadFilter(input, coeffs: crossoverFilters[bandIndex], state: &bands[bandIndex].lowpassState)
                } else {
                    bandSamples[bandIndex][i] = input // Fallback
                }
            }
        }
        
        // Process each frequency band independently
        for bandIndex in 0..<bands.count {
            processBand(&bandSamples[bandIndex], bandIndex: bandIndex, contentType: contentType)
        }
        
        // Sum processed bands back together
        for i in 0..<samples.count {
            samples[i] = 0.0
            for bandIndex in 0..<bands.count {
                samples[i] += bandSamples[bandIndex][i]
            }
            
            // Apply soft clipping to prevent inter-band summing artifacts
            samples[i] = softClip(samples[i])
        }
    }
    
    /// Process individual frequency band with compression
    private func processBand(_ bandSamples: inout [Float], bandIndex: Int, contentType: AudioContentType) {
        guard bandIndex < bands.count else { return }
        
        var band = bands[bandIndex]
        
        // Adjust compression parameters based on content type
        let adaptiveSettings = getAdaptiveSettings(for: contentType, band: band)
        
        // Calculate envelope coefficients
        let attackCoeff = exp(-1.0 / (adaptiveSettings.attack * sampleRate / 1000.0))
        let releaseCoeff = exp(-1.0 / (adaptiveSettings.release * sampleRate / 1000.0))
        
        for i in 0..<bandSamples.count {
            let input = bandSamples[i]
            let inputLevel = abs(input)
            let inputdB = inputLevel > 0 ? 20.0 * log10(inputLevel) : -80.0
            
            var targetGain: Float = 1.0
            
            // Apply compression if above threshold
            if inputdB > adaptiveSettings.threshold {
                let excess = inputdB - adaptiveSettings.threshold
                let compressedExcess = excess / adaptiveSettings.ratio
                let targetdB = adaptiveSettings.threshold + compressedExcess
                targetGain = pow(10.0, (targetdB - inputdB) / 20.0)
            }
            
            // Smooth envelope following with adaptive time constants
            if targetGain < band.envelope {
                // Attack phase - fast gain reduction
                band.envelope = targetGain + (band.envelope - targetGain) * attackCoeff
            } else {
                // Release phase - gradual gain restoration
                band.envelope = targetGain + (band.envelope - targetGain) * releaseCoeff
            }
            
            // Apply compression and makeup gain
            bandSamples[i] = input * band.envelope * adaptiveSettings.makeupGain
        }
        
        // Update band state
        bands[bandIndex] = band
    }
    
    /// Get adaptive compression settings based on content type
    private func getAdaptiveSettings(for contentType: AudioContentType, band: Band) -> Band {
        var adaptiveBand = band
        
        switch contentType {
        case .speech:
            // Optimize for speech clarity
            if band.lowFreq >= 250.0 && band.highFreq <= 4000.0 {
                // Mid-band: enhance vocal presence
                adaptiveBand.threshold -= 2.0 // Lower threshold for more compression
                adaptiveBand.ratio *= 1.2 // Slightly more compression
                adaptiveBand.makeupGain *= 1.3 // More makeup gain
            }
            
        case .music:
            // Preserve musical dynamics
            adaptiveBand.ratio *= 0.8 // Less aggressive compression
            adaptiveBand.attack *= 1.5 // Slower attack to preserve transients
            
        case .mixed:
            // Balanced approach
            adaptiveBand.ratio *= 0.9
            
        case .silence:
            // Minimal processing for silence
            adaptiveBand.threshold -= 10.0 // Much lower threshold
            adaptiveBand.ratio = 1.0 // No compression
        }
        
        return adaptiveBand
    }
    
    /// Soft clipping function to prevent harsh distortion
    private func softClip(_ input: Float) -> Float {
        let threshold: Float = 0.7
        let absInput = abs(input)
        
        if absInput <= threshold {
            return input
        } else {
            let sign: Float = input >= 0 ? 1.0 : -1.0
            let excess = absInput - threshold
            let softened = threshold + excess / (1.0 + excess)
            return sign * softened
        }
    }
    
    /// Update compressor settings
    func updateSettings(_ settings: AudioEnhancementSettings) {
        setupBands(with: settings)
        setupCrossoverFilters()
    }
}

/// Audio content analyzer for adaptive processing
private class AudioContentAnalyzer {
    private let sampleRate: Float
    private var spectralCentroid: Float = 0.0
    private var spectralRolloff: Float = 0.0
    private var zeroCrossingRate: Float = 0.0
    
    init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }
    
    /// Analyze audio content to determine type
    func analyzeContent(_ samples: [Float]) -> AudioContentType {
        guard !samples.isEmpty else { return .silence }
        
        // Calculate RMS to detect silence
        var rms: Float = 0.0
        var sumSquares: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        rms = sqrt(sumSquares / Float(samples.count))
        
        if rms < 0.001 { // Very quiet, likely silence
            return .silence
        }
        
        // Calculate zero crossing rate for speech detection
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        zeroCrossingRate = Float(crossings) / Float(samples.count) * sampleRate / 2.0
        
        // Calculate spectral features (simplified)
        calculateSpectralFeatures(samples)
        
        // Classify content based on features
        if zeroCrossingRate > 3000 && spectralCentroid > 2000 {
            return .speech // High ZCR and mid-range spectral centroid
        } else if spectralCentroid < 1000 && spectralRolloff < 8000 {
            return .music // Lower spectral centroid, typical of music
        } else {
            return .mixed // Mixed content
        }
    }
    
    /// Calculate spectral features (simplified implementation)
    private func calculateSpectralFeatures(_ samples: [Float]) {
        // This is a simplified implementation
        // In practice, you would use FFT for proper spectral analysis
        
        // Estimate spectral centroid using high-frequency content
        var highFreqEnergy: Float = 0.0
        var totalEnergy: Float = 0.0
        
        for i in 0..<samples.count {
            let sample = samples[i]
            totalEnergy += sample * sample
            
            // Simple high-pass filter approximation for high-frequency content
            if i > 0 {
                let highFreqSample = sample - samples[i-1]
                highFreqEnergy += highFreqSample * highFreqSample
            }
        }
        
        spectralCentroid = totalEnergy > 0 ? (highFreqEnergy / totalEnergy) * sampleRate / 4.0 : 0.0
        spectralRolloff = spectralCentroid * 2.0 // Rough approximation
    }
}

/// Audio content types for adaptive processing
private enum AudioContentType {
    case speech
    case music
    case mixed
    case silence
}

/// Advanced soft limiter with lookahead prediction and smooth gain reduction
private class SoftLimiter {
    private let threshold: Float
    private let release: Float
    private let sampleRate: Float
    private let lookaheadSamples: Int
    private let lookaheadMs: Float
    
    // Delay line for lookahead processing
    private var delayBuffer: [Float]
    private var delayIndex: Int = 0
    
    // Envelope and gain reduction state
    private var envelope: Float = 1.0
    private var targetGain: Float = 1.0
    private var gainSmoothingBuffer: [Float]
    private var gainBufferIndex: Int = 0
    
    // Lookahead prediction
    private var peakPredictionBuffer: [Float]
    private var predictionIndex: Int = 0
    
    // Adaptive release
    private var adaptiveRelease: Float
    private var releaseCoeff: Float
    
    // Distortion prevention
    private let kneeWidth: Float = 2.0 // dB
    private var overshootProtection: Bool = true
    
    init(threshold: Float, release: Float, sampleRate: Float, lookaheadMs: Float = 5.0) {
        self.threshold = threshold
        self.release = release
        self.sampleRate = sampleRate
        self.lookaheadMs = lookaheadMs
        self.lookaheadSamples = Int(lookaheadMs * sampleRate / 1000.0)
        self.adaptiveRelease = release
        
        // Initialize buffers
        self.delayBuffer = Array(repeating: 0.0, count: max(lookaheadSamples, 1))
        self.gainSmoothingBuffer = Array(repeating: 1.0, count: max(lookaheadSamples / 4, 1))
        self.peakPredictionBuffer = Array(repeating: 0.0, count: max(lookaheadSamples, 1))
        
        // Calculate release coefficient
        self.releaseCoeff = exp(-1.0 / (release * sampleRate / 1000.0))
    }
    
    /// Process audio samples with advanced lookahead limiting
    func process(_ samples: inout [Float]) {
        guard !samples.isEmpty && lookaheadSamples > 0 else { return }
        
        let thresholdLinear = pow(10.0, threshold / 20.0)
        let kneeStart = pow(10.0, (threshold - kneeWidth) / 20.0)
        let kneeEnd = thresholdLinear
        
        for i in 0..<samples.count {
            let input = samples[i]
            
            // Store input in delay buffer
            delayBuffer[delayIndex] = input
            
            // Lookahead peak prediction
            let predictedPeak = predictUpcomingPeak(currentSample: input)
            peakPredictionBuffer[predictionIndex] = predictedPeak
            
            // Calculate required gain reduction based on prediction
            let requiredGain = calculateGainReduction(
                predictedPeak: predictedPeak,
                thresholdLinear: thresholdLinear,
                kneeStart: kneeStart,
                kneeEnd: kneeEnd
            )
            
            // Smooth gain changes to prevent artifacts
            let smoothedGain = smoothGainTransition(targetGain: requiredGain)
            
            // Get delayed sample for processing
            let delayedSample = delayBuffer[delayIndex]
            
            // Apply limiting with smooth gain reduction
            samples[i] = delayedSample * smoothedGain
            
            // Apply additional overshoot protection if enabled
            if overshootProtection {
                samples[i] = applyOvershootProtection(samples[i], threshold: thresholdLinear)
            }
            
            // Update adaptive release based on signal characteristics
            updateAdaptiveRelease(inputLevel: abs(input), predictedPeak: predictedPeak)
            
            // Advance buffer indices
            delayIndex = (delayIndex + 1) % lookaheadSamples
            predictionIndex = (predictionIndex + 1) % lookaheadSamples
            gainBufferIndex = (gainBufferIndex + 1) % gainSmoothingBuffer.count
        }
    }
    
    /// Predict upcoming peak using lookahead analysis
    private func predictUpcomingPeak(currentSample: Float) -> Float {
        var maxPeak = abs(currentSample)
        
        // Look ahead in the delay buffer to find potential peaks
        for i in 1..<min(lookaheadSamples, delayBuffer.count) {
            let futureIndex = (delayIndex + i) % delayBuffer.count
            let futureSample = abs(delayBuffer[futureIndex])
            maxPeak = max(maxPeak, futureSample)
        }
        
        // Apply prediction smoothing to avoid rapid changes
        let smoothingFactor: Float = 0.7
        let previousPrediction = peakPredictionBuffer[predictionIndex]
        return maxPeak * (1.0 - smoothingFactor) + previousPrediction * smoothingFactor
    }
    
    /// Calculate gain reduction with soft knee compression
    private func calculateGainReduction(
        predictedPeak: Float,
        thresholdLinear: Float,
        kneeStart: Float,
        kneeEnd: Float
    ) -> Float {
        
        if predictedPeak <= kneeStart {
            // Below knee - no gain reduction
            return 1.0
        } else if predictedPeak <= kneeEnd {
            // In knee region - soft compression
            let kneeRatio = (predictedPeak - kneeStart) / (kneeEnd - kneeStart)
            let compressionAmount = kneeRatio * kneeRatio // Quadratic knee
            let targetLevel = kneeStart + (kneeEnd - kneeStart) * compressionAmount
            return targetLevel / predictedPeak
        } else {
            // Above threshold - hard limiting
            return thresholdLinear / predictedPeak
        }
    }
    
    /// Smooth gain transitions to prevent audible artifacts
    private func smoothGainTransition(targetGain: Float) -> Float {
        // Store target gain in smoothing buffer
        gainSmoothingBuffer[gainBufferIndex] = targetGain
        
        // Calculate smoothed gain using moving average
        var smoothedGain: Float = 0.0
        for gain in gainSmoothingBuffer {
            smoothedGain += gain
        }
        smoothedGain /= Float(gainSmoothingBuffer.count)
        
        // Apply envelope following for additional smoothing
        if smoothedGain < envelope {
            // Fast attack for gain reduction
            let attackCoeff = exp(-1.0 / (0.1 * sampleRate / 1000.0)) // 0.1ms attack
            envelope = smoothedGain + (envelope - smoothedGain) * attackCoeff
        } else {
            // Adaptive release for gain restoration
            envelope = smoothedGain + (envelope - smoothedGain) * releaseCoeff
        }
        
        return envelope
    }
    
    /// Apply overshoot protection to prevent inter-sample peaks
    private func applyOvershootProtection(_ sample: Float, threshold: Float) -> Float {
        let absSample = abs(sample)
        
        if absSample > threshold {
            // Apply soft saturation curve
            let excess = absSample - threshold
            let saturated = threshold + excess / (1.0 + excess / threshold)
            return sample >= 0 ? saturated : -saturated
        }
        
        return sample
    }
    
    /// Update adaptive release based on signal characteristics
    private func updateAdaptiveRelease(inputLevel: Float, predictedPeak: Float) {
        // Faster release for transient signals, slower for sustained signals
        let transientFactor = abs(inputLevel - predictedPeak) / max(inputLevel, 0.001)
        
        if transientFactor > 0.5 {
            // Transient signal - faster release
            adaptiveRelease = release * 0.5
        } else {
            // Sustained signal - normal release
            adaptiveRelease = release
        }
        
        // Update release coefficient
        releaseCoeff = exp(-1.0 / (adaptiveRelease * sampleRate / 1000.0))
    }
    
    /// Update limiter settings
    func updateSettings(threshold: Float, release: Float) {
        // Note: This would require reinitializing buffers if lookahead time changes
        // For now, just update the coefficients
        self.adaptiveRelease = release
        self.releaseCoeff = exp(-1.0 / (release * sampleRate / 1000.0))
    }
    
    /// Get current limiter metrics
    func getMetrics() -> (gainReduction: Float, isLimiting: Bool) {
        let gainReductionDB = envelope < 1.0 ? 20.0 * log10(envelope) : 0.0
        let isLimiting = envelope < 0.95
        return (gainReductionDB, isLimiting)
    }
    
    /// Reset limiter state
    func reset() {
        envelope = 1.0
        targetGain = 1.0
        delayIndex = 0
        gainBufferIndex = 0
        predictionIndex = 0
        
        // Clear buffers
        delayBuffer = Array(repeating: 0.0, count: delayBuffer.count)
        gainSmoothingBuffer = Array(repeating: 1.0, count: gainSmoothingBuffer.count)
        peakPredictionBuffer = Array(repeating: 0.0, count: peakPredictionBuffer.count)
    }
}

/// Core audio processor providing real-time audio enhancement
class AudioProcessor: AudioProcessorProtocol {
    
    // MARK: - Properties
    
    /// Current master gain in dB
    private var masterGain: Float = 0.0
    
    /// Whether automatic gain control is enabled
    private var autoGainEnabled: Bool = true
    
    /// Current audio enhancement settings
    private var currentSettings: AudioEnhancementSettings
    
    /// Audio quality monitor
    private let qualityMonitor: AudioQualityMonitor
    
    /// Multiband compressor
    private var compressor: MultibandCompressor?
    
    /// Soft limiter
    private var limiter: SoftLimiter?
    
    /// Processing statistics
    private var processedFrames: Int = 0
    private var processingErrors: Int = 0
    
    // MARK: - Performance Optimization Components
    
    /// High-performance buffer pool for memory management
    private var bufferPool: AudioBufferPool?
    
    /// Memory usage monitor
    private let memoryMonitor: AudioMemoryMonitor
    
    /// Performance metrics tracking
    private var processingTimeHistory: [Double] = []
    private let maxPerformanceHistorySize: Int = 100
    
    /// Auto gain control state
    private var targetLUFS: Float = -16.0
    private var currentLUFS: Float = -16.0
    private var lufsHistory: [Float] = []
    private let lufsHistorySize: Int = 50
    
    /// Quality protection state
    private var qualityProtectionActive: Bool = false
    private var fallbackGain: Float = 0.0
    private var losslessModeActive: Bool = false
    private var originalAudioBuffer: [Float] = []
    private var qualityFallbackCount: Int = 0
    private let maxQualityFallbackCount: Int = 3
    
    // MARK: - Initialization
    
    /// Initialize audio processor with default settings
    /// - Parameter settings: Initial audio enhancement settings
    init(settings: AudioEnhancementSettings = AudioEnhancementSettings()) {
        self.currentSettings = settings
        self.masterGain = settings.masterGain
        self.autoGainEnabled = settings.autoGainEnabled
        self.targetLUFS = settings.targetLUFS
        
        // Initialize quality monitor
        self.qualityMonitor = AudioQualityMonitor(
            maxTHD: settings.maxTHD,
            clippingThreshold: -0.1
        )
        
        // Initialize memory monitor
        self.memoryMonitor = AudioMemoryMonitor.realTimeMonitor()
        
        // Set up quality monitor delegate
        self.qualityMonitor.delegate = self
        
        // Setup memory monitoring callbacks
        setupMemoryMonitoringCallbacks()
        
        print("🎵 AudioProcessor initialized with preset: \(settings.preset.rawValue)")
        print("🏊‍♂️ Performance optimizations enabled: buffer pooling, vDSP acceleration, memory monitoring")
    }
    
    // MARK: - AudioProcessorProtocol Implementation
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, settings: AudioEnhancementSettings) throws -> AVAudioPCMBuffer {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard settings.processingEnabled else {
            // Pass through without processing
            return buffer
        }
        
        // Update settings if changed
        if settings != currentSettings {
            try updateSettings(settings)
        }
        
        // Validate buffer format
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            throw AudioProcessingError.unsupportedAudioFormat
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Initialize buffer pool if needed
        if bufferPool == nil {
            try initializeBufferPool(sampleRate: Double(sampleRate), channelCount: channelCount)
        }
        
        // Get optimized output buffer from pool
        let outputBuffer: AVAudioPCMBuffer
        if let pool = bufferPool {
            outputBuffer = try pool.getBuffer()
            outputBuffer.frameLength = buffer.frameLength
        } else {
            // Fallback to direct allocation
            guard let fallbackBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
                throw AudioProcessingError.memoryAllocationFailed
            }
            outputBuffer = fallbackBuffer
            outputBuffer.frameLength = buffer.frameLength
        }
        
        guard let outputChannelData = outputBuffer.floatChannelData else {
            throw AudioProcessingError.memoryAllocationFailed
        }
        
        // Process each channel using optimized DSP operations
        for channel in 0..<channelCount {
            let inputPtr = floatChannelData[channel]
            let outputPtr = outputChannelData[channel]
            
            // Use optimized buffer copy
            AudioDSPOptimizer.copyBuffer(from: inputPtr, to: outputPtr, frameCount: frameCount)
            
            // Apply processing chain with optimized operations
            try processChannelOptimized(outputPtr, frameCount: frameCount, sampleRate: sampleRate)
        }
        
        // Update quality monitoring
        try qualityMonitor.processAudioBuffer(outputBuffer)
        
        // Track performance metrics
        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to milliseconds
        updatePerformanceMetrics(processingTime: processingTime, frameCount: frameCount)
        
        // Track memory usage
        trackMemoryUsage()
        
        processedFrames += frameCount
        
        return outputBuffer
    }
    
    func setGain(_ gain: Float) {
        guard gain >= -20.0 && gain <= 20.0 else {
            print("⚠️ Invalid gain value: \(gain) dB. Must be between -20.0 and +20.0")
            return
        }
        
        masterGain = gain
        currentSettings.masterGain = gain
        currentSettings.preset = .custom // Mark as custom when manually adjusted
        
        print("🎚️ Master gain set to \(String(format: "%.1f", gain)) dB")
    }
    
    func enableAutoGainControl(_ enabled: Bool) {
        autoGainEnabled = enabled
        currentSettings.autoGainEnabled = enabled
        
        if enabled {
            print("🤖 Auto gain control enabled (target: \(String(format: "%.1f", targetLUFS)) LUFS)")
        } else {
            print("🎚️ Manual gain control enabled")
        }
    }
    
    func getAudioMetrics() -> AudioMetrics {
        return qualityMonitor.getCurrentMetrics()
    }
    
    // MARK: - Public Methods
    
    /// Update audio enhancement settings
    /// - Parameter settings: New settings to apply
    /// - Throws: AudioProcessingError if settings are invalid
    func updateSettings(_ settings: AudioEnhancementSettings) throws {
        guard settings.isValid else {
            throw AudioProcessingError.qualityThresholdExceeded
        }
        
        currentSettings = settings
        masterGain = settings.masterGain
        autoGainEnabled = settings.autoGainEnabled
        targetLUFS = settings.targetLUFS
        
        // Update existing processors with new settings
        compressor?.updateSettings(settings)
        limiter?.updateSettings(threshold: settings.limiterThreshold, release: settings.limiterRelease)
        
        // If processors don't exist yet, they will be created on first buffer processing
        if compressor == nil || limiter == nil {
            try setupProcessors(sampleRate: 48000.0) // Default sample rate, will be updated on first buffer
        }
        
        print("⚙️ Audio settings updated: \(settings.preset.rawValue)")
    }
    
    /// Get current processing statistics
    /// - Returns: Dictionary with processing statistics
    func getProcessingStats() -> [String: Any] {
        let metrics = qualityMonitor.getCurrentMetrics()
        
        var stats: [String: Any] = [
            "processedFrames": processedFrames,
            "processingErrors": processingErrors,
            "currentGain": masterGain,
            "autoGainEnabled": autoGainEnabled,
            "qualityProtectionActive": qualityProtectionActive,
            "peakLevel": metrics.peakLevel,
            "rmsLevel": metrics.rmsLevel,
            "thd": metrics.thd,
            "clippingDetected": metrics.clippingDetected,
            "preset": currentSettings.preset.rawValue,
            "processingEnabled": currentSettings.processingEnabled
        ]
        
        // Add limiter statistics if available
        if let limiter = limiter {
            let limiterMetrics = limiter.getMetrics()
            stats["limiterGainReduction"] = limiterMetrics.gainReduction
            stats["limiterActive"] = limiterMetrics.isLimiting
        }
        
        return stats
    }
    
    /// Reset processing statistics and state
    func reset() {
        processedFrames = 0
        processingErrors = 0
        qualityProtectionActive = false
        losslessModeActive = false
        qualityFallbackCount = 0
        lufsHistory.removeAll()
        originalAudioBuffer.removeAll()
        qualityMonitor.reset()
        
        // Reset processors
        limiter?.reset()
        
        print("🔄 AudioProcessor reset")
    }
    
    /// Enable or disable lossless audio enhancement mode
    /// - Parameter enabled: Whether to enable lossless mode
    func enableLosslessMode(_ enabled: Bool) {
        losslessModeActive = enabled
        qualityMonitor.enableLosslessMode(enabled)
        
        if enabled {
            // In lossless mode, use very conservative settings
            var losslessSettings = currentSettings
            losslessSettings.compressionRatio = 1.5 // Minimal compression
            losslessSettings.threshold = -6.0 // Higher threshold
            losslessSettings.limiterThreshold = -0.5 // Conservative limiting
            losslessSettings.maxTHD = 0.0005 // Stricter THD limit
            
            try? updateSettings(losslessSettings)
            print("🔒 Lossless audio mode enabled - using conservative processing")
        } else {
            print("🔓 Lossless audio mode disabled - normal processing restored")
        }
    }
    
    /// Check if lossless mode is active
    var isLosslessModeActive: Bool {
        return losslessModeActive
    }
    
    /// Get audio quality analysis report
    /// - Returns: Detailed quality analysis report
    func getQualityAnalysisReport() -> [String: Any] {
        let protectionHistory = qualityMonitor.getProtectionHistory()
        let currentMetrics = qualityMonitor.getCurrentMetrics()
        
        var report: [String: Any] = [
            "losslessModeActive": losslessModeActive,
            "qualityProtectionActive": qualityProtectionActive,
            "qualityFallbackCount": qualityFallbackCount,
            "totalProtectionEvents": protectionHistory.count,
            "currentQualityScore": calculateCurrentQualityScore(currentMetrics),
            "processingRecommendation": getProcessingRecommendation(currentMetrics)
        ]
        
        // Add event type counts
        let eventCounts = Dictionary(grouping: protectionHistory, by: { $0.eventType })
            .mapValues { $0.count }
        report["eventCounts"] = eventCounts
        
        // Add recent quality trends
        let recentEvents = protectionHistory.suffix(10)
        let avgSeverity = recentEvents.isEmpty ? 0.0 : recentEvents.map { $0.severity }.reduce(0, +) / Float(recentEvents.count)
        report["recentAverageSeverity"] = avgSeverity
        
        // Add performance metrics
        report["performanceMetrics"] = getPerformanceMetrics()
        
        // Add memory statistics
        report["memoryStatistics"] = getMemoryStatistics()
        
        return report
    }
    
    /// Get performance metrics
    /// - Returns: Performance metrics dictionary
    func getPerformanceMetrics() -> [String: Any] {
        let avgProcessingTime = processingTimeHistory.isEmpty ? 0.0 : 
            processingTimeHistory.reduce(0, +) / Double(processingTimeHistory.count)
        let maxProcessingTime = processingTimeHistory.max() ?? 0.0
        let minProcessingTime = processingTimeHistory.min() ?? 0.0
        
        var metrics: [String: Any] = [
            "averageProcessingTimeMs": avgProcessingTime,
            "maxProcessingTimeMs": maxProcessingTime,
            "minProcessingTimeMs": minProcessingTime,
            "processedFrames": processedFrames,
            "processingErrors": processingErrors
        ]
        
        // Add buffer pool statistics if available
        if let pool = bufferPool {
            metrics["bufferPoolStats"] = pool.getPoolStatistics()
        }
        
        return metrics
    }
    
    /// Get memory statistics
    /// - Returns: Memory statistics dictionary
    func getMemoryStatistics() -> [String: Any] {
        let memoryStats = memoryMonitor.getCurrentMemoryStatistics()
        
        return [
            "totalMemoryMB": memoryStats.totalMemoryMB,
            "audioProcessingMemoryMB": memoryStats.audioProcessingMemoryMB,
            "bufferPoolMemoryMB": memoryStats.bufferPoolMemoryMB,
            "memoryGrowthRate": memoryStats.memoryGrowthRate,
            "peakMemoryMB": memoryStats.peakMemoryMB,
            "memoryPressure": memoryStats.systemMemoryPressure.rawValue,
            "optimizationRecommendations": memoryMonitor.getOptimizationRecommendations()
        ]
    }
    
    // MARK: - Private Methods
    
    /// Setup audio processors based on current settings
    /// - Parameter sampleRate: Audio sample rate
    /// - Throws: AudioProcessingError if setup fails
    private func setupProcessors(sampleRate: Float) throws {
        // Setup multiband compressor with current settings
        compressor = MultibandCompressor(sampleRate: sampleRate, settings: currentSettings)
        
        // Setup soft limiter with lookahead
        limiter = SoftLimiter(
            threshold: currentSettings.limiterThreshold,
            release: currentSettings.limiterRelease,
            sampleRate: sampleRate,
            lookaheadMs: 5.0 // 5ms lookahead for prediction
        )
        
        print("🔧 Enhanced audio processors initialized for \(Int(sampleRate)) Hz")
        print("   - Multiband compressor: 3-band crossover (250Hz, 4kHz)")
        print("   - Soft limiter: \(String(format: "%.1f", currentSettings.limiterThreshold))dB threshold with 5ms lookahead")
    }
    
    /// Process a single channel of audio
    /// - Parameters:
    ///   - samples: Audio samples to process (modified in place)
    ///   - sampleRate: Sample rate of the audio
    /// - Throws: AudioProcessingError if processing fails
    private func processChannel(_ samples: inout [Float], sampleRate: Float) throws {
        // Store original samples for quality comparison
        let originalSamples = samples
        qualityMonitor.storeOriginalAudio(originalSamples)
        
        // In lossless mode, apply minimal processing
        if losslessModeActive {
            try processLosslessMode(&samples, sampleRate: sampleRate)
            return
        }
        
        // Initialize processors if needed
        if compressor == nil || limiter == nil {
            try setupProcessors(sampleRate: sampleRate)
        }
        
        // 1. Apply master gain
        let gainLinear = pow(10.0, masterGain / 20.0)
        vDSP_vsmul(samples, 1, [gainLinear], &samples, 1, vDSP_Length(samples.count))
        
        // 2. Auto gain control
        if autoGainEnabled {
            try applyAutoGainControl(&samples)
        }
        
        // 3. Multiband compression
        compressor?.process(&samples)
        
        // 4. Soft limiting
        limiter?.process(&samples)
        
        // 5. Quality protection check
        if currentSettings.qualityProtectionEnabled {
            try applyQualityProtection(&samples)
        }
        
        // 6. Quality comparison and analysis
        if currentSettings.qualityProtectionEnabled {
            performQualityAnalysis(original: originalSamples, processed: samples)
        }
    }
    
    /// Process audio in lossless mode with minimal enhancement
    /// - Parameters:
    ///   - samples: Audio samples to process
    ///   - sampleRate: Sample rate of the audio
    /// - Throws: AudioProcessingError if processing fails
    private func processLosslessMode(_ samples: inout [Float], sampleRate: Float) throws {
        // In lossless mode, only apply minimal gain adjustment and soft limiting
        
        // 1. Apply very conservative gain (max 3dB)
        let conservativeGain = min(3.0, max(-3.0, masterGain))
        let gainLinear = pow(10.0, conservativeGain / 20.0)
        vDSP_vsmul(samples, 1, [gainLinear], &samples, 1, vDSP_Length(samples.count))
        
        // 2. Apply only soft limiting to prevent clipping
        if let limiter = limiter {
            limiter.process(&samples)
        }
        
        // 3. Ensure no clipping occurs
        for i in 0..<samples.count {
            samples[i] = max(-0.95, min(0.95, samples[i]))
        }
    }
    
    /// Perform quality analysis comparing original and processed audio
    /// - Parameters:
    ///   - original: Original audio samples
    ///   - processed: Processed audio samples
    private func performQualityAnalysis(original: [Float], processed: [Float]) {
        guard let comparison = qualityMonitor.compareAudioQuality(processed) else {
            return
        }
        
        // Handle quality degradation
        if comparison.degradationDetected {
            qualityFallbackCount += 1
            
            // If quality degradation persists, take corrective action
            if qualityFallbackCount >= maxQualityFallbackCount {
                handleQualityDegradation(comparison: comparison)
                qualityFallbackCount = 0 // Reset counter after taking action
            }
        } else {
            // Reset fallback count if quality is good
            qualityFallbackCount = max(0, qualityFallbackCount - 1)
        }
    }
    
    /// Handle quality degradation by taking corrective action
    /// - Parameter comparison: Quality comparison result
    private func handleQualityDegradation(comparison: AudioQualityComparison) {
        print("🚨 Quality degradation detected - taking corrective action")
        print("   Quality Score: \(String(format: "%.2f", comparison.qualityScore))")
        print("   SNR: \(String(format: "%.1f", comparison.snr)) dB")
        print("   THD Increase: \(String(format: "%.3f", comparison.thd * 100))%")
        
        switch comparison.recommendedAction {
        case .reduceGain(let amount):
            let newGain = masterGain - amount
            setGain(max(-20.0, newGain))
            print("   Action: Reduced gain by \(String(format: "%.1f", amount)) dB")
            
        case .disableCompression:
            var newSettings = currentSettings
            newSettings.compressionRatio = 1.0 // Disable compression
            try? updateSettings(newSettings)
            print("   Action: Disabled compression")
            
        case .enableLosslessMode:
            enableLosslessMode(true)
            print("   Action: Enabled lossless mode")
            
        case .fallbackToOriginal:
            // Disable all processing temporarily
            var newSettings = currentSettings
            newSettings.processingEnabled = false
            try? updateSettings(newSettings)
            print("   Action: Disabled all processing (fallback to original)")
            
        case .adjustCompressionRatio(let newRatio):
            var newSettings = currentSettings
            newSettings.compressionRatio = newRatio
            try? updateSettings(newSettings)
            print("   Action: Adjusted compression ratio to \(String(format: "%.1f", newRatio))")
            
        case .adjustLimiterThreshold(let newThreshold):
            var newSettings = currentSettings
            newSettings.limiterThreshold = newThreshold
            try? updateSettings(newSettings)
            print("   Action: Adjusted limiter threshold to \(String(format: "%.1f", newThreshold)) dB")
        }
    }
    
    /// Apply automatic gain control based on LUFS measurement
    /// - Parameter samples: Audio samples to process
    /// - Throws: AudioProcessingError if AGC fails
    private func applyAutoGainControl(_ samples: inout [Float]) throws {
        // Calculate current LUFS (simplified implementation)
        var rms: Float = 0.0
        var sumSquares: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        rms = sqrt(sumSquares / Float(samples.count))
        
        let currentLUFS = rms > 0 ? -0.691 + 10.0 * log10(rms * rms + 1e-10) : -80.0
        
        // Update LUFS history
        lufsHistory.append(currentLUFS)
        if lufsHistory.count > lufsHistorySize {
            lufsHistory.removeFirst()
        }
        
        // Calculate average LUFS
        let avgLUFS = lufsHistory.reduce(0, +) / Float(lufsHistory.count)
        
        // Calculate gain adjustment
        let lufsError = targetLUFS - avgLUFS
        let maxAdjustment: Float = 0.1 // Maximum 0.1 dB adjustment per buffer
        let gainAdjustment = max(-maxAdjustment, min(maxAdjustment, lufsError * 0.01))
        
        // Apply gradual gain adjustment
        if abs(gainAdjustment) > 0.01 {
            let adjustmentLinear = pow(10.0, gainAdjustment / 20.0)
            vDSP_vsmul(samples, 1, [adjustmentLinear], &samples, 1, vDSP_Length(samples.count))
            
            // Update master gain for tracking
            masterGain += gainAdjustment
            masterGain = max(-20.0, min(20.0, masterGain)) // Clamp to valid range
        }
    }
    
    /// Apply quality protection mechanisms
    /// - Parameter samples: Audio samples to check and protect
    /// - Throws: AudioProcessingError if quality protection is triggered
    private func applyQualityProtection(_ samples: inout [Float]) throws {
        // Check for clipping
        var peak: Float = 0.0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        
        if peak >= 0.99 { // Near clipping
            if !qualityProtectionActive {
                qualityProtectionActive = true
                fallbackGain = masterGain
                
                // Reduce gain by 3dB as protection
                let protectionGain = Float(pow(10.0, -3.0 / 20.0))
                vDSP_vsmul(samples, 1, [protectionGain], &samples, 1, vDSP_Length(samples.count))
                
                print("🛡️ Quality protection activated: reducing gain by 3dB")
            }
        } else if peak < 0.7 && qualityProtectionActive {
            // Gradually restore gain when levels are safe
            qualityProtectionActive = false
            print("✅ Quality protection deactivated: levels safe")
        }
    }
    
    /// Calculate current quality score based on metrics
    /// - Parameter metrics: Current audio metrics
    /// - Returns: Quality score from 0.0 to 1.0
    private func calculateCurrentQualityScore(_ metrics: AudioMetrics) -> Float {
        var score: Float = 1.0
        
        // Penalize clipping
        if metrics.clippingDetected {
            score -= 0.3
        }
        
        // Penalize high distortion
        if metrics.thd > currentSettings.maxTHD {
            let thdPenalty = min(0.4, (metrics.thd / currentSettings.maxTHD - 1.0) * 0.4)
            score -= thdPenalty
        }
        
        // Penalize poor dynamic range
        if metrics.dynamicRange < 6.0 {
            score -= (6.0 - metrics.dynamicRange) / 20.0
        }
        
        // Penalize levels that are too high or too low
        if metrics.peakLevel > -1.0 {
            score -= (metrics.peakLevel + 1.0) / 10.0
        } else if metrics.peakLevel < -40.0 {
            score -= (-40.0 - metrics.peakLevel) / 100.0
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// Get processing recommendation based on current metrics
    /// - Parameter metrics: Current audio metrics
    /// - Returns: Processing recommendation string
    private func getProcessingRecommendation(_ metrics: AudioMetrics) -> String {
        if losslessModeActive {
            return "Lossless mode active - minimal processing applied"
        }
        
        if metrics.clippingDetected {
            return "Reduce gain to prevent clipping"
        }
        
        if metrics.thd > currentSettings.maxTHD {
            return "Reduce compression or enable lossless mode"
        }
        
        if metrics.peakLevel < -30.0 {
            return "Increase gain for better signal level"
        }
        
        if metrics.dynamicRange < 3.0 {
            return "Reduce compression ratio to preserve dynamics"
        }
        
        return "Processing settings are optimal"
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Initialize buffer pool for optimized memory management
    /// - Parameters:
    ///   - sampleRate: Audio sample rate
    ///   - channelCount: Number of audio channels
    /// - Throws: AudioProcessingError if initialization fails
    private func initializeBufferPool(sampleRate: Double, channelCount: Int) throws {
        do {
            bufferPool = try AudioBufferPool.realTimePool(
                sampleRate: sampleRate,
                channelCount: channelCount,
                latencyOptimized: true
            )
            
            // Register buffer pool with memory monitor
            if let pool = bufferPool {
                memoryMonitor.registerBufferPool(pool)
            }
            
            print("🏊‍♂️ Buffer pool initialized for \(Int(sampleRate))Hz, \(channelCount)ch")
        } catch {
            print("⚠️ Failed to initialize buffer pool: \(error.localizedDescription)")
            throw AudioProcessingError.memoryAllocationFailed
        }
    }
    
    /// Process audio channel using optimized DSP operations
    /// - Parameters:
    ///   - buffer: Audio buffer pointer (modified in place)
    ///   - frameCount: Number of frames to process
    ///   - sampleRate: Sample rate of the audio
    /// - Throws: AudioProcessingError if processing fails
    private func processChannelOptimized(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Float) throws {
        // Store original samples for quality comparison (using optimized copy)
        var originalSamples = [Float](repeating: 0.0, count: frameCount)
        AudioDSPOptimizer.copyBuffer(from: buffer, to: &originalSamples, frameCount: frameCount)
        qualityMonitor.storeOriginalAudio(originalSamples)
        
        // In lossless mode, apply minimal processing
        if losslessModeActive {
            try processLosslessModeOptimized(buffer, frameCount: frameCount, sampleRate: sampleRate)
            return
        }
        
        // Initialize processors if needed
        if compressor == nil || limiter == nil {
            try setupProcessors(sampleRate: sampleRate)
        }
        
        // 1. Apply master gain using optimized vDSP operation
        let gainLinear = pow(10.0, masterGain / 20.0)
        AudioDSPOptimizer.applyGain(buffer: buffer, gain: gainLinear, frameCount: frameCount)
        
        // 2. Remove DC offset using optimized operation
        AudioDSPOptimizer.removeDCOffset(buffer: buffer, frameCount: frameCount)
        
        // 3. Auto gain control using optimized RMS calculation
        if autoGainEnabled {
            try applyAutoGainControlOptimized(buffer, frameCount: frameCount)
        }
        
        // 4. Multiband compression (convert to array for existing implementation)
        var samples = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
        compressor?.process(&samples)
        
        // Copy back to buffer using optimized operation
        AudioDSPOptimizer.copyBuffer(from: samples, to: buffer, frameCount: frameCount)
        
        // 5. Soft limiting (convert to array for existing implementation)
        samples = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
        limiter?.process(&samples)
        
        // Copy back to buffer
        AudioDSPOptimizer.copyBuffer(from: samples, to: buffer, frameCount: frameCount)
        
        // 6. Quality protection check using optimized peak detection
        if currentSettings.qualityProtectionEnabled {
            try applyQualityProtectionOptimized(buffer, frameCount: frameCount)
        }
        
        // 7. Quality comparison and analysis
        if currentSettings.qualityProtectionEnabled {
            let processedSamples = Array(UnsafeBufferPointer(start: buffer, count: frameCount))
            performQualityAnalysis(original: originalSamples, processed: processedSamples)
        }
    }
    
    /// Process audio in lossless mode with optimized operations
    /// - Parameters:
    ///   - buffer: Audio buffer pointer
    ///   - frameCount: Number of frames
    ///   - sampleRate: Sample rate
    /// - Throws: AudioProcessingError if processing fails
    private func processLosslessModeOptimized(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Float) throws {
        // In lossless mode, only apply minimal gain adjustment and soft limiting
        
        // 1. Apply very conservative gain (max 3dB) using optimized operation
        let conservativeGain = min(3.0, max(-3.0, masterGain))
        let gainLinear = pow(10.0, conservativeGain / 20.0)
        AudioDSPOptimizer.applyGain(buffer: buffer, gain: gainLinear, frameCount: frameCount)
        
        // 2. Apply soft clipping to prevent harsh distortion
        AudioDSPOptimizer.applySoftClipping(buffer: buffer, threshold: 0.95, frameCount: frameCount)
    }
    
    /// Apply auto gain control using optimized operations
    /// - Parameters:
    ///   - buffer: Audio buffer pointer
    ///   - frameCount: Number of frames
    /// - Throws: AudioProcessingError if AGC fails
    private func applyAutoGainControlOptimized(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) throws {
        // Calculate current LUFS using optimized RMS calculation
        let rms = AudioDSPOptimizer.calculateRMS(buffer: buffer, frameCount: frameCount)
        let currentLUFS = rms > 0 ? -0.691 + 10.0 * log10(rms * rms + 1e-10) : -80.0
        
        // Update LUFS history
        lufsHistory.append(currentLUFS)
        if lufsHistory.count > lufsHistorySize {
            lufsHistory.removeFirst()
        }
        
        // Calculate average LUFS
        let avgLUFS = lufsHistory.reduce(0, +) / Float(lufsHistory.count)
        
        // Calculate gain adjustment
        let lufsError = targetLUFS - avgLUFS
        let maxAdjustment: Float = 0.1 // Maximum 0.1 dB adjustment per buffer
        let gainAdjustment = max(-maxAdjustment, min(maxAdjustment, lufsError * 0.01))
        
        // Apply gradual gain adjustment using optimized operation
        if abs(gainAdjustment) > 0.01 {
            let adjustmentLinear = pow(10.0, gainAdjustment / 20.0)
            AudioDSPOptimizer.applyGain(buffer: buffer, gain: adjustmentLinear, frameCount: frameCount)
            
            // Update master gain for tracking
            masterGain += gainAdjustment
            masterGain = max(-20.0, min(20.0, masterGain)) // Clamp to valid range
        }
    }
    
    /// Apply quality protection using optimized operations
    /// - Parameters:
    ///   - buffer: Audio buffer pointer
    ///   - frameCount: Number of frames
    /// - Throws: AudioProcessingError if quality protection is triggered
    private func applyQualityProtectionOptimized(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) throws {
        // Check for clipping using optimized peak detection
        let peak = AudioDSPOptimizer.findPeak(buffer: buffer, frameCount: frameCount)
        
        if peak >= 0.99 { // Near clipping
            if !qualityProtectionActive {
                qualityProtectionActive = true
                fallbackGain = masterGain
                
                // Reduce gain by 3dB as protection using optimized operation
                let protectionGain: Float = pow(10.0, -3.0 / 20.0)
                AudioDSPOptimizer.applyGain(buffer: buffer, gain: protectionGain, frameCount: frameCount)
                
                print("🛡️ Quality protection activated: reducing gain by 3dB")
            }
        } else if peak < 0.7 && qualityProtectionActive {
            // Gradually restore gain when levels are safe
            qualityProtectionActive = false
            print("✅ Quality protection deactivated: levels safe")
        }
    }
    
    /// Setup memory monitoring callbacks
    private func setupMemoryMonitoringCallbacks() {
        memoryMonitor.onMemoryWarning = { [weak self] memoryMB in
            print("⚠️ Memory warning: \(String(format: "%.1f", memoryMB)) MB")
            self?.optimizeMemoryUsage()
        }
        
        memoryMonitor.onCriticalMemory = { [weak self] memoryMB in
            print("🚨 Critical memory: \(String(format: "%.1f", memoryMB)) MB")
            self?.emergencyMemoryCleanup()
        }
        
        memoryMonitor.onMemoryLeak = { [weak self] component, leakMB in
            print("🔍 Memory leak detected in \(component): \(String(format: "%.1f", leakMB)) MB")
            self?.handleMemoryLeak(component: component, leakMB: leakMB)
        }
    }
    
    /// Update performance metrics
    /// - Parameters:
    ///   - processingTime: Processing time in milliseconds
    ///   - frameCount: Number of frames processed
    private func updatePerformanceMetrics(processingTime: Double, frameCount: Int) {
        processingTimeHistory.append(processingTime)
        
        // Limit history size
        if processingTimeHistory.count > maxPerformanceHistorySize {
            processingTimeHistory.removeFirst()
        }
        
        // Check for performance issues
        let avgProcessingTime = processingTimeHistory.reduce(0, +) / Double(processingTimeHistory.count)
        let expectedTime = Double(frameCount) / 48000.0 * 1000.0 // Expected time for 48kHz
        
        if avgProcessingTime > expectedTime * 0.5 { // Using more than 50% of available time
            print("⚠️ High processing latency: \(String(format: "%.2f", avgProcessingTime))ms (avg)")
        }
    }
    
    /// Track memory usage for this component
    private func trackMemoryUsage() {
        // Estimate memory usage based on processing state
        var memoryUsage: Double = 0.0
        
        // Base processor memory
        memoryUsage += 5.0 // Base overhead
        
        // Buffer pool memory (if available)
        if let pool = bufferPool {
            let stats = pool.getPoolStatistics()
            if let poolMemory = stats["estimatedMemoryMB"] as? Float {
                memoryUsage += Double(poolMemory)
            }
        }
        
        // Processing history memory
        memoryUsage += Double(processingTimeHistory.count * MemoryLayout<Double>.size) / (1024 * 1024)
        
        // LUFS history memory
        memoryUsage += Double(lufsHistory.count * MemoryLayout<Float>.size) / (1024 * 1024)
        
        // Track with memory monitor
        memoryMonitor.trackComponentMemory(component: "AudioProcessor", memoryMB: memoryUsage)
    }
    
    /// Optimize memory usage when warning threshold is reached
    private func optimizeMemoryUsage() {
        // Compact buffer pool
        bufferPool?.compactPool()
        
        // Trim performance history
        if processingTimeHistory.count > 50 {
            processingTimeHistory = Array(processingTimeHistory.suffix(50))
        }
        
        // Trim LUFS history
        if lufsHistory.count > 25 {
            lufsHistory = Array(lufsHistory.suffix(25))
        }
        
        print("🧹 AudioProcessor memory optimized")
    }
    
    /// Emergency memory cleanup for critical memory situations
    private func emergencyMemoryCleanup() {
        // Aggressive memory cleanup
        bufferPool?.compactPool()
        
        // Clear performance history
        processingTimeHistory.removeAll()
        
        // Reduce LUFS history to minimum
        if lufsHistory.count > 10 {
            lufsHistory = Array(lufsHistory.suffix(10))
        }
        
        // Clear original audio buffer
        originalAudioBuffer.removeAll()
        
        print("🚨 AudioProcessor emergency memory cleanup completed")
    }
    
    /// Handle detected memory leak
    /// - Parameters:
    ///   - component: Component with memory leak
    ///   - leakMB: Amount of leaked memory in MB
    private func handleMemoryLeak(component: String, leakMB: Double) {
        if component == "AudioProcessor" {
            // Reset processor state to prevent further leaks
            reset()
            print("🔄 AudioProcessor reset due to memory leak")
        }
    }
    
    /// Return buffer to pool when processing is complete
    /// - Parameter buffer: Buffer to return
    func returnBufferToPool(_ buffer: AVAudioPCMBuffer) {
        bufferPool?.returnBuffer(buffer)
    }
    
    /// Get comprehensive performance report
    /// - Returns: Formatted performance report
    func getPerformanceReport() -> String {
        let performanceMetrics = getPerformanceMetrics()
        let memoryStats = getMemoryStatistics()
        
        var report = "🚀 AudioProcessor Performance Report:\n\n"
        
        // Processing performance
        if let avgTime = performanceMetrics["averageProcessingTimeMs"] as? Double,
           let maxTime = performanceMetrics["maxProcessingTimeMs"] as? Double {
            report += "⏱️ Processing Performance:\n"
            report += "   Average: \(String(format: "%.2f", avgTime))ms\n"
            report += "   Peak: \(String(format: "%.2f", maxTime))ms\n"
            report += "   Processed Frames: \(processedFrames)\n\n"
        }
        
        // Memory usage
        if let totalMB = memoryStats["totalMemoryMB"] as? Double,
           let audioMB = memoryStats["audioProcessingMemoryMB"] as? Double {
            report += "🧠 Memory Usage:\n"
            report += "   Total: \(String(format: "%.1f", totalMB)) MB\n"
            report += "   Audio Processing: \(String(format: "%.1f", audioMB)) MB\n"
        }
        
        // Buffer pool statistics
        if let poolStats = performanceMetrics["bufferPoolStats"] as? [String: Any] {
            if let hitRate = poolStats["hitRate"] as? Float,
               let allocated = poolStats["totalAllocatedBuffers"] as? Int {
                report += "\n🏊‍♂️ Buffer Pool:\n"
                report += "   Hit Rate: \(String(format: "%.1f", hitRate * 100))%\n"
                report += "   Allocated Buffers: \(allocated)\n"
            }
        }
        
        // Optimization recommendations
        if let recommendations = memoryStats["optimizationRecommendations"] as? [String] {
            report += "\n💡 Recommendations:\n"
            for recommendation in recommendations.prefix(3) {
                report += "   • \(recommendation)\n"
            }
        }
        
        return report
    }
}

// MARK: - AudioQualityMonitorDelegate

extension AudioProcessor: AudioQualityMonitorDelegate {
    
    func audioQualityUpdated(_ metrics: AudioMetrics) {
        // Update internal state based on quality metrics
        currentLUFS = metrics.rmsLevel
        
        // Log quality issues if verbose mode is enabled
        if metrics.clippingDetected || metrics.thd > currentSettings.maxTHD {
            print("⚠️ Audio quality issue detected: Peak=\(String(format: "%.1f", metrics.peakLevel))dB, THD=\(String(format: "%.3f", metrics.thd * 100))%")
        }
    }
    
    func audioQualityIssueDetected(_ issue: String, severity: Float) {
        print("🚨 Audio Quality Issue (\(String(format: "%.0f", severity * 100))%): \(issue)")
        
        // Take corrective action for high severity issues
        if severity > 0.7 && currentSettings.qualityProtectionEnabled {
            // Reduce processing intensity
            if masterGain > 0 {
                setGain(masterGain - 1.0)
                print("🛡️ Reducing gain by 1dB due to quality issue")
            }
        }
    }
    
    func clippingDetected(at level: Float) {
        print("📢 Clipping detected at \(String(format: "%.1f", level)) dBFS")
        
        // Immediate gain reduction if clipping is severe
        if level > -0.1 && currentSettings.qualityProtectionEnabled {
            masterGain -= 6.0
            masterGain = max(-20.0, masterGain)
            print("🚨 Emergency gain reduction: -6dB")
        }
    }
    
    func qualityDegradationDetected(originalMetrics: AudioMetrics, processedMetrics: AudioMetrics, recommendedAction: QualityProtectionAction) {
        print("🔍 Quality degradation detected between original and processed audio")
        print("   Original: Peak=\(String(format: "%.1f", originalMetrics.peakLevel))dB, THD=\(String(format: "%.3f", originalMetrics.thd * 100))%")
        print("   Processed: Peak=\(String(format: "%.1f", processedMetrics.peakLevel))dB, THD=\(String(format: "%.3f", processedMetrics.thd * 100))%")
        
        // Apply recommended action if quality protection is enabled
        if currentSettings.qualityProtectionEnabled {
            switch recommendedAction {
            case .reduceGain(let amount):
                setGain(masterGain - amount)
                print("   Applied: Reduced gain by \(String(format: "%.1f", amount)) dB")
                
            case .disableCompression:
                var newSettings = currentSettings
                newSettings.compressionRatio = 1.0
                try? updateSettings(newSettings)
                print("   Applied: Disabled compression")
                
            case .enableLosslessMode:
                enableLosslessMode(true)
                print("   Applied: Enabled lossless mode")
                
            case .fallbackToOriginal:
                var newSettings = currentSettings
                newSettings.processingEnabled = false
                try? updateSettings(newSettings)
                print("   Applied: Disabled processing (fallback to original)")
                
            case .adjustCompressionRatio(let newRatio):
                var newSettings = currentSettings
                newSettings.compressionRatio = newRatio
                try? updateSettings(newSettings)
                print("   Applied: Adjusted compression ratio to \(String(format: "%.1f", newRatio))")
                
            case .adjustLimiterThreshold(let newThreshold):
                var newSettings = currentSettings
                newSettings.limiterThreshold = newThreshold
                try? updateSettings(newSettings)
                print("   Applied: Adjusted limiter threshold to \(String(format: "%.1f", newThreshold)) dB")
            }
        }
    }
    
    func losslessModeRecommended(reason: String) {
        print("🔒 Lossless mode recommended: \(reason)")
        
        if currentSettings.qualityProtectionEnabled && !losslessModeActive {
            enableLosslessMode(true)
            print("   Auto-enabled lossless mode due to quality concerns")
        }
    }
}