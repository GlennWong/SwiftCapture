import Foundation
import AVFoundation
import Accelerate

/// High-performance audio buffer pool manager for efficient memory management
/// Provides object pooling, buffer reuse, and memory optimization for real-time audio processing
class AudioBufferPool {
    
    // MARK: - Buffer Pool Configuration
    
    /// Configuration for buffer pool behavior
    struct PoolConfiguration {
        let maxBufferCount: Int
        let bufferCapacity: AVAudioFrameCount
        let channelCount: Int
        let sampleRate: Double
        let preallocationCount: Int
        let enableMemoryWarnings: Bool
        let maxMemoryUsageMB: Int
        
        static let `default` = PoolConfiguration(
            maxBufferCount: 32,
            bufferCapacity: 1024,
            channelCount: 2,
            sampleRate: 48000.0,
            preallocationCount: 8,
            enableMemoryWarnings: true,
            maxMemoryUsageMB: 50
        )
        
        static func optimized(for sampleRate: Double, channelCount: Int) -> PoolConfiguration {
            let bufferCapacity: AVAudioFrameCount = sampleRate > 44100 ? 1024 : 512
            let maxBuffers = channelCount > 2 ? 24 : 32
            
            return PoolConfiguration(
                maxBufferCount: maxBuffers,
                bufferCapacity: bufferCapacity,
                channelCount: channelCount,
                sampleRate: sampleRate,
                preallocationCount: maxBuffers / 4,
                enableMemoryWarnings: true,
                maxMemoryUsageMB: channelCount > 2 ? 75 : 50
            )
        }
    }
    
    // MARK: - Properties
    
    private let configuration: PoolConfiguration
    private let audioFormat: AVAudioFormat
    private var availableBuffers: [AVAudioPCMBuffer] = []
    private var usedBuffers: Set<ObjectIdentifier> = []
    private let poolQueue = DispatchQueue(label: "com.swiftcapture.audiobufferpool", qos: .userInteractive)
    
    // Memory tracking
    private var totalAllocatedBuffers: Int = 0
    private var peakBufferUsage: Int = 0
    private var memoryPressureDetected: Bool = false
    
    // Performance metrics
    private var poolHits: Int = 0
    private var poolMisses: Int = 0
    private var bufferReallocations: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize buffer pool with configuration
    /// - Parameter config: Pool configuration
    /// - Throws: AudioBufferPoolError if initialization fails
    init(configuration: PoolConfiguration = .default) throws {
        self.configuration = configuration
        
        // Create audio format
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: configuration.sampleRate,
            channels: AVAudioChannelCount(configuration.channelCount)
        ) else {
            throw AudioBufferPoolError.formatCreationFailed
        }
        
        self.audioFormat = format
        
        // Pre-allocate buffers
        try preallocateBuffers()
        
        // Setup memory pressure monitoring
        if configuration.enableMemoryWarnings {
            setupMemoryPressureMonitoring()
        }
        
