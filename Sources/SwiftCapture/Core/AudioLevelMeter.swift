import Foundation
import AVFoundation
import Accelerate

/// Real-time audio level meter for monitoring peak and RMS levels
class AudioLevelMeter {
    
    // MARK: - Properties
    
    /// Current peak level in dBFS
    private(set) var peakLevel: Float = -Float.infinity
    
    /// Current RMS level in dBFS  
    private(set) var rmsLevel: Float = -Float.infinity
    
    /// Peak hold time in seconds
    var peakHoldTime: TimeInterval = 2.0
    
    /// Update rate for level calculations
    var updateRate: TimeInterval = 0.05 // 50ms updates
    
    /// Peak history for hold functionality
    private var peakHistory: [(level: Float, timestamp: Date)] = []
    
    /// RMS smoothing buffer
    private var rmsBuffer: [Float] = []
    private let rmsBufferSize: Int = 10
    
    /// Last update timestamp
    private var lastUpdate: Date = Date()
    
    /// Delegate for level updates
    weak var delegate: AudioLevelMeterDelegate?
    
    // MARK: - Initialization
    
    init() {
        reset()
    }
    
    // MARK: - Public Methods
    
    /// Process audio buffer and update levels
    /// - Parameter buffer: Audio buffer to analyze
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Mix channels to mono for level calculation
        var samples: [Float] = []
        
        if channelCount == 1 {
            samples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameCount))
        } else {
            samples = Array(repeating: 0.0, count: frameCount)
            for frame in 0..<frameCount {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += floatChannelData[channel][frame]
                }
                samples[frame] = sum / Float(channelCount)
            }
        }
        
        updateLevels(from: samples)
    }
    
    /// Get current levels as a formatted string
    /// - Returns: Human-readable level information
    func getLevelsDescription() -> String {
        let peakStr = peakLevel == -Float.infinity ? "Silent" : String(format: "%.1f dBFS", peakLevel)
        let rmsStr = rmsLevel == -Float.infinity ? "Silent" : String(format: "%.1f dBFS", rmsLevel)
        
        return "Peak: \(peakStr) | RMS: \(rmsStr)"
    }
    
    /// Get level bar representation
    /// - Parameters:
    ///   - width: Width of the bar in characters
    ///   - useUnicode: Whether to use Unicode block characters
    /// - Returns: Visual level bar
    func getLevelBar(width: Int = 20, useUnicode: Bool = true) -> String {
        let peakNormalized = normalizeLevel(peakLevel)
        let rmsNormalized = normalizeLevel(rmsLevel)
        
        let peakPos = Int(peakNormalized * Float(width))
        let rmsPos = Int(rmsNormalized * Float(width))
        
        var bar = ""
        
        if useUnicode {
            // Use Unicode block characters for better visual representation
            for i in 0..<width {
                if i < rmsPos {
                    bar += "█" // Full block for RMS
                } else if i < peakPos {
                    bar += "▓" // Medium shade for peak
                } else {
                    bar += "░" // Light shade for background
                }
            }
        } else {
            // ASCII fallback
            for i in 0..<width {
                if i < rmsPos {
                    bar += "#"
                } else if i < peakPos {
                    bar += "-"
                } else {
                    bar += " "
                }
            }
        }
        
        return "[\(bar)]"
    }
    
    /// Reset level meter state
    func reset() {
        peakLevel = -Float.infinity
        rmsLevel = -Float.infinity
        peakHistory.removeAll()
        rmsBuffer.removeAll()
        lastUpdate = Date()
    }
    
    // MARK: - Private Methods
    
    /// Update levels from audio samples
    /// - Parameter samples: Audio samples to analyze
    private func updateLevels(from samples: [Float]) {
        guard !samples.isEmpty else { return }
        
        let now = Date()
        
        // Calculate peak level
        var currentPeak: Float = 0.0
        vDSP_maxmgv(samples, 1, &currentPeak, vDSP_Length(samples.count))
        let currentPeakdB = currentPeak > 0 ? 20.0 * log10(currentPeak) : -Float.infinity
        
        // Update peak with hold
        updatePeakWithHold(currentPeakdB, timestamp: now)
        
        // Calculate RMS level
        var rms: Float = 0.0
        var sumSquares: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        rms = sqrt(sumSquares / Float(samples.count))
        let currentRMSdB = rms > 0 ? 20.0 * log10(rms) : -Float.infinity
        
        // Smooth RMS level
        updateRMSWithSmoothing(currentRMSdB)
        
        // Notify delegate if enough time has passed
        if now.timeIntervalSince(lastUpdate) >= updateRate {
            delegate?.levelMeterUpdated(peak: peakLevel, rms: rmsLevel)
            lastUpdate = now
        }
    }
    
    /// Update peak level with hold functionality
    /// - Parameters:
    ///   - newPeak: New peak level in dB
    ///   - timestamp: Timestamp of the measurement
    private func updatePeakWithHold(_ newPeak: Float, timestamp: Date) {
        // Add new peak to history
        if newPeak > -Float.infinity {
            peakHistory.append((level: newPeak, timestamp: timestamp))
        }
        
        // Remove old peaks outside hold time
        peakHistory = peakHistory.filter { 
            timestamp.timeIntervalSince($0.timestamp) <= peakHoldTime 
        }
        
        // Find maximum peak in history
        if let maxPeak = peakHistory.max(by: { $0.level < $1.level }) {
            peakLevel = maxPeak.level
        } else {
            peakLevel = newPeak
        }
    }
    
    /// Update RMS level with smoothing
    /// - Parameter newRMS: New RMS level in dB
    private func updateRMSWithSmoothing(_ newRMS: Float) {
        guard newRMS > -Float.infinity else {
            rmsLevel = newRMS
            return
        }
        
        // Add to smoothing buffer
        rmsBuffer.append(newRMS)
        if rmsBuffer.count > rmsBufferSize {
            rmsBuffer.removeFirst()
        }
        
        // Calculate smoothed RMS
        let validSamples = rmsBuffer.filter { $0 > -Float.infinity }
        if !validSamples.isEmpty {
            rmsLevel = validSamples.reduce(0, +) / Float(validSamples.count)
        } else {
            rmsLevel = newRMS
        }
    }
    
    /// Normalize level from dB to 0.0-1.0 range for visualization
    /// - Parameter levelDB: Level in dB
    /// - Returns: Normalized level (0.0 = -60dB, 1.0 = 0dB)
    private func normalizeLevel(_ levelDB: Float) -> Float {
        guard levelDB > -Float.infinity else { return 0.0 }
        
        let minDB: Float = -60.0
        let maxDB: Float = 0.0
        
        let normalized = (levelDB - minDB) / (maxDB - minDB)
        return max(0.0, min(1.0, normalized))
    }
}

// MARK: - AudioLevelMeterDelegate

/// Delegate protocol for audio level meter updates
protocol AudioLevelMeterDelegate: AnyObject {
    /// Called when audio levels are updated
    /// - Parameters:
    ///   - peak: Current peak level in dBFS
    ///   - rms: Current RMS level in dBFS
    func levelMeterUpdated(peak: Float, rms: Float)
}