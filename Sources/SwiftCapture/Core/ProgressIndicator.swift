import Foundation
import Dispatch

/// Progress indicator for recording operations
/// Requirements 10.1, 10.2, 10.3: Real-time duration display, recording status, and completion info
class ProgressIndicator: @unchecked Sendable {
    
    // MARK: - Properties
    private var startTime: Date?
    private var timer: DispatchSourceTimer?
    private var isRecording = false
    private let outputURL: URL
    private let expectedDuration: TimeInterval
    
    // MARK: - Initialization
    init(outputURL: URL, expectedDuration: TimeInterval) {
        self.outputURL = outputURL
        self.expectedDuration = expectedDuration
    }
    
    // MARK: - Public Methods
    
    /// Start showing progress indicators
    /// Requirement 10.1: Add real-time recording duration display
    /// Requirement 10.2: Show recording status and elapsed time during capture
    func startProgress() {
        guard !isRecording else { return }
        
        startTime = Date()
        isRecording = true
        
        // Clear the line and show initial status
        print("🔴 Recording started...")
        print("   Output: \(outputURL.lastPathComponent)")
        
        if expectedDuration < 0 {
            print("   Mode: Continuous recording (press Ctrl+C to stop)")
        } else {
            print("   Expected duration: \(formatDuration(expectedDuration))")
            print("   Press Ctrl+C to stop early")
        }
        print("")
        
        // Start the progress timer
        startProgressTimer()
    }
    
    /// Stop showing progress indicators and display completion info
    /// Requirement 10.3: Display file size and location upon completion
    func stopProgress() {
        guard isRecording else { return }
        
        isRecording = false
        timer?.cancel()
        timer = nil
        
        // Clear the current progress line
        clearCurrentLine()
        
        let actualDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        print("✅ Recording completed!")
        print("   Duration: \(formatDuration(actualDuration))")
        print("   Output: \(outputURL.path)")
        
        // Display file size if file exists
        displayFileInfo()
        
        print("")
    }
    
    /// Stop progress with error information
    func stopProgressWithError(_ error: Error) {
        guard isRecording else { return }
        
        isRecording = false
        timer?.cancel()
        timer = nil
        
        // Clear the current progress line
        clearCurrentLine()
        
        let actualDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        print("❌ Recording failed after \(formatDuration(actualDuration))")
        print("   Error: \(error.localizedDescription)")
        
        // Check if partial file was created
        if FileManager.default.fileExists(atPath: outputURL.path) {
            print("   Partial file saved: \(outputURL.path)")
            displayFileInfo()
        }
        
        print("")
    }
    
    /// Update progress with current status (for external updates)
    func updateProgress(message: String) {
        guard isRecording else { return }
        
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        clearCurrentLine()
        if expectedDuration < 0 {
            // Continuous recording mode
            print("🔴 \(message) | Elapsed: \(formatDuration(elapsed))", terminator: "")
        } else {
            // Timed recording mode
            let remaining = max(0, expectedDuration - elapsed)
            print("🔴 \(message) | Elapsed: \(formatDuration(elapsed)) | Remaining: \(formatDuration(remaining))", terminator: "")
        }
        fflush(stdout)
    }
    
    // MARK: - Private Methods
    
    /// Start the progress timer that updates every second
    private func startProgressTimer() {
        let queue = DispatchQueue(label: "progress.timer", qos: .utility)
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        timer?.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.updateProgressDisplay()
        }
        
        timer?.resume()
    }
    
    /// Update the progress display with current timing information
    private func updateProgressDisplay() {
        guard isRecording, let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        let progressLine: String
        if expectedDuration < 0 {
            // Continuous recording mode - no progress bar or remaining time
            progressLine = String(format: "🔴 Recording... | Elapsed: %@ (press Ctrl+C to stop)",
                                formatDuration(elapsed))
        } else {
            // Timed recording mode - show progress bar and remaining time
            let remaining = max(0, expectedDuration - elapsed)
            let progress = min(1.0, elapsed / expectedDuration)
            
            // Create progress bar
            let barWidth = 30
            let filledWidth = Int(progress * Double(barWidth))
            let progressBar = String(repeating: "█", count: filledWidth) + 
                             String(repeating: "░", count: barWidth - filledWidth)
            
            progressLine = String(format: "🔴 Recording [%@] %.1f%% | %@ / %@ | Remaining: %@",
                                    progressBar,
                                    progress * 100,
                                    formatDuration(elapsed),
                                    formatDuration(expectedDuration),
                                    formatDuration(remaining))
        }
        
        // Update the display on main queue
        DispatchQueue.main.sync {
            self.clearCurrentLine()
            print(progressLine, terminator: "")
            fflush(stdout)
        }
    }
    
    /// Clear the current line in terminal
    private func clearCurrentLine() {
        print("\r\u{001B}[K", terminator: "")
    }
    
    /// Format duration in a human-readable format
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((duration - Double(totalSeconds)) * 1000)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%03ds", seconds, milliseconds)
        }
    }
    
    /// Display file information after recording completion
    private func displayFileInfo() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                let sizeString = formatFileSize(fileSize)
                print("   File size: \(sizeString)")
                
                // Calculate approximate bitrate
                let actualDuration = startTime.map { Date().timeIntervalSince($0) } ?? expectedDuration
                if actualDuration > 0 {
                    let bitrate = Double(fileSize * 8) / actualDuration / 1_000_000 // Mbps
                    print("   Average bitrate: \(String(format: "%.1f", bitrate)) Mbps")
                }
            }
            
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .medium
                print("   Created: \(formatter.string(from: creationDate))")
            }
        } catch {
            print("   File info unavailable: \(error.localizedDescription)")
        }
    }
    
    /// Format file size in human-readable format
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Static Convenience Methods

extension ProgressIndicator {
    /// Create and start a progress indicator for a recording session
    static func startRecording(outputURL: URL, duration: TimeInterval) -> ProgressIndicator {
        let indicator = ProgressIndicator(outputURL: outputURL, expectedDuration: duration)
        indicator.startProgress()
        return indicator
    }
    
    /// Show a simple completion message without progress tracking
    static func showCompletion(outputURL: URL, duration: TimeInterval) {
        print("✅ Recording completed!")
        print("   Duration: \(ProgressIndicator.formatDurationStatic(duration))")
        print("   Output: \(outputURL.path)")
        
        // Display file size if available
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.countStyle = .file
                print("   File size: \(formatter.string(fromByteCount: fileSize))")
            }
        } catch {
            // Silently ignore file info errors
        }
        
        print("")
    }
    
    /// Static version of formatDuration for external use
    private static func formatDurationStatic(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((duration - Double(totalSeconds)) * 1000)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%03ds", seconds, milliseconds)
        }
    }
}