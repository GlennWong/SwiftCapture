import Foundation
import AVFoundation
import Accelerate

/// Real-time audio spectrum analyzer using FFT
class AudioSpectrumAnalyzer {
    
    // MARK: - Properties
    
    /// FFT size (must be power of 2)
    private let fftSize: Int
    
    /// Number of frequency bins in output
    private let binCount: Int
    
    /// Sample rate for frequency calculations
    private var sampleRate: Float = 48000.0
    
    /// FFT setup for vDSP
    private var fftSetup: FFTSetup?
    
    /// Working buffers
    private var fftBuffer: [Float]
    private var windowBuffer: [Float]
    private var magnitudeBuffer: [Float]
    private var smoothedMagnitudes: [Float]
    
    /// Spectrum smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    var smoothingFactor: Float = 0.7
    
    /// Update rate for spectrum calculations
    var updateRate: TimeInterval = 0.1 // 100ms updates
    
    /// Last update timestamp
    private var lastUpdate: Date = Date()
    
    /// Delegate for spectrum updates
    weak var delegate: AudioSpectrumAnalyzerDelegate?
    
    /// Frequency bands for display
    private let frequencyBands: [Float] = [
        31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
    ]
    
    // MARK: - Initialization
    
    /// Initialize spectrum analyzer
    /// - Parameter fftSize: FFT size (default: 1024, must be power of 2)
    init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.binCount = fftSize / 2
        
        // Initialize buffers
        self.fftBuffer = Array(repeating: 0.0, count: fftSize)
        self.windowBuffer = Array(repeating: 0.0, count: fftSize)
        self.magnitudeBuffer = Array(repeating: 0.0, count: binCount)
        self.smoothedMagnitudes = Array(repeating: -80.0, count: binCount)
        
