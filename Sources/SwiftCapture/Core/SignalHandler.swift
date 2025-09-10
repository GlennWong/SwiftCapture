import Foundation
import Dispatch

/// Signal handler for graceful shutdown on Ctrl+C
/// Requirement 10.5: Implement graceful shutdown on Ctrl+C with partial recording save
class SignalHandler {
    
    // MARK: - Properties
    private var signalSource: DispatchSourceSignal?
    private var _isHandling = false
    private var onInterrupt: (() -> Void)?
    private var hasDuration = false
    private var requiresConfirmation = false
    
    /// Public read-only access to the signal handling state for debugging
    var isHandling: Bool {
        return _isHandling
    }
    
    // MARK: - Singleton
    static let shared = SignalHandler()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Setup signal handling for graceful shutdown
    /// - Parameters:
    ///   - onInterrupt: Callback to execute when Ctrl+C is pressed
    ///   - hasDuration: Whether the recording has a specified duration (requires confirmation for early termination)
    func setupGracefulShutdown(onInterrupt: @escaping () -> Void, hasDuration: Bool = false) {
        guard !_isHandling else { return }
        
        self.onInterrupt = onInterrupt
        self.hasDuration = hasDuration
        self.requiresConfirmation = hasDuration
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
        hasDuration = false
        requiresConfirmation = false
        
        // Restore default SIGINT behavior
        signal(SIGINT, SIG_DFL)
    }
    
    // MARK: - Private Methods
    
    private func handleInterrupt() {
        print("\n🛑 Interrupt signal received (Ctrl+C)")
        
        // If duration is specified, require confirmation for early termination
        if requiresConfirmation {
            if promptForConfirmation() {
                print("   Recording stopped early by user confirmation.")
                onInterrupt?()
                
                // Give time for cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                    print("⚠️ Forced shutdown after 20 second timeout")
                    print("   File may be incomplete or corrupted")
                    exit(130) // Standard exit code for SIGINT
                }
            } else {
                print("   Continuing recording...")
                return
            }
        } else {
            // No duration specified - immediate graceful shutdown
            print("   Attempting graceful shutdown...")
            onInterrupt?()
            
            // Give more time for cleanup in recording scenarios (20 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                print("⚠️ Forced shutdown after 20 second timeout")
                print("   File may be incomplete or corrupted")
                exit(130) // Standard exit code for SIGINT
            }
        }
    }
    
    /// Prompt user for confirmation when terminating a timed recording early
    /// - Returns: true if user confirms early termination, false to continue recording
    private func promptForConfirmation() -> Bool {
        print("   Recording has a specified duration. Are you sure you want to stop early?")
        print("   Type 'y' or 'yes' to confirm, or press Enter to continue: ", terminator: "")
        fflush(stdout)
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        
        return input == "y" || input == "yes"
    }
}

// MARK: - Recording Session Integration

extension SignalHandler {
    /// Setup signal handling specifically for recording sessions
    /// - Parameters:
    ///   - progressIndicator: Progress indicator to update
    ///   - onGracefulStop: Callback to stop recording gracefully
    ///   - hasDuration: Whether the recording has a specified duration (requires confirmation for early termination)
    func setupForRecording(
        progressIndicator: ProgressIndicator?,
        onGracefulStop: @escaping () async -> Void,
        hasDuration: Bool = false
    ) {
        setupGracefulShutdown(onInterrupt: {
            Task { @MainActor in
                progressIndicator?.updateProgress(message: "Stopping recording gracefully...")
                
                await onGracefulStop()
                progressIndicator?.stopProgress()
                print("✅ Recording stopped gracefully")
                
                // Don't exit immediately - let the continuation handle the exit
                // The timeout in handleInterrupt() will force exit if this takes too long
            }
        }, hasDuration: hasDuration)
    }
}

// MARK: - Countdown Integration

extension SignalHandler {
    /// Setup signal handling for countdown cancellation
    /// - Parameter onCancel: Callback to execute when countdown is cancelled
    func setupForCountdown(onCancel: @escaping () -> Void) {
        setupGracefulShutdown(onInterrupt: {
            print("\n❌ Countdown cancelled by user")
            onCancel()
            exit(130)
        }, hasDuration: false) // Countdown cancellation doesn't require confirmation
    }
}