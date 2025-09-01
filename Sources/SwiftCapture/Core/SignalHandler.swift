import Foundation
import Dispatch

/// Signal handler for graceful shutdown on Ctrl+C
/// Requirement 10.5: Implement graceful shutdown on Ctrl+C with partial recording save
class SignalHandler {
    
    // MARK: - Properties
    private var signalSource: DispatchSourceSignal?
    private var _isHandling = false
    private var onInterrupt: (() -> Void)?
    
    /// Public read-only access to the signal handling state for debugging
    var isHandling: Bool {
        return _isHandling
    }
    
    // MARK: - Singleton
    static let shared = SignalHandler()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Setup signal handling for graceful shutdown
    /// - Parameter onInterrupt: Callback to execute when Ctrl+C is pressed
    func setupGracefulShutdown(onInterrupt: @escaping () -> Void) {
        guard !_isHandling else { return }
        
        self.onInterrupt = onInterrupt
        _isHandling = true
        
        // Ignore the default SIGINT behavior
        signal(SIGINT, SIG_IGN)
        
        // Create a dispatch source for SIGINT
        signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        
        signalSource?.setEventHandler { [weak self] in
            self?.handleInterrupt()
        }
        
        signalSource?.resume()
    }
    
    /// Clean up signal handling
    func cleanup() {
        signalSource?.cancel()
        signalSource = nil
        _isHandling = false
        onInterrupt = nil
        
        // Restore default SIGINT behavior
        signal(SIGINT, SIG_DFL)
    }
    
    // MARK: - Private Methods
    
    private func handleInterrupt() {
        print("\n🛑 Interrupt signal received (Ctrl+C)")
        print("   Attempting graceful shutdown...")
        
        // Call the interrupt handler
        onInterrupt?()
        
        // Give more time for cleanup in recording scenarios (10 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            print("⚠️ Forced shutdown after timeout")
            exit(130) // Standard exit code for SIGINT
        }
    }
}

// MARK: - Recording Session Integration

extension SignalHandler {
    /// Setup signal handling specifically for recording sessions
    /// - Parameters:
    ///   - progressIndicator: Progress indicator to update
    ///   - onGracefulStop: Callback to stop recording gracefully
    func setupForRecording(
        progressIndicator: ProgressIndicator?,
        onGracefulStop: @escaping () async -> Void
    ) {
        setupGracefulShutdown {
            Task { @MainActor in
                progressIndicator?.updateProgress(message: "Stopping recording gracefully...")
                
                await onGracefulStop()
                progressIndicator?.stopProgress()
                print("✅ Recording stopped gracefully")
                
                // Exit after graceful stop is complete
                // The timeout in handleInterrupt() will force exit if this takes too long
                exit(130) // Standard exit code for SIGINT
            }
        }
    }
}

// MARK: - Countdown Integration

extension SignalHandler {
    /// Setup signal handling for countdown cancellation
    /// - Parameter onCancel: Callback to execute when countdown is cancelled
    func setupForCountdown(onCancel: @escaping () -> Void) {
        setupGracefulShutdown {
            print("\n❌ Countdown cancelled by user")
            onCancel()
            exit(130)
        }
    }
}