        print("🏊‍♂️ AudioBufferPool initialized:")
        print("   Format: \(Int(configuration.sampleRate))Hz, \(configuration.channelCount)ch")
        print("   Buffer Capacity: \(configuration.bufferCapacity) frames")
        print("   Max Buffers: \(configuration.maxBufferCount)")
        print("   Pre-allocated: \(configuration.preallocationCount)")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Get a buffer from the pool or create a new one
    /// - Returns: Reusable audio buffer
    /// - Throws: AudioBufferPoolError if buffer cannot be obtained
    func getBuffer() throws -> AVAudioPCMBuffer {
        return try poolQueue.sync {
            // Try to reuse an existing buffer
            if let buffer = availableBuffers.popLast() {
                // Reset buffer state
                buffer.frameLength = 0
                
                // Track usage
                usedBuffers.insert(ObjectIdentifier(buffer))
                poolHits += 1
                
                return buffer
            }
            
            // Create new buffer if under limit
            guard totalAllocatedBuffers < configuration.maxBufferCount else {
                throw AudioBufferPoolError.poolExhausted
            }
            
            guard let newBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFormat,
                frameCapacity: configuration.bufferCapacity
            ) else {
                throw AudioBufferPoolError.bufferAllocationFailed
            }
            
            // Track allocation
            totalAllocatedBuffers += 1
            peakBufferUsage = max(peakBufferUsage, totalAllocatedBuffers)
            usedBuffers.insert(ObjectIdentifier(newBuffer))
            poolMisses += 1
            
            return newBuffer
        }
    }
    
    /// Return a buffer to the pool for reuse
    /// - Parameter buffer: Buffer to return to pool
    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        poolQueue.async { [weak self] in
            guard let self = self else { return }
            
            let bufferID = ObjectIdentifier(buffer)
            
            // Only accept buffers that were issued by this pool
            guard self.usedBuffers.contains(bufferID) else {
                return
            }
            
            // Remove from used set
            self.usedBuffers.remove(bufferID)
            
            // Check if we should keep this buffer or release it
            if self.availableBuffers.count < self.configuration.maxBufferCount / 2 && 
               !self.memoryPressureDetected {
                // Return to pool for reuse
                self.availableBuffers.append(buffer)
            } else {
                // Release buffer to reduce memory pressure
                self.totalAllocatedBuffers -= 1
            }
        }
    }
    
    /// Get buffer pool statistics
    /// - Returns: Dictionary with pool performance metrics
    func getPoolStatistics() -> [String: Any] {
        return poolQueue.sync {
            let hitRate = poolHits + poolMisses > 0 ? 
                Float(poolHits) / Float(poolHits + poolMisses) : 0.0
            
            let estimatedMemoryMB = Float(totalAllocatedBuffers * Int(configuration.bufferCapacity) * 
                                        configuration.channelCount * MemoryLayout<Float>.size) / (1024 * 1024)
            
            return [
                "totalAllocatedBuffers": totalAllocatedBuffers,
                "availableBuffers": availableBuffers.count,
                "usedBuffers": usedBuffers.count,
                "peakBufferUsage": peakBufferUsage,
                "poolHits": poolHits,
                "poolMisses": poolMisses,
                "hitRate": hitRate,
                "bufferReallocations": bufferReallocations,
                "estimatedMemoryMB": estimatedMemoryMB,
                "memoryPressureDetected": memoryPressureDetected
            ]
        }
    }
    
    /// Force cleanup of unused buffers to reduce memory usage
    func compactPool() {
        poolQueue.async { [weak self] in
            guard let self = self else { return }
            
            let _ = self.availableBuffers.count
            
            // Keep only essential buffers
            let keepCount = max(2, self.configuration.preallocationCount / 2)
            if self.availableBuffers.count > keepCount {
                let removeCount = self.availableBuffers.count - keepCount
                self.availableBuffers.removeLast(removeCount)
                self.totalAllocatedBuffers -= removeCount
                
                print("🧹 Buffer pool compacted: removed \(removeCount) buffers")
            }
        }
    }
    
    /// Reset pool statistics
    func resetStatistics() {
        poolQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.poolHits = 0
            self.poolMisses = 0
            self.bufferReallocations = 0
            self.peakBufferUsage = self.totalAllocatedBuffers
        }
    }
    
    /// Get formatted statistics description
    /// - Returns: Human-readable statistics string
    func getStatisticsDescription() -> String {
        let stats = getPoolStatistics()
        
        let hitRate = stats["hitRate"] as? Float ?? 0.0
        let memoryMB = stats["estimatedMemoryMB"] as? Float ?? 0.0
        let allocated = stats["totalAllocatedBuffers"] as? Int ?? 0
        let available = stats["availableBuffers"] as? Int ?? 0
        let used = stats["usedBuffers"] as? Int ?? 0
        
        return """
        🏊‍♂️ Buffer Pool Statistics:
           Allocated: \(allocated) | Available: \(available) | Used: \(used)
           Hit Rate: \(String(format: "%.1f", hitRate * 100))% | Memory: \(String(format: "%.1f", memoryMB)) MB
           Pressure: \(memoryPressureDetected ? "⚠️ YES" : "✅ NO")
        """
    }
    
    // MARK: - Private Methods
    
    /// Pre-allocate buffers for better performance
    /// - Throws: AudioBufferPoolError if preallocation fails
    private func preallocateBuffers() throws {
        for _ in 0..<configuration.preallocationCount {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFormat,
                frameCapacity: configuration.bufferCapacity
            ) else {
                throw AudioBufferPoolError.bufferAllocationFailed
            }
            
            availableBuffers.append(buffer)
            totalAllocatedBuffers += 1
        }
    }
    
    /// Setup memory pressure monitoring
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: poolQueue)
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = source.mask
            
            if event.contains(.warning) || event.contains(.critical) {
                self.memoryPressureDetected = true
                self.handleMemoryPressure(critical: event.contains(.critical))
            } else if event.contains(.normal) {
                self.memoryPressureDetected = false
            }
        }
        
        source.resume()
    }
    
    /// Handle memory pressure by reducing buffer pool size
    /// - Parameter critical: Whether this is critical memory pressure
    private func handleMemoryPressure(critical: Bool) {
        let reductionFactor: Float = critical ? 0.25 : 0.5 // Keep 25% or 50% of buffers
        let targetCount = Int(Float(availableBuffers.count) * reductionFactor)
        
        if availableBuffers.count > targetCount {
            let removeCount = availableBuffers.count - targetCount
            availableBuffers.removeLast(removeCount)
            totalAllocatedBuffers -= removeCount
            
            print("⚠️ Memory pressure detected - reduced buffer pool by \(removeCount) buffers")
        }
    }
    
    /// Cleanup all resources
    private func cleanup() {
        poolQueue.sync {
            availableBuffers.removeAll()
            usedBuffers.removeAll()
            totalAllocatedBuffers = 0
        }
    }
}

// MARK: - Error Types

enum AudioBufferPoolError: LocalizedError {
    case formatCreationFailed
    case bufferAllocationFailed
    case poolExhausted
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return "Failed to create audio format for buffer pool"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .poolExhausted:
            return "Buffer pool exhausted - maximum buffer count reached"
        case .invalidConfiguration:
            return "Invalid buffer pool configuration"
        }
    }
}

// MARK: - Convenience Extensions

extension AudioBufferPool {
    
    /// Create a buffer pool optimized for real-time audio processing
    /// - Parameters:
    ///   - sampleRate: Audio sample rate
    ///   - channelCount: Number of audio channels
    ///   - latencyOptimized: Whether to optimize for low latency
    /// - Returns: Configured buffer pool
    /// - Throws: AudioBufferPoolError if creation fails
    static func realTimePool(
        sampleRate: Double,
        channelCount: Int,
        latencyOptimized: Bool = true
    ) throws -> AudioBufferPool {
        let bufferCapacity: AVAudioFrameCount = latencyOptimized ? 512 : 1024
        let maxBuffers = latencyOptimized ? 16 : 32
        
        let config = PoolConfiguration(
            maxBufferCount: maxBuffers,
            bufferCapacity: bufferCapacity,
            channelCount: channelCount,
            sampleRate: sampleRate,
            preallocationCount: maxBuffers / 4,
            enableMemoryWarnings: true,
            maxMemoryUsageMB: 25
        )
        
        return try AudioBufferPool(configuration: config)
    }
    
    /// Create a buffer pool optimized for high-quality processing
    /// - Parameters:
    ///   - sampleRate: Audio sample rate
    ///   - channelCount: Number of audio channels
    /// - Returns: Configured buffer pool
    /// - Throws: AudioBufferPoolError if creation fails
    static func highQualityPool(
        sampleRate: Double,
        channelCount: Int
    ) throws -> AudioBufferPool {
        let config = PoolConfiguration(
            maxBufferCount: 48,
            bufferCapacity: 2048,
            channelCount: channelCount,
            sampleRate: sampleRate,
            preallocationCount: 12,
            enableMemoryWarnings: true,
            maxMemoryUsageMB: 100
        )
        
        return try AudioBufferPool(configuration: config)
    }
}