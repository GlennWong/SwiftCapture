import Foundation
import AVFoundation
import ScreenCaptureKit

/// Manages audio recording capabilities including microphone detection and configuration
class AudioManager {
    
    // MARK: - Error Types
    enum AudioError: LocalizedError {
        case microphoneNotAvailable
        case microphonePermissionDenied
        case audioDeviceNotFound(String)
        case audioConfigurationFailed(Error)
        case unsupportedAudioQuality(String)
        case audioEngineSetupFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .microphoneNotAvailable:
                return "Microphone is not available on this system"
            case .microphonePermissionDenied:
                return "Microphone permission denied. Please grant microphone access in System Preferences > Security & Privacy > Privacy > Microphone"
            case .audioDeviceNotFound(let deviceName):
                return "Audio device '\(deviceName)' not found"
            case .audioConfigurationFailed(let error):
                return "Audio configuration failed: \(error.localizedDescription)"
            case .unsupportedAudioQuality(let quality):
                return "Unsupported audio quality: '\(quality)'. Supported values: low, medium, high"
            case .audioEngineSetupFailed(let error):
                return "Audio engine setup failed: \(error.localizedDescription)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .microphoneNotAvailable:
                return "Check that a microphone is connected and recognized by the system"
            case .microphonePermissionDenied:
                return "Go to System Preferences > Security & Privacy > Privacy > Microphone and enable access for this application"
            case .audioDeviceNotFound:
                return "Use --list-audio-devices to see available audio devices"
            case .audioConfigurationFailed:
                return "Try using default audio settings or check system audio configuration"
            case .unsupportedAudioQuality:
                return "Use one of: low, medium, high"
            case .audioEngineSetupFailed:
                return "Restart the application or check system audio settings"
            }
        }
    }
    
    // MARK: - Properties
    private var audioEngine: AVAudioEngine?
    private var microphoneNode: AVAudioInputNode?
    
    // MARK: - Initialization
    init() {
        // Initialize audio engine for microphone detection
        setupAudioEngine()
    }
    
    deinit {
        cleanupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// Configure audio settings based on recording configuration
    /// - Parameter config: Recording configuration containing audio preferences
    /// - Returns: Configured AudioSettings
    /// - Throws: AudioError if configuration fails
    func configureAudio(for config: RecordingConfiguration) throws -> AudioSettings {
        // Validate audio quality
        guard let audioQuality = AudioQuality(rawValue: config.audioSettings.quality.rawValue) else {
            throw AudioError.unsupportedAudioQuality(config.audioSettings.quality.rawValue)
        }
        
        // Check microphone availability if requested
        if config.audioSettings.includeMicrophone {
            try validateMicrophoneAvailability()
        }
        
        // Create audio settings with validated parameters
        let audioSettings = AudioSettings(
            includeMicrophone: config.audioSettings.includeMicrophone,
            includeSystemAudio: config.audioSettings.includeSystemAudio,
            quality: audioQuality,
            sampleRate: audioQuality.sampleRate,
            bitRate: audioQuality.bitRate,
            channels: 2 // Stereo
        )
        
        return audioSettings
    }
    
    /// Setup microphone for recording
    /// - Returns: Configured AVAudioEngine if microphone is available
    /// - Throws: AudioError if microphone setup fails
    func setupMicrophone() throws -> AVAudioEngine? {
        guard let audioEngine = audioEngine else {
            throw AudioError.audioEngineSetupFailed(
                NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not initialized"])
            )
        }
        
        // Check microphone permission
        try validateMicrophonePermission()
        
        // Get the input node (microphone)
        let inputNode = audioEngine.inputNode
        
        // Configure input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioError.microphoneNotAvailable
        }
        
        print("🎤 Microphone configured:")
        print("   Sample Rate: \(inputFormat.sampleRate) Hz")
        print("   Channels: \(inputFormat.channelCount)")
        print("   Format: \(inputFormat.commonFormat.rawValue)")
        
        self.microphoneNode = inputNode
        return audioEngine
    }
    
    /// Validate that audio devices are available and accessible
    /// - Throws: AudioError if validation fails
    func validateAudioDevices() throws {
        // Check system audio availability (ScreenCaptureKit handles this)
        if #available(macOS 13.0, *) {
            // ScreenCaptureKit audio capture is available
            print("✅ System audio capture available via ScreenCaptureKit")
        } else {
            print("⚠️ System audio capture requires macOS 13.0+")
        }
        
        // Check microphone availability
        let microphoneAvailable = checkMicrophoneAvailability()
        if microphoneAvailable {
            print("✅ Microphone available")
        } else {
            print("⚠️ Microphone not available")
        }
        
        // List available audio devices for debugging
        listAvailableAudioDevices()
    }
    
    /// Check if microphone is available without throwing errors
    /// - Returns: true if microphone is available, false otherwise
    func checkMicrophoneAvailability() -> Bool {
        do {
            try validateMicrophoneAvailability()
            return true
        } catch {
            return false
        }
    }
    
    /// Get audio quality from string
    /// - Parameter qualityString: Quality string (low, medium, high)
    /// - Returns: AudioQuality enum value
    /// - Throws: AudioError if quality string is invalid
    func getAudioQuality(from qualityString: String) throws -> AudioQuality {
        guard let quality = AudioQuality(rawValue: qualityString.lowercased()) else {
            throw AudioError.unsupportedAudioQuality(qualityString)
        }
        return quality
    }
    
    /// Create audio settings with validation
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone audio
    ///   - includeSystemAudio: Whether to include system audio
    ///   - qualityString: Audio quality string
    /// - Returns: Validated AudioSettings
    /// - Throws: AudioError if validation fails
    func createAudioSettings(
        includeMicrophone: Bool,
        includeSystemAudio: Bool,
        qualityString: String
    ) throws -> AudioSettings {
        // Validate quality
        let quality = try getAudioQuality(from: qualityString)
        
        // Validate microphone if requested
        if includeMicrophone {
            try validateMicrophoneAvailability()
        }
        
        return AudioSettings(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: includeSystemAudio,
            quality: quality,
            sampleRate: quality.sampleRate,
            bitRate: quality.bitRate,
            channels: 2
        )
    }
    
    // MARK: - Private Methods
    
    /// Setup audio engine for microphone detection
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        print("🔧 Audio engine initialized")
    }
    
    /// Cleanup audio engine resources
    private func cleanupAudioEngine() {
        audioEngine?.stop()
        audioEngine = nil
        microphoneNode = nil
    }
    
    /// Validate microphone availability
    /// - Throws: AudioError if microphone is not available
    private func validateMicrophoneAvailability() throws {
        // Check if audio engine is available
        guard let audioEngine = audioEngine else {
            throw AudioError.audioEngineSetupFailed(
                NSError(domain: "AudioManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio engine not available"])
            )
        }
        
        // Check microphone permission first
        try validateMicrophonePermission()
        
        // Check if input node is available
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate that we have a valid input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw AudioError.microphoneNotAvailable
        }
    }
    
    /// Validate microphone permission
    /// - Throws: AudioError if permission is denied
    private func validateMicrophonePermission() throws {
        // On macOS, we use AVCaptureDevice authorization instead of AVAudioSession
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch authStatus {
        case .authorized:
            // Permission granted, continue
            break
        case .denied, .restricted:
            throw AudioError.microphonePermissionDenied
        case .notDetermined:
            // Request permission synchronously for CLI tool
            let semaphore = DispatchSemaphore(value: 0)
            var permissionGranted = false
            
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                permissionGranted = granted
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if !permissionGranted {
                throw AudioError.microphonePermissionDenied
            }
        @unknown default:
            throw AudioError.microphonePermissionDenied
        }
    }
    
    /// List available audio devices for debugging
    private func listAvailableAudioDevices() {
        print("🔍 Available Audio Devices:")
        
        // List input devices (microphones) using compatible API
        if #available(macOS 14.0, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone, .builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            
            let inputDevices = discoverySession.devices
            if inputDevices.isEmpty {
                print("   📱 No audio input devices found")
            } else {
                for (index, device) in inputDevices.enumerated() {
                    print("   📱 Input \(index + 1): \(device.localizedName)")
                    print("      ID: \(device.uniqueID)")
                    print("      Connected: \(device.isConnected)")
                }
            }
        } else {
            // Fallback for older macOS versions
            let inputDevices = AVCaptureDevice.devices(for: .audio)
            if inputDevices.isEmpty {
                print("   📱 No audio input devices found")
            } else {
                for (index, device) in inputDevices.enumerated() {
                    print("   📱 Input \(index + 1): \(device.localizedName)")
                    print("      ID: \(device.uniqueID)")
                    print("      Connected: \(device.isConnected)")
                }
            }
        }
        
        // Check system audio availability
        if #available(macOS 13.0, *) {
            print("   🔊 System Audio: Available via ScreenCaptureKit")
        } else {
            print("   🔊 System Audio: Requires macOS 13.0+")
        }
    }
}

// MARK: - AudioManager Extensions

extension AudioManager {
    
    /// Create default audio settings for common use cases
    /// - Parameters:
    ///   - includeMicrophone: Whether to include microphone
    ///   - quality: Audio quality preset
    /// - Returns: AudioSettings with default values
    static func defaultSettings(includeMicrophone: Bool = false, quality: AudioQuality = .medium) -> AudioSettings {
        return AudioSettings.default(
            includeMicrophone: includeMicrophone,
            includeSystemAudio: true,
            quality: quality
        )
    }
    
    /// Validate audio configuration without throwing
    /// - Parameter settings: Audio settings to validate
    /// - Returns: Validation result with error message if invalid
    func validateAudioConfiguration(_ settings: AudioSettings) -> (isValid: Bool, error: String?) {
        do {
            if settings.includeMicrophone {
                try validateMicrophoneAvailability()
            }
            return (true, nil)
        } catch let error as AudioError {
            return (false, error.localizedDescription)
        } catch {
            return (false, "Unknown audio validation error: \(error.localizedDescription)")
        }
    }
}