        setupFFT()
        setupWindow()
    }
    
    deinit {
        cleanupFFT()
    }
    
    // MARK: - Public Methods
    
    /// Process audio buffer and update spectrum
    /// - Parameter buffer: Audio buffer to analyze
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0,
              let fftSetup = fftSetup else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Update sample rate if changed
        let bufferSampleRate = Float(buffer.format.sampleRate)
        if bufferSampleRate != sampleRate {
            sampleRate = bufferSampleRate
        }
        
        // Mix channels to mono for spectrum analysis
        var samples: [Float] = []
        
        if channelCount == 1 {
            samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: min(frameCount, fftSize)))
        } else {
            let sampleCount = min(frameCount, fftSize)
            samples = Array(repeating: 0.0, count: sampleCount)
            for frame in 0..<sampleCount {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += floatChannelData[channel][frame]
                }
                samples[frame] = sum / Float(channelCount)
            }
        }
        
        // Only process if we have enough samples
        guard samples.count >= fftSize else { return }
        
        calculateSpectrum(from: samples, setup: fftSetup)
        
        // Notify delegate if enough time has passed
        let now = Date()
        if now.timeIntervalSince(lastUpdate) >= updateRate {
            delegate?.spectrumAnalyzerUpdated(magnitudes: smoothedMagnitudes, frequencies: getFrequencies())
            lastUpdate = now
        }
    }
    
    /// Get current spectrum magnitudes
    /// - Returns: Array of magnitude values in dB
    func getCurrentSpectrum() -> [Float] {
        return smoothedMagnitudes
    }
    
    /// Get frequency values for each bin
    /// - Returns: Array of frequency values in Hz
    func getFrequencies() -> [Float] {
        let nyquist = sampleRate / 2.0
        let binWidth = nyquist / Float(binCount)
        
        return (0..<binCount).map { Float($0) * binWidth }
    }
    
    /// Get spectrum for specific frequency bands
    /// - Returns: Dictionary mapping frequency bands to magnitude values
    func getBandSpectrum() -> [Float: Float] {
        let frequencies = getFrequencies()
        var bandSpectrum: [Float: Float] = [:]
        
        for band in frequencyBands {
            // Find closest frequency bin
            let binIndex = findClosestBin(for: band, in: frequencies)
            if binIndex < smoothedMagnitudes.count {
                bandSpectrum[band] = smoothedMagnitudes[binIndex]
            }
        }
        
        return bandSpectrum
    }
    
    /// Get spectrum as ASCII visualization
    /// - Parameters:
    ///   - width: Width of the visualization
    ///   - height: Height of the visualization
    ///   - useUnicode: Whether to use Unicode characters
    /// - Returns: ASCII spectrum visualization
    func getSpectrumVisualization(width: Int = 40, height: Int = 10, useUnicode: Bool = true) -> String {
        let bandSpectrum = getBandSpectrum()
        let sortedBands = frequencyBands.sorted()
        
        var visualization = ""
        
        // Create visualization from top to bottom
        for row in (0..<height).reversed() {
            let threshold = Float(row) / Float(height - 1) * 60.0 - 80.0 // -80dB to -20dB range
            
            for (_, band) in sortedBands.enumerated() {
                let magnitude = bandSpectrum[band] ?? -80.0
                let barWidth = width / sortedBands.count
                
                for _ in 0..<barWidth {
                    if magnitude > threshold {
                        visualization += useUnicode ? "█" : "#"
                    } else {
                        visualization += " "
                    }
                }
            }
            
            if row > 0 {
                visualization += "\n"
            }
        }
        
        // Add frequency labels
        visualization += "\n"
        for (_, band) in sortedBands.enumerated() {
            let barWidth = width / sortedBands.count
            let label = formatFrequency(band)
            let padding = max(0, barWidth - label.count) / 2
            
            visualization += String(repeating: " ", count: padding)
            visualization += label
            visualization += String(repeating: " ", count: barWidth - padding - label.count)
        }
        
        return visualization
    }
    
    /// Reset spectrum analyzer state
    func reset() {
        smoothedMagnitudes = Array(repeating: -80.0, count: binCount)
        lastUpdate = Date()
    }
    
    // MARK: - Private Methods
    
    /// Setup FFT for spectrum analysis
    private func setupFFT() {
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2))
        
        if fftSetup == nil {
            print("⚠️ Failed to setup FFT for spectrum analysis")
        }
    }
    
    /// Setup window function for FFT
    private func setupWindow() {
        // Create Hann window for better frequency resolution
        vDSP_hann_window(&windowBuffer, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }
    
    /// Cleanup FFT resources
    private func cleanupFFT() {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }
    }
    
    /// Calculate spectrum from audio samples
    /// - Parameters:
    ///   - samples: Audio samples to analyze
    ///   - setup: FFT setup
    private func calculateSpectrum(from samples: [Float], setup: FFTSetup) {
        // Copy samples to FFT buffer with zero padding
        fftBuffer = Array(repeating: 0.0, count: fftSize)
        let copyCount = min(samples.count, fftSize)
        for i in 0..<copyCount {
            fftBuffer[i] = samples[i]
        }
        
        // Apply window function
        vDSP_vmul(fftBuffer, 1, windowBuffer, 1, &fftBuffer, 1, vDSP_Length(fftSize))
        
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
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        vDSP_fft_zrip(setup, &complexBuffer, 1, log2Size, FFTDirection(kFFTDirection_Forward))
        
        // Calculate magnitude spectrum
        var newMagnitudes = Array(repeating: Float(0.0), count: halfSize)
        
        for i in 0..<halfSize {
            let magnitude = sqrt(complexBuffer.realp[i] * complexBuffer.realp[i] + complexBuffer.imagp[i] * complexBuffer.imagp[i])
            newMagnitudes[i] = magnitude > 0 ? 20.0 * log10(magnitude) : -80.0
        }
        
        // Apply smoothing
        for i in 0..<halfSize {
            smoothedMagnitudes[i] = newMagnitudes[i] * (1.0 - smoothingFactor) + smoothedMagnitudes[i] * smoothingFactor
        }
    }
    
    /// Find closest frequency bin for a given frequency
    /// - Parameters:
    ///   - frequency: Target frequency in Hz
    ///   - frequencies: Array of bin frequencies
    /// - Returns: Index of closest bin
    private func findClosestBin(for frequency: Float, in frequencies: [Float]) -> Int {
        var closestIndex = 0
        var closestDistance = abs(frequencies[0] - frequency)
        
        for (index, binFreq) in frequencies.enumerated() {
            let distance = abs(binFreq - frequency)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        
        return closestIndex
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
}

// MARK: - AudioSpectrumAnalyzerDelegate

/// Delegate protocol for spectrum analyzer updates
protocol AudioSpectrumAnalyzerDelegate: AnyObject {
    /// Called when spectrum analysis is updated
    /// - Parameters:
    ///   - magnitudes: Array of magnitude values in dB
    ///   - frequencies: Array of corresponding frequencies in Hz
    func spectrumAnalyzerUpdated(magnitudes: [Float], frequencies: [Float])
}