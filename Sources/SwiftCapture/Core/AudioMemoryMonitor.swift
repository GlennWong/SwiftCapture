import Foundation
import os.log

/// Monitors and optimizes memory usage for audio processing components
/// Provides real-time memory tracking, leak detection, and optimization recommendations
class AudioMemoryMonitor {
    
    // MARK: - Memory Tracking Configuration
    
    struct MonitoringConfiguration {
        let enableRealTimeTracking: Bool
        let memoryWarningThresholdMB: Int
        let criticalMemoryThresholdMB: Int
        let trackingIntervalSeconds: TimeInterval
        let enableLeakDetection: Bool
        let maxHistoryEntries: Int
        let enableAutomaticCleanup: Bool
        
        static let `default` = MonitoringConfiguration(
            enableRealTimeTracking: true,
            memoryWarningThresholdMB: 100,
            criticalMemoryThresholdMB: 200,
            trackingIntervalSeconds: 1.0,
            enableLeakDetection: true,
            maxHistoryEntries: 300,
            enableAutomaticCleanup: true
        )
        
        static let performance = MonitoringConfiguration(
            enableRealTimeTracking: true,
            memoryWarningThresholdMB: 50,
            criticalMemoryThresholdMB: 100,
            trackingIntervalSeconds: 0.5,
            enableLeakDetection: true,
            maxHistoryEntries: 600,
            enableAutomaticCleanup: true
        )
    }
    
    // MARK: - Memory Statistics
    
    struct MemoryStatistics {
        let timestamp: Date
        let totalMemoryMB: Double
        let audioProcessingMemoryMB: Double
        let bufferPoolMemoryMB: Double
        let systemMemoryPressure: MemoryPressureLevel
        let memoryGrowthRate: Double // MB per second
        let peakMemoryMB: Double
        let averageMemoryMB: Double
        
        var description: String {
            return """
            📊 Memory Statistics (\(DateFormatter.memoryTimeFormatter.string(from: timestamp))):
               Total: \(String(format: "%.1f", totalMemoryMB)) MB | Audio: \(String(format: "%.1f", audioProcessingMemoryMB)) MB
               Buffers: \(String(format: "%.1f", bufferPoolMemoryMB)) MB | Peak: \(String(format: "%.1f", peakMemoryMB)) MB
               Growth Rate: \(String(format: "%.2f", memoryGrowthRate)) MB/s | Pressure: \(systemMemoryPressure.description)
            """
        }
    }
    
    enum MemoryPressureLevel: String, CustomStringConvertible {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        
        var description: String { rawValue }
    }
    
    // MARK: - Memory Event Types
    
    enum MemoryEvent {
        case memoryWarning(currentMB: Double)
        case criticalMemory(currentMB: Double)
        case memoryLeak(component: String, leakMB: Double)
        case memoryOptimized(savedMB: Double)
        case bufferPoolExpanded(newSizeMB: Double)
        case bufferPoolCompacted(freedMB: Double)
        case automaticCleanup(freedMB: Double)
        
        var severity: Float {
            switch self {
            case .memoryWarning: return 0.6
            case .criticalMemory: return 0.9
            case .memoryLeak: return 0.8
            case .memoryOptimized: return 0.2
            case .bufferPoolExpanded: return 0.3
            case .bufferPoolCompacted: return 0.2
            case .automaticCleanup: return 0.2
            }
        }
        
        var description: String {
            switch self {
            case .memoryWarning(let mb):
                return "Memory usage warning: \(String(format: "%.1f", mb)) MB"
            case .criticalMemory(let mb):
                return "Critical memory usage: \(String(format: "%.1f", mb)) MB"
            case .memoryLeak(let component, let leak):
                return "Memory leak detected in \(component): \(String(format: "%.1f", leak)) MB"
            case .memoryOptimized(let saved):
                return "Memory optimized: saved \(String(format: "%.1f", saved)) MB"
            case .bufferPoolExpanded(let size):
                return "Buffer pool expanded to \(String(format: "%.1f", size)) MB"
            case .bufferPoolCompacted(let freed):
                return "Buffer pool compacted: freed \(String(format: "%.1f", freed)) MB"
            case .automaticCleanup(let freed):
                return "Automatic cleanup: freed \(String(format: "%.1f", freed)) MB"
            }
        }
    }
    
    // MARK: - Properties
    
    private let configuration: MonitoringConfiguration
    private var memoryHistory: [MemoryStatistics] = []
    private var memoryEvents: [MemoryEvent] = []
    private var monitoringTimer: Timer?
    private let monitoringQueue = DispatchQueue(label: "com.swiftcapture.memorymonitor", qos: .utility)
    
    // Component memory tracking
    private var componentMemoryUsage: [String: Double] = [:]
    private var bufferPoolReferences: [WeakReference<AudioBufferPool>] = []
    
    // Memory pressure monitoring
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var currentMemoryPressure: MemoryPressureLevel = .normal
    
    // Leak detection
    private var baselineMemory: Double = 0.0
    private var leakDetectionEnabled: Bool = false
    private var lastLeakCheck: Date = Date()
    
    // Callbacks
    var onMemoryWarning: ((Double) -> Void)?
    var onCriticalMemory: ((Double) -> Void)?
    var onMemoryLeak: ((String, Double) -> Void)?
    var onMemoryOptimized: ((Double) -> Void)?
    
    // MARK: - Initialization
    
    init(configuration: MonitoringConfiguration = .default) {
        self.configuration = configuration
        
        if configuration.enableRealTimeTracking {
            startRealTimeMonitoring()
        }
        
        setupMemoryPressureMonitoring()
        
        // Establish baseline memory usage
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.establishBaseline()
        }
        
        print("🧠 AudioMemoryMonitor initialized:")
        print("   Warning Threshold: \(configuration.memoryWarningThresholdMB) MB")
        print("   Critical Threshold: \(configuration.criticalMemoryThresholdMB) MB")
        print("   Tracking Interval: \(configuration.trackingIntervalSeconds)s")
        print("   Leak Detection: \(configuration.enableLeakDetection ? "enabled" : "disabled")")
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start memory monitoring
    func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        startRealTimeMonitoring()
        print("🔍 Memory monitoring started")
    }
    
    /// Stop memory monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        
        print("⏹️ Memory monitoring stopped")
    }
    
    /// Register a buffer pool for monitoring
    /// - Parameter bufferPool: Buffer pool to monitor
    func registerBufferPool(_ bufferPool: AudioBufferPool) {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Clean up dead references
            self.bufferPoolReferences = self.bufferPoolReferences.filter { $0.value != nil }
            
            // Add new reference
            self.bufferPoolReferences.append(WeakReference(bufferPool))
            
            print("📝 Registered buffer pool for memory monitoring")
        }
    }
    
    /// Track memory usage for a specific component
    /// - Parameters:
    ///   - component: Component name
    ///   - memoryMB: Memory usage in MB
    func trackComponentMemory(component: String, memoryMB: Double) {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            
            let previousUsage = self.componentMemoryUsage[component] ?? 0.0
            self.componentMemoryUsage[component] = memoryMB
            
            // Check for significant memory increase (potential leak)
            if self.configuration.enableLeakDetection && memoryMB > previousUsage + 10.0 {
                let leak = memoryMB - previousUsage
                self.recordMemoryEvent(.memoryLeak(component: component, leakMB: leak))
                self.onMemoryLeak?(component, leak)
            }
        }
    }
    
    /// Get current memory statistics
    /// - Returns: Current memory statistics
    func getCurrentMemoryStatistics() -> MemoryStatistics {
        let totalMemory = getCurrentMemoryUsage()
        let audioMemory = getAudioProcessingMemory()
        let bufferMemory = getBufferPoolMemory()
        let growthRate = calculateMemoryGrowthRate()
        let peakMemory = memoryHistory.map { $0.totalMemoryMB }.max() ?? totalMemory
        let avgMemory = memoryHistory.isEmpty ? totalMemory : 
            memoryHistory.map { $0.totalMemoryMB }.reduce(0, +) / Double(memoryHistory.count)
        
        return MemoryStatistics(
            timestamp: Date(),
            totalMemoryMB: totalMemory,
            audioProcessingMemoryMB: audioMemory,
            bufferPoolMemoryMB: bufferMemory,
            systemMemoryPressure: currentMemoryPressure,
            memoryGrowthRate: growthRate,
            peakMemoryMB: peakMemory,
            averageMemoryMB: avgMemory
        )
    }
    
    /// Get memory usage history
    /// - Parameter limit: Maximum number of entries to return
    /// - Returns: Array of memory statistics
    func getMemoryHistory(limit: Int = 100) -> [MemoryStatistics] {
        return monitoringQueue.sync {
            return Array(memoryHistory.suffix(limit))
        }
    }
    
    /// Get memory events history
    /// - Parameter limit: Maximum number of events to return
    /// - Returns: Array of memory events
    func getMemoryEvents(limit: Int = 50) -> [MemoryEvent] {
        return monitoringQueue.sync {
            return Array(memoryEvents.suffix(limit))
        }
    }
    
    /// Force memory optimization
    /// - Returns: Amount of memory freed in MB
    @discardableResult
    func optimizeMemory() -> Double {
        var totalFreed: Double = 0.0
        
        // Compact buffer pools
        for reference in bufferPoolReferences {
            if let bufferPool = reference.value {
                let beforeStats = bufferPool.getPoolStatistics()
                let beforeMemory = beforeStats["estimatedMemoryMB"] as? Float ?? 0.0
                
                bufferPool.compactPool()
                
                let afterStats = bufferPool.getPoolStatistics()
                let afterMemory = afterStats["estimatedMemoryMB"] as? Float ?? 0.0
                
                let freed = Double(beforeMemory - afterMemory)
                if freed > 0 {
                    totalFreed += freed
                    recordMemoryEvent(.bufferPoolCompacted(freedMB: freed))
                }
            }
        }
        
        // Force garbage collection
        autoreleasepool {
            // This block helps release any autoreleased objects
        }
        
        if totalFreed > 0 {
            recordMemoryEvent(.memoryOptimized(savedMB: totalFreed))
            onMemoryOptimized?(totalFreed)
            print("🧹 Memory optimization completed: freed \(String(format: "%.1f", totalFreed)) MB")
        }
        
        return totalFreed
    }
    
    /// Check for memory leaks
    /// - Returns: Dictionary of detected leaks by component
    func checkForMemoryLeaks() -> [String: Double] {
        guard configuration.enableLeakDetection else { return [:] }
        
        let currentMemory = getCurrentMemoryUsage()
        let timeSinceBaseline = Date().timeIntervalSince(lastLeakCheck)
        
        // Update baseline periodically
        if timeSinceBaseline > 300 { // 5 minutes
            establishBaseline()
            return [:]
        }
        
        var leaks: [String: Double] = [:]
        
        // Check for overall memory growth
        let memoryGrowth = currentMemory - baselineMemory
        if memoryGrowth > 50.0 { // 50MB growth threshold
            leaks["System"] = memoryGrowth
        }
        
        // Check component-specific leaks
        for (component, usage) in componentMemoryUsage {
            if usage > 20.0 { // 20MB threshold for component leaks
                leaks[component] = usage
            }
        }
        
        return leaks
    }
    
    /// Get memory optimization recommendations
    /// - Returns: Array of optimization recommendations
    func getOptimizationRecommendations() -> [String] {
        let stats = getCurrentMemoryStatistics()
        var recommendations: [String] = []
        
        // Check total memory usage
        if stats.totalMemoryMB > Double(configuration.memoryWarningThresholdMB) {
            recommendations.append("Total memory usage is high (\(String(format: "%.1f", stats.totalMemoryMB)) MB)")
        }
        
        // Check memory growth rate
        if stats.memoryGrowthRate > 5.0 {
            recommendations.append("High memory growth rate (\(String(format: "%.2f", stats.memoryGrowthRate)) MB/s) - possible leak")
        }
        
        // Check buffer pool usage
        if stats.bufferPoolMemoryMB > 30.0 {
            recommendations.append("Buffer pool memory usage is high - consider compacting")
        }
        
        // Check system memory pressure
        if stats.systemMemoryPressure != .normal {
            recommendations.append("System memory pressure detected - reduce buffer sizes")
        }
        
        // Check for component-specific issues
        for (component, usage) in componentMemoryUsage {
            if usage > 15.0 {
                recommendations.append("High memory usage in \(component) (\(String(format: "%.1f", usage)) MB)")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("Memory usage is optimal")
        }
        
        return recommendations
    }
    
    /// Get formatted memory report
    /// - Returns: Human-readable memory report
    func getMemoryReport() -> String {
        let stats = getCurrentMemoryStatistics()
        let recommendations = getOptimizationRecommendations()
        let recentEvents = Array(memoryEvents.suffix(5))
        
        var report = stats.description + "\n\n"
        
        report += "🎯 Optimization Recommendations:\n"
        for (index, recommendation) in recommendations.enumerated() {
            report += "   \(index + 1). \(recommendation)\n"
        }
        
        if !recentEvents.isEmpty {
            report += "\n📋 Recent Memory Events:\n"
            for event in recentEvents {
                report += "   • \(event.description)\n"
            }
        }
        
        return report
    }
    
    // MARK: - Private Methods
    
    /// Start real-time memory monitoring
    private func startRealTimeMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: configuration.trackingIntervalSeconds, repeats: true) { [weak self] _ in
            self?.updateMemoryStatistics()
        }
    }
    
    /// Update memory statistics
    private func updateMemoryStatistics() {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            
            let stats = self.getCurrentMemoryStatistics()
            
            // Add to history
            self.memoryHistory.append(stats)
            
            // Limit history size
            if self.memoryHistory.count > self.configuration.maxHistoryEntries {
                self.memoryHistory.removeFirst()
            }
            
            // Check thresholds
            self.checkMemoryThresholds(stats)
            
            // Perform automatic cleanup if enabled
            if self.configuration.enableAutomaticCleanup && 
               stats.totalMemoryMB > Double(self.configuration.memoryWarningThresholdMB) {
                let freed = self.optimizeMemory()
                if freed > 0 {
                    self.recordMemoryEvent(.automaticCleanup(freedMB: freed))
                }
            }
        }
    }
    
    /// Check memory thresholds and trigger warnings
    /// - Parameter stats: Current memory statistics
    private func checkMemoryThresholds(_ stats: MemoryStatistics) {
        let totalMB = stats.totalMemoryMB
        
        if totalMB > Double(configuration.criticalMemoryThresholdMB) {
            recordMemoryEvent(.criticalMemory(currentMB: totalMB))
            onCriticalMemory?(totalMB)
        } else if totalMB > Double(configuration.memoryWarningThresholdMB) {
            recordMemoryEvent(.memoryWarning(currentMB: totalMB))
            onMemoryWarning?(totalMB)
        }
    }
    
    /// Setup system memory pressure monitoring
    private func setupMemoryPressureMonitoring() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: monitoringQueue)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self, let source = self.memoryPressureSource else { return }
            
            let event = source.mask
            
            if event.contains(.critical) {
                self.currentMemoryPressure = .critical
                print("🚨 Critical memory pressure detected")
            } else if event.contains(.warning) {
                self.currentMemoryPressure = .warning
                print("⚠️ Memory pressure warning")
            } else if event.contains(.normal) {
                self.currentMemoryPressure = .normal
                print("✅ Memory pressure normalized")
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    /// Get current memory usage in MB
    /// - Returns: Memory usage in MB
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        return Double(info.resident_size) / (1024 * 1024) // Convert to MB
    }
    
    /// Get audio processing memory usage
    /// - Returns: Audio processing memory in MB
    private func getAudioProcessingMemory() -> Double {
        return componentMemoryUsage.values.reduce(0, +)
    }
    
    /// Get buffer pool memory usage
    /// - Returns: Buffer pool memory in MB
    private func getBufferPoolMemory() -> Double {
        var totalMemory: Double = 0.0
        
        for reference in bufferPoolReferences {
            if let bufferPool = reference.value {
                let stats = bufferPool.getPoolStatistics()
                if let memoryMB = stats["estimatedMemoryMB"] as? Float {
                    totalMemory += Double(memoryMB)
                }
            }
        }
        
        return totalMemory
    }
    
    /// Calculate memory growth rate
    /// - Returns: Memory growth rate in MB per second
    private func calculateMemoryGrowthRate() -> Double {
        guard memoryHistory.count >= 2 else { return 0.0 }
        
        let recent = Array(memoryHistory.suffix(10))
        guard recent.count >= 2 else { return 0.0 }
        
        let firstEntry = recent.first!
        let lastEntry = recent.last!
        
        let memoryDiff = lastEntry.totalMemoryMB - firstEntry.totalMemoryMB
        let timeDiff = lastEntry.timestamp.timeIntervalSince(firstEntry.timestamp)
        
        return timeDiff > 0 ? memoryDiff / timeDiff : 0.0
    }
    
    /// Establish baseline memory usage
    private func establishBaseline() {
        baselineMemory = getCurrentMemoryUsage()
        lastLeakCheck = Date()
        leakDetectionEnabled = true
        
        print("📊 Memory baseline established: \(String(format: "%.1f", baselineMemory)) MB")
    }
    
    /// Record a memory event
    /// - Parameter event: Memory event to record
    private func recordMemoryEvent(_ event: MemoryEvent) {
        memoryEvents.append(event)
        
        // Limit events history
        if memoryEvents.count > configuration.maxHistoryEntries {
            memoryEvents.removeFirst()
        }
        
        // Log significant events
        if event.severity > 0.5 {
            print("🧠 Memory Event: \(event.description)")
        }
    }
}

// MARK: - Supporting Types

/// Weak reference wrapper for buffer pool monitoring
private class WeakReference<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let memoryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Memory Monitor Extensions

extension AudioMemoryMonitor {
    
    /// Create a memory monitor optimized for real-time audio processing
    /// - Returns: Configured memory monitor
    static func realTimeMonitor() -> AudioMemoryMonitor {
        return AudioMemoryMonitor(configuration: .performance)
    }
    
    /// Create a memory monitor for development/debugging
    /// - Returns: Configured memory monitor with verbose tracking
    static func debugMonitor() -> AudioMemoryMonitor {
        let config = MonitoringConfiguration(
            enableRealTimeTracking: true,
            memoryWarningThresholdMB: 25,
            criticalMemoryThresholdMB: 50,
            trackingIntervalSeconds: 0.25,
            enableLeakDetection: true,
            maxHistoryEntries: 1000,
            enableAutomaticCleanup: false // Manual control for debugging
        )
        
        return AudioMemoryMonitor(configuration: config)
    }
}