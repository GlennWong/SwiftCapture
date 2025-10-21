import Foundation
import Accelerate
import AVFoundation

/// High-performance DSP operations using vDSP framework optimizations
/// Provides vectorized audio processing operations for maximum performance
class AudioDSPOptimizer {
    
    // MARK: - SIMD-Optimized Buffer Operations
    
    /// Vectorized buffer copying with format conversion
    /// - Parameters:
    ///   - source: Source buffer
    ///   - destination: Destination buffer
    ///   - frameCount: Number of frames to copy
    static func copyBuffer(
        from source: UnsafePointer<Float>,
        to destination: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        // Use vDSP for optimized memory copy
        vDSP_mmov(source, destination, vDSP_Length(frameCount), 1, 1, 1)
    }
    
    /// Vectorized buffer mixing with gain control
    /// - Parameters:
    ///   - buffer1: First input buffer
    ///   - buffer2: Second input buffer
    ///   - output: Output buffer
    ///   - gain1: Gain for first buffer
    ///   - gain2: Gain for second buffer
    ///   - frameCount: Number of frames to process
    static func mixBuffers(
        buffer1: UnsafePointer<Float>,
        buffer2: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        gain1: Float,
        gain2: Float,
        frameCount: Int
    ) {
        let length = vDSP_Length(frameCount)
        
        // Scale first buffer
        vDSP_vsmul(buffer1, 1, [gain1], output, 1, length)
        
        // Scale and add second buffer
        var tempBuffer = [Float](repeating: 0.0, count: frameCount)
        vDSP_vsmul(buffer2, 1, [gain2], &tempBuffer, 1, length)
        vDSP_vadd(output, 1, tempBuffer, 1, output, 1, length)
    }
    
    /// Vectorized stereo to mono conversion
    /// - Parameters:
    ///   - leftChannel: Left channel input
    ///   - rightChannel: Right channel input
    ///   - monoOutput: Mono output buffer
    ///   - frameCount: Number of frames to process
    static func stereoToMono(
        leftChannel: UnsafePointer<Float>,
        rightChannel: UnsafePointer<Float>,
        monoOutput: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let length = vDSP_Length(frameCount)
        let mixGain: Float = 0.5
        
        // Add left and right channels
        vDSP_vadd(leftChannel, 1, rightChannel, 1, monoOutput, 1, length)
        
        // Scale by 0.5 to prevent clipping
        vDSP_vsmul(monoOutput, 1, [mixGain], monoOutput, 1, length)
    }
    
    /// Vectorized mono to stereo duplication
    /// - Parameters:
    ///   - monoInput: Mono input buffer
    ///   - leftChannel: Left channel output
    ///   - rightChannel: Right channel output
    ///   - frameCount: Number of frames to process
    static func monoToStereo(
        monoInput: UnsafePointer<Float>,
        leftChannel: UnsafeMutablePointer<Float>,
        rightChannel: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        let length = vDSP_Length(frameCount)
        
        // Copy mono to both channels
        vDSP_mmov(monoInput, leftChannel, length, 1, 1, 1)
        vDSP_mmov(monoInput, rightChannel, length, 1, 1, 1)
    }
    
    // MARK: - Optimized Audio Analysis
    
    /// High-performance RMS calculation using vDSP
    /// - Parameters:
    ///   - buffer: Audio buffer to analyze
    ///   - frameCount: Number of frames
    /// - Returns: RMS value
    static func calculateRMS(buffer: UnsafePointer<Float>, frameCount: Int) -> Float {
        var rms: Float = 0.0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(frameCount))
        return rms
    }
    
    /// High-performance peak detection using vDSP
    /// - Parameters:
    ///   - buffer: Audio buffer to analyze
    ///   - frameCount: Number of frames
    /// - Returns: Peak absolute value
    static func findPeak(buffer: UnsafePointer<Float>, frameCount: Int) -> Float {
        var peak: Float = 0.0
        vDSP_maxmgv(buffer, 1, &peak, vDSP_Length(frameCount))
        return peak
    }
    
    /// Vectorized DC offset removal
    /// - Parameters:
    ///   - buffer: Audio buffer (modified in place)
    ///   - frameCount: Number of frames
    static func removeDCOffset(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let length = vDSP_Length(frameCount)
        
        // Calculate mean (DC component)
        var mean: Float = 0.0
        vDSP_meanv(buffer, 1, &mean, length)
        
        // Subtract mean from all samples
        var negativeMean = -mean
        vDSP_vsadd(buffer, 1, &negativeMean, buffer, 1, length)
    }
    
    /// Optimized zero-crossing rate calculation
    /// - Parameters:
    ///   - buffer: Audio buffer to analyze
    ///   - frameCount: Number of frames
    /// - Returns: Zero crossing rate (crossings per sample)
    static func calculateZeroCrossingRate(buffer: UnsafePointer<Float>, frameCount: Int) -> Float {
        guard frameCount > 1 else { return 0.0 }
        
        var crossings = 0
        var previousSign = buffer[0] >= 0
        
        // Vectorized sign detection would be complex, so use optimized loop
        for i in 1..<frameCount {
            let currentSign = buffer[i] >= 0
            if currentSign != previousSign {
                crossings += 1
            }
            previousSign = currentSign
        }
        
        return Float(crossings) / Float(frameCount - 1)
    }
    
    // MARK: - Optimized Audio Effects
    
    /// High-performance gain application using vDSP
    /// - Parameters:
    ///   - buffer: Audio buffer (modified in place)
    ///   - gain: Linear gain value
    ///   - frameCount: Number of frames
    static func applyGain(buffer: UnsafeMutablePointer<Float>, gain: Float, frameCount: Int) {
        vDSP_vsmul(buffer, 1, [gain], buffer, 1, vDSP_Length(frameCount))
    }
    
    /// Vectorized soft clipping using vDSP
    /// - Parameters:
    ///   - buffer: Audio buffer (modified in place)
    ///   - threshold: Clipping threshold (0.0 to 1.0)
    ///   - frameCount: Number of frames
    static func applySoftClipping(buffer: UnsafeMutablePointer<Float>, threshold: Float, frameCount: Int) {
        let length = vDSP_Length(frameCount)
        
        // Clamp to threshold range
        var negativeThreshold = -threshold
        var positiveThreshold = threshold
        vDSP_vclip(buffer, 1, &negativeThreshold, &positiveThreshold, buffer, 1, length)
        
        // Apply soft saturation curve for values above threshold
        for i in 0..<frameCount {
            let sample = buffer[i]
            let absSample = abs(sample)
            
            if absSample > threshold {
                let sign: Float = sample >= 0 ? 1.0 : -1.0
                let excess = absSample - threshold
                let softened = threshold + excess / (1.0 + excess / threshold)
                buffer[i] = sign * softened
            }
        }
    }
    
    /// Optimized fade in/out using vDSP
    /// - Parameters:
    ///   - buffer: Audio buffer (modified in place)
    ///   - fadeType: Type of fade (in or out)
    ///   - frameCount: Number of frames
    static func applyFade(buffer: UnsafeMutablePointer<Float>, fadeType: FadeType, frameCount: Int) {
        let length = vDSP_Length(frameCount)
        var ramp = [Float](repeating: 0.0, count: frameCount)
        
        switch fadeType {
        case .fadeIn:
            // Create linear ramp from 0 to 1
            vDSP_vramp([0.0], [1.0], &ramp, 1, length)
        case .fadeOut:
            // Create linear ramp from 1 to 0
            vDSP_vramp([1.0], [0.0], &ramp, 1, length)
        }
        
        // Apply ramp to buffer
        vDSP_vmul(buffer, 1, ramp, 1, buffer, 1, length)
    }
    
    // MARK: - Advanced DSP Operations
    
    /// High-performance convolution using vDSP
    /// - Parameters:
    ///   - signal: Input signal
    ///   - kernel: Convolution kernel (impulse response)
    ///   - output: Output buffer
    ///   - signalLength: Length of input signal
    ///   - kernelLength: Length of kernel
    static func convolve(
        signal: UnsafePointer<Float>,
        kernel: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        signalLength: Int,
        kernelLength: Int
    ) {
        vDSP_conv(
            signal, 1,
            kernel, 1,
            output, 1,
            vDSP_Length(signalLength),
            vDSP_Length(kernelLength)
        )
    }
    
    /// Optimized windowing function application
    /// - Parameters:
    ///   - buffer: Audio buffer (modified in place)
    ///   - windowType: Type of window function
    ///   - frameCount: Number of frames
    static func applyWindow(buffer: UnsafeMutablePointer<Float>, windowType: WindowType, frameCount: Int) {
        let length = vDSP_Length(frameCount)
        var window = [Float](repeating: 0.0, count: frameCount)
        
        switch windowType {
        case .hann:
            vDSP_hann_window(&window, length, Int32(vDSP_HANN_NORM))
        case .hamming:
            vDSP_hamm_window(&window, length, 0)
        case .blackman:
            vDSP_blkman_window(&window, length, 0)
        }
        
        // Apply window to buffer
        vDSP_vmul(buffer, 1, window, 1, buffer, 1, length)
    }
    
    /// High-performance FFT magnitude spectrum calculation
    /// - Parameters:
    ///   - input: Input audio buffer
    ///   - output: Output magnitude spectrum
    ///   - fftSize: FFT size (must be power of 2)
    /// - Returns: Success status
    static func calculateMagnitudeSpectrum(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        fftSize: Int
    ) -> Bool {
        guard fftSize > 0 && (fftSize & (fftSize - 1)) == 0 else {
            return false // FFT size must be power of 2
        }
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return false
        }
        
        defer {
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        let halfSize = fftSize / 2
        
        // Allocate complex buffer
        var realPart = [Float](repeating: 0.0, count: halfSize)
        var imagPart = [Float](repeating: 0.0, count: halfSize)
        
        return realPart.withUnsafeMutableBufferPointer { realPtr in
            return imagPart.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBaseAddress = realPtr.baseAddress,
                      let imagBaseAddress = imagPtr.baseAddress else {
                    return false
                }
                
                var complexBuffer = DSPSplitComplex(realp: realBaseAddress, imagp: imagBaseAddress)
                
                // Convert real input to complex format
                input.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexInput in
                    vDSP_ctoz(complexInput, 2, &complexBuffer, 1, vDSP_Length(halfSize))
                }
                
                // Perform FFT
                vDSP_fft_zrip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(kFFTDirection_Forward))
                
                // Calculate magnitude
                vDSP_zvmags(&complexBuffer, 1, output, 1, vDSP_Length(halfSize))
                
                // Convert to dB scale
                var one: Float = 1.0
                vDSP_vdbcon(output, 1, &one, output, 1, vDSP_Length(halfSize), 1)
                
                return true
            }
        }
    }
    
    // MARK: - Memory-Optimized Operations
    
    /// In-place buffer operations to minimize memory allocations
    struct InPlaceOperations {
        
        /// Normalize buffer to prevent clipping
        /// - Parameters:
        ///   - buffer: Audio buffer (modified in place)
        ///   - frameCount: Number of frames
        ///   - targetPeak: Target peak level (0.0 to 1.0)
        static func normalize(buffer: UnsafeMutablePointer<Float>, frameCount: Int, targetPeak: Float = 0.95) {
            // Find current peak
            var currentPeak: Float = 0.0
            vDSP_maxmgv(buffer, 1, &currentPeak, vDSP_Length(frameCount))
            
            // Calculate normalization gain
            if currentPeak > 0.0 {
                let gain = targetPeak / currentPeak
                vDSP_vsmul(buffer, 1, [gain], buffer, 1, vDSP_Length(frameCount))
            }
        }
        
        /// Apply high-pass filter in place
        /// - Parameters:
        ///   - buffer: Audio buffer (modified in place)
        ///   - frameCount: Number of frames
        ///   - cutoffFreq: Cutoff frequency (normalized 0.0 to 1.0)
        static func highPassFilter(buffer: UnsafeMutablePointer<Float>, frameCount: Int, cutoffFreq: Float) {
            // Simple first-order high-pass filter
            let alpha = cutoffFreq
            var previousSample: Float = 0.0
            var previousOutput: Float = 0.0
            
            for i in 0..<frameCount {
                let currentSample = buffer[i]
                let output = alpha * (previousOutput + currentSample - previousSample)
                buffer[i] = output
                
                previousSample = currentSample
                previousOutput = output
            }
        }
        
        /// Apply low-pass filter in place
        /// - Parameters:
        ///   - buffer: Audio buffer (modified in place)
        ///   - frameCount: Number of frames
        ///   - cutoffFreq: Cutoff frequency (normalized 0.0 to 1.0)
        static func lowPassFilter(buffer: UnsafeMutablePointer<Float>, frameCount: Int, cutoffFreq: Float) {
            // Simple first-order low-pass filter
            let alpha = cutoffFreq
            var previousOutput: Float = 0.0
            
            for i in 0..<frameCount {
                let output = alpha * buffer[i] + (1.0 - alpha) * previousOutput
                buffer[i] = output
                previousOutput = output
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    /// Measure performance of DSP operations
    /// - Parameter operation: DSP operation to measure
    /// - Returns: Execution time in microseconds
    static func measurePerformance<T>(operation: () throws -> T) rethrows -> (result: T, microseconds: Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let microseconds = (endTime - startTime) * 1_000_000
        return (result, microseconds)
    }
    
    /// Benchmark common DSP operations
    /// - Parameter frameCount: Number of frames to test with
    /// - Returns: Performance benchmark results
    static func benchmarkOperations(frameCount: Int = 1024) -> [String: Double] {
        var results: [String: Double] = [:]
        
        // Create test buffers
        let inputBuffer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let outputBuffer = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        
        defer {
            inputBuffer.deallocate()
            outputBuffer.deallocate()
        }
        
        // Initialize with test data
        for i in 0..<frameCount {
            inputBuffer[i] = sin(Float(i) * 0.1) * 0.5
        }
        
        // Benchmark RMS calculation
        let (_, rmsTime) = measurePerformance {
            return calculateRMS(buffer: inputBuffer, frameCount: frameCount)
        }
        results["RMS"] = rmsTime
        
        // Benchmark peak detection
        let (_, peakTime) = measurePerformance {
            return findPeak(buffer: inputBuffer, frameCount: frameCount)
        }
        results["Peak"] = peakTime
        
        // Benchmark gain application
        let (_, gainTime) = measurePerformance {
            applyGain(buffer: inputBuffer, gain: 1.5, frameCount: frameCount)
        }
        results["Gain"] = gainTime
        
        // Benchmark DC offset removal
        let (_, dcTime) = measurePerformance {
            removeDCOffset(buffer: inputBuffer, frameCount: frameCount)
        }
        results["DC_Removal"] = dcTime
        
        return results
    }
}

// MARK: - Supporting Types

enum FadeType {
    case fadeIn
    case fadeOut
}

enum WindowType {
    case hann
    case hamming
    case blackman
}

// MARK: - Extensions for AVAudioPCMBuffer

extension AVAudioPCMBuffer {
    
    /// Apply optimized DSP operations to buffer
    /// - Parameter operation: DSP operation to apply
    func applyDSPOperation(_ operation: (UnsafeMutablePointer<Float>, Int) -> Void) {
        guard let floatChannelData = floatChannelData else { return }
        
        let frameCount = Int(frameLength)
        let channelCount = Int(format.channelCount)
        
        for channel in 0..<channelCount {
            operation(floatChannelData[channel], frameCount)
        }
    }
    
    /// Get optimized RMS level for all channels
    /// - Returns: RMS level in dB
    func getOptimizedRMSLevel() -> Float {
        guard let floatChannelData = floatChannelData, frameLength > 0 else {
            return -Float.infinity
        }
        
        let frameCount = Int(frameLength)
        let channelCount = Int(format.channelCount)
        var totalRMS: Float = 0.0
        
        for channel in 0..<channelCount {
            let rms = AudioDSPOptimizer.calculateRMS(buffer: floatChannelData[channel], frameCount: frameCount)
            totalRMS += rms * rms
        }
        
        let avgRMS = sqrt(totalRMS / Float(channelCount))
        return avgRMS > 0 ? 20.0 * log10(avgRMS) : -Float.infinity
    }
    
    /// Get optimized peak level for all channels
    /// - Returns: Peak level in dB
    func getOptimizedPeakLevel() -> Float {
        guard let floatChannelData = floatChannelData, frameLength > 0 else {
            return -Float.infinity
        }
        
        let frameCount = Int(frameLength)
        let channelCount = Int(format.channelCount)
        var maxPeak: Float = 0.0
        
        for channel in 0..<channelCount {
            let peak = AudioDSPOptimizer.findPeak(buffer: floatChannelData[channel], frameCount: frameCount)
            maxPeak = max(maxPeak, peak)
        }
        
        return maxPeak > 0 ? 20.0 * log10(maxPeak) : -Float.infinity
    }
}