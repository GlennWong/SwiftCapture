import Foundation
@preconcurrency import AVFoundation
import CoreGraphics

/// Audio quality validation status
enum AudioQualityStatus {
    case excellent  // Quality score >= 0.9
    case good      // Quality score >= 0.7
    case acceptable // Quality score >= 0.5
    case poor      // Quality score < 0.5
    
    var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .acceptable: return "Acceptable"
        case .poor: return "Poor"
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .acceptable: return "🟠"
        case .poor: return "🔴"
        }
    }
}

/// Audio quality validation result
struct AudioQualityValidationResult {
    /// Overall quality status
    let status: AudioQualityStatus
    
    /// Quality score (0.0 to 1.0)
    let qualityScore: Float
    
    /// List of identified quality issues
    let issues: [String]
    
    /// Current audio metrics (if available)
    let metrics: AudioMetrics?
    
    /// Recommendations for improving quality
    let recommendations: [String]
    
    /// Whether the audio quality is acceptable for recording
    var isAcceptable: Bool {
        return qualityScore >= 0.5
    }
    
    /// Whether the audio quality is optimal
    var isOptimal: Bool {
        return qualityScore >= 0.9 && issues.isEmpty
    }
}

/// Manages output file creation and AVAssetWriter configuration
class OutputManager {
    
    /// Error types for output operations
    enum OutputError: LocalizedError {
        case invalidOutputPath(String)
        case writerCreationFailed(Error)
        case inputCreationFailed(Error)
        case directoryCreationFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidOutputPath(let path):
                return "Invalid output path: '\(path)'"
            case .writerCreationFailed(let error):
                return "Failed to create AVAssetWriter: \(error.localizedDescription)"
            case .inputCreationFailed(let error):
                return "Failed to create AVAssetWriter input: \(error.localizedDescription)"
            case .directoryCreationFailed(let error):
                return "Failed to create output directory: \(error.localizedDescription)"
            }
        }
    }
    
    /// Generate output URL from path or create default timestamp-based name
    /// - Parameter path: Optional custom output path
    /// - Parameter format: Output format for file extension
    /// - Parameter overwrite: Whether to overwrite existing files without prompting
    /// - Returns: URL for output file with conflict resolution
    func generateOutputURL(from path: String?, format: OutputFormat, overwrite: Bool = false) throws -> URL {
        let baseURL: URL
        
        if let customPath = path, !customPath.isEmpty {
            baseURL = URL(fileURLWithPath: customPath)
        } else {
            // Generate timestamp-based filename (YYYY-MM-DD_HH-MM-SS.mov)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let filename = "\(timestamp).\(format.fileExtension)"
            
            baseURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(filename)
        }
        
        // Handle file conflicts
        return try resolveFileConflict(for: baseURL, overwrite: overwrite)
    }
    
    /// Resolve file conflicts with user confirmation or auto-numbering
    /// - Parameter url: Original URL that may conflict
    /// - Parameter overwrite: Whether to overwrite existing files without prompting
    /// - Returns: URL that doesn't conflict with existing files
    /// - Throws: OutputError if user cancels or resolution fails
    private func resolveFileConflict(for url: URL, overwrite: Bool) throws -> URL {
        // If file doesn't exist, return original URL
        if !FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        
        // If overwrite flag is set, return original URL (will be overwritten)
        if overwrite {
            return url
        }
        
        // Check if we're in interactive mode (can prompt user)
        if isInteractiveMode() {
            return try handleInteractiveConflict(for: url)
        } else {
            // Auto-number the file
            return generateNumberedFilename(for: url)
        }
    }
    
    /// Handle file conflict in interactive mode with user confirmation
    /// - Parameter url: Original URL that conflicts
    /// - Returns: Resolved URL based on user choice
    /// - Throws: OutputError if user cancels
    private func handleInteractiveConflict(for url: URL) throws -> URL {
        print("⚠️  File already exists: \(url.lastPathComponent)")
        print("Choose an option:")
        print("  1. Overwrite existing file")
        print("  2. Auto-number (e.g., filename-2.mov)")
        print("  3. Cancel recording")
        print("Enter choice (1-3): ", terminator: "")
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              let choice = Int(input) else {
            throw OutputError.invalidOutputPath("Invalid choice. Recording cancelled.")
        }
        
        switch choice {
        case 1:
            // Overwrite - return original URL
            return url
        case 2:
            // Auto-number
            return generateNumberedFilename(for: url)
        case 3:
            // Cancel
            throw OutputError.invalidOutputPath("Recording cancelled by user.")
        default:
            throw OutputError.invalidOutputPath("Invalid choice. Recording cancelled.")
        }
    }
    
    /// Generate a numbered filename to avoid conflicts
    /// - Parameter url: Original URL
    /// - Returns: URL with number suffix that doesn't conflict
    private func generateNumberedFilename(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        
        var counter = 2
        var newURL: URL
        
        repeat {
            let numberedFilename = "\(filename)-\(counter).\(fileExtension)"
            newURL = directory.appendingPathComponent(numberedFilename)
            counter += 1
        } while FileManager.default.fileExists(atPath: newURL.path)
        
        return newURL
    }
    
    /// Check if we're running in interactive mode (can prompt user)
    /// - Returns: true if interactive, false otherwise
    private func isInteractiveMode() -> Bool {
        return isatty(STDIN_FILENO) != 0
    }
    
    /// Validate format compatibility with recording settings
    /// - Parameter config: Recording configuration to validate
    /// - Throws: OutputError if format is incompatible with settings
    func validateFormatCompatibility(_ config: RecordingConfiguration) throws {
        let format = config.outputFormat
        let codec = config.videoSettings.codec
        
        // Check codec compatibility
        if !format.isCompatible(with: codec) {
            throw OutputError.invalidOutputPath(
                "Codec \(codec.rawValue) is not compatible with \(format.rawValue.uppercased()) format. " +
                "Supported codecs for \(format.rawValue.uppercased()): \(format.supportedCodecs.map { $0.rawValue }.joined(separator: ", "))"
            )
        }
        
        // MOV format supports all resolutions and frame rates natively
        // No additional validation needed for MOV format
        
        // Log format selection only in verbose mode
        if config.verbose {
            print("📹 Format Configuration:")
            print("   Format: \(format.description)")
            print("   Codec: \(codec.rawValue.uppercased())")
            print("   Compatibility: ✅ Validated")
        }
    }
    
    /// Get optimized codec for format and quality settings
    /// - Parameters:
    ///   - format: Output format
    ///   - quality: Video quality setting
    ///   - resolution: Recording resolution
    /// - Returns: Recommended codec for the configuration
    func getOptimizedCodec(for format: OutputFormat, quality: VideoQuality, resolution: CGSize) -> AVVideoCodecType {
        let pixelCount = Int(resolution.width * resolution.height)
        
        switch format {
        case .mov:
            // For MOV, we can use HEVC for high quality/resolution to save space
            if quality == .high && pixelCount > 1920 * 1080 {
                return .hevc // Better compression for high-res content
            } else {
                return .h264 // Standard choice for compatibility
            }
        case .mp4:
            // Legacy case - should not be used since format is fixed to MOV
            return .h264
        }
    }
    
    /// Validate output path and create directories if needed
    /// - Parameter url: Output URL to validate
    /// - Throws: OutputError if validation fails
    func validateOutputPath(_ url: URL) throws {
        let directory = url.deletingLastPathComponent()
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("📁 Created directory: \(directory.path)")
            } catch {
                throw OutputError.directoryCreationFailed(error)
            }
        }
        
        // Check if we have write permissions
        if !FileManager.default.isWritableFile(atPath: directory.path) {
            throw OutputError.invalidOutputPath("No write permission for directory: \(directory.path)")
        }
        
        // If file exists, it should have been handled by conflict resolution
        // Just remove it if it still exists (user chose to overwrite)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
                print("🗑️  Removed existing file: \(url.lastPathComponent)")
            } catch {
                throw OutputError.invalidOutputPath("Cannot overwrite existing file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Create AVAssetWriter with proper configuration
    /// - Parameters:
    ///   - url: Output URL
    ///   - format: Output format
    /// - Returns: Configured AVAssetWriter
    /// - Throws: OutputError if creation fails
    func createWriter(for url: URL, format: OutputFormat) throws -> AVAssetWriter {
        do {
            return try AVAssetWriter(outputURL: url, fileType: format.avFileType)
        } catch {
            throw OutputError.writerCreationFailed(error)
        }
    }
    
    /// Create video input with enhanced settings
    /// - Parameter config: Recording configuration
    /// - Returns: Configured AVAssetWriterInput for video
    /// - Throws: OutputError if creation fails
    func createVideoInput(for config: RecordingConfiguration) throws -> AVAssetWriterInput {
        let settings = config.videoSettings.avSettings
        

        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        return input
    }
    
    /// Create audio input with quality settings and enhancement support
    /// - Parameter config: Recording configuration
    /// - Returns: Configured AVAssetWriterInput for audio
    /// - Throws: OutputError if creation fails
    func createAudioInput(for config: RecordingConfiguration) throws -> AVAssetWriterInput {
        // Use enhanced settings if audio processing is enabled
        let settings = getOptimizedAudioSettings(for: config)
        
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        
        // Configure performance expectations for high-quality audio
        if config.audioSettings.hasEnhancement {
            input.performsMultiPassEncodingIfSupported = true
        }
        
        return input
    }
    
    /// Get optimized audio settings based on configuration and quality requirements
    /// - Parameter config: Recording configuration
    /// - Returns: Optimized audio settings dictionary
    private func getOptimizedAudioSettings(for config: RecordingConfiguration) -> [String: Any] {
        let audioSettings = config.audioSettings
        
        // Start with base settings
        var settings = audioSettings.finalAVSettings
        
        // Apply quality-adaptive encoding based on enhancement settings
        if audioSettings.hasEnhancement {
            settings = applyQualityAdaptiveEncoding(settings, enhancementSettings: audioSettings.enhancementSettings)
        }
        
        // Apply high-quality encoding optimizations
        settings = applyHighQualityOptimizations(settings, audioSettings: audioSettings)
        
        return settings
    }
    
    /// Apply quality-adaptive encoding settings based on enhancement configuration
    /// - Parameters:
    ///   - baseSettings: Base audio settings
    ///   - enhancementSettings: Audio enhancement configuration
    /// - Returns: Adapted audio settings
    private func applyQualityAdaptiveEncoding(_ baseSettings: [String: Any], enhancementSettings: AudioEnhancementSettings) -> [String: Any] {
        var settings = baseSettings
        
        // Determine optimal bit rate based on enhancement settings
        let baseBitRate = baseSettings[AVEncoderBitRateKey] as? Int ?? 128_000
        let adaptiveBitRate = calculateAdaptiveBitRate(baseBitRate: baseBitRate, enhancementSettings: enhancementSettings)
        
        settings[AVEncoderBitRateKey] = adaptiveBitRate
        
        // Set audio quality based on enhancement mode
        if enhancementSettings.losslessModeEnabled {
            // Use maximum quality for lossless mode
            settings[AVEncoderAudioQualityKey] = AVAudioQuality.max.rawValue
            // Note: Variable bit rate is handled through quality settings for AAC
            
            // Use higher sample rate if available
            if let sampleRate = settings[AVSampleRateKey] as? Double, sampleRate < 48000 {
                settings[AVSampleRateKey] = 48000.0
            }
        } else if enhancementSettings.qualityProtectionEnabled {
            // Use high quality with variable bit rate for quality protection
            settings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue
            // Note: Variable bit rate is handled through quality settings for AAC
        }
        
        // Adjust encoding complexity based on processing requirements
        if enhancementSettings.compressionRatio > 3.0 || enhancementSettings.masterGain > 10.0 {
            // Use higher quality encoding for heavily processed audio
            settings[AVEncoderAudioQualityKey] = AVAudioQuality.max.rawValue
        }
        
        return settings
    }
    
    /// Calculate adaptive bit rate based on enhancement settings
    /// - Parameters:
    ///   - baseBitRate: Base bit rate from audio quality setting
    ///   - enhancementSettings: Enhancement configuration
    /// - Returns: Optimized bit rate
    private func calculateAdaptiveBitRate(baseBitRate: Int, enhancementSettings: AudioEnhancementSettings) -> Int {
        var adaptiveBitRate = baseBitRate
        
        // Increase bit rate for lossless mode
        if enhancementSettings.losslessModeEnabled {
            adaptiveBitRate = min(baseBitRate * 3, 512_000) // Up to 512 kbps for lossless
        } else if enhancementSettings.processingEnabled {
            // Increase bit rate based on processing intensity
            let processingIntensity = calculateProcessingIntensity(enhancementSettings)
            let multiplier = 1.0 + (processingIntensity * 0.8) // Up to 80% increase
            adaptiveBitRate = min(Int(Float(baseBitRate) * multiplier), 320_000) // Max 320 kbps for processed
        }
        
        // Ensure minimum quality for enhanced audio
        if enhancementSettings.processingEnabled {
            adaptiveBitRate = max(adaptiveBitRate, 192_000) // Minimum 192 kbps for enhanced audio
        }
        
        return adaptiveBitRate
    }
    
    /// Calculate processing intensity score from enhancement settings
    /// - Parameter settings: Enhancement settings
    /// - Returns: Processing intensity (0.0 to 1.0)
    private func calculateProcessingIntensity(_ settings: AudioEnhancementSettings) -> Float {
        var intensity: Float = 0.0
        
        // Factor in gain amount
        intensity += min(abs(settings.masterGain) / 20.0, 1.0) * 0.3
        
        // Factor in compression ratio
        intensity += min((settings.compressionRatio - 1.0) / 4.0, 1.0) * 0.4
        
        // Factor in limiter usage
        if settings.limiterThreshold > -3.0 {
            intensity += 0.2
        }
        
        // Factor in quality protection overhead
        if settings.qualityProtectionEnabled {
            intensity += 0.1
        }
        
        return min(intensity, 1.0)
    }
    
    /// Apply high-quality encoding optimizations
    /// - Parameters:
    ///   - settings: Base audio settings
    ///   - audioSettings: Audio configuration
    /// - Returns: Optimized settings
    private func applyHighQualityOptimizations(_ settings: [String: Any], audioSettings: AudioSettings) -> [String: Any] {
        var optimizedSettings = settings
        
        // Enable high-quality AAC encoding
        optimizedSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        
        // Set optimal channel layout for stereo
        if audioSettings.channels == 2 {
            optimizedSettings[AVChannelLayoutKey] = [
                AVChannelLayoutKey: kAudioChannelLayoutTag_Stereo
            ]
        }
        
        // Configure bit depth for high quality
        if audioSettings.quality == .high || audioSettings.hasEnhancement {
            // Use higher bit depth equivalent settings
            optimizedSettings[AVLinearPCMBitDepthKey] = 24 // Request 24-bit equivalent quality
        }
        
        // Enable advanced encoding features
        optimizedSettings[AVEncoderAudioQualityForVBRKey] = AVAudioQuality.max.rawValue
        
        return optimizedSettings
    }
    
    /// Create pixel buffer adaptor for video input
    /// - Parameters:
    ///   - input: Video input to attach adaptor to
    ///   - resolution: Recording resolution
    /// - Returns: Configured AVAssetWriterInputPixelBufferAdaptor
    func createPixelBufferAdaptor(for input: AVAssetWriterInput, resolution: CGSize) -> AVAssetWriterInputPixelBufferAdaptor {

        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(resolution.width),
            kCVPixelBufferHeightKey as String: Int(resolution.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        return AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
    }
    
    /// Configure complete recording setup with enhanced video settings
    /// - Parameter config: Recording configuration
    /// - Returns: Tuple containing writer, video input, audio input, and pixel buffer adaptor
    /// - Throws: OutputError if setup fails
    func setupRecording(for config: RecordingConfiguration) throws -> (
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) {
        // Validate format compatibility with recording settings
        try validateFormatCompatibility(config)
        
        // Validate and prepare output path
        try validateOutputPath(config.outputURL)
        
        // Create writer
        let writer = try createWriter(for: config.outputURL, format: config.outputFormat)
        
        // Create video input with fps and quality settings
        let videoInput = try createVideoInput(for: config)
        
        // Create audio input if audio is enabled
        let audioInput: AVAssetWriterInput?
        if config.audioSettings.hasAudio {
            audioInput = try createAudioInput(for: config)
        } else {
            audioInput = nil
        }
        
        // Create pixel buffer adaptor
        let adaptor = createPixelBufferAdaptor(for: videoInput, resolution: config.videoSettings.resolution)
        
        // Add inputs to writer
        writer.add(videoInput)
        if let audioInput = audioInput {
            writer.add(audioInput)
        }
        
        // Start writing (but not session - that's handled by CaptureController)
        writer.startWriting()
        
        // Log configuration only in verbose mode
        if config.verbose {
            print("📁 Output Configuration:")
            print("   File: \(config.outputURL.lastPathComponent)")
            print("   Format: \(config.outputFormat.rawValue.uppercased())")
            print("   Video Settings: \(config.videoSettings.fps)fps, \(config.videoSettings.quality.rawValue) quality")
            if audioInput != nil {
                let audioSettings = config.audioSettings
                print("   Audio Settings: \(audioSettings.quality.rawValue) quality, \(audioSettings.sampleRate) Hz")
                
                // Show enhanced audio information
                if audioSettings.hasEnhancement {
                    let finalSettings = getOptimizedAudioSettings(for: config)
                    let bitRate = finalSettings[AVEncoderBitRateKey] as? Int ?? 0
                    print("   Audio Enhancement: enabled (\(audioSettings.enhancementSettings.preset.rawValue) preset)")
                    print("   Enhanced Bit Rate: \(bitRate/1000) kbps")
                    print("   Quality Protection: \(audioSettings.enhancementSettings.qualityProtectionEnabled ? "enabled" : "disabled")")
                    
                    if audioSettings.enhancementSettings.losslessModeEnabled {
                        print("   Lossless Mode: enabled")
                    }
                }
            } else {
                print("   Audio: disabled")
            }
        }
        
        return (writer: writer, videoInput: videoInput, audioInput: audioInput, adaptor: adaptor)
    }
    
    /// Validate audio quality after processing
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - qualityMonitor: Audio quality monitor (optional)
    /// - Returns: Audio quality validation result
    func validateAudioQuality(for config: RecordingConfiguration, qualityMonitor: AudioQualityMonitor? = nil) -> AudioQualityValidationResult {
        let audioSettings = config.audioSettings
        
        // Perform basic configuration validation
        var validationIssues: [String] = []
        var qualityScore: Float = 1.0
        
        // Check if bit rate is sufficient for enhancement
        if audioSettings.hasEnhancement {
            let finalSettings = getOptimizedAudioSettings(for: config)
            let bitRate = finalSettings[AVEncoderBitRateKey] as? Int ?? 0
            
            if bitRate < 192_000 {
                validationIssues.append("Bit rate (\(bitRate/1000) kbps) may be insufficient for audio enhancement")
                qualityScore -= 0.2
            }
            
            // Validate enhancement settings
            let enhancementValidation = validateEnhancementSettings(audioSettings.enhancementSettings)
            validationIssues.append(contentsOf: enhancementValidation.issues)
            qualityScore *= enhancementValidation.score
        }
        
        // Check sample rate compatibility
        if audioSettings.sampleRate < 44100 && audioSettings.hasEnhancement {
            validationIssues.append("Sample rate (\(Int(audioSettings.sampleRate)) Hz) may be too low for optimal enhancement")
            qualityScore -= 0.1
        }
        
        // Get quality metrics from monitor if available
        var currentMetrics: AudioMetrics?
        if let monitor = qualityMonitor {
            currentMetrics = monitor.getCurrentMetrics()
            
            // Check for quality issues
            if let metrics = currentMetrics {
                if metrics.clippingDetected {
                    validationIssues.append("Audio clipping detected")
                    qualityScore -= 0.3
                }
                
                if metrics.thd > audioSettings.enhancementSettings.maxTHD {
                    validationIssues.append("THD (\(String(format: "%.3f", metrics.thd * 100))%) exceeds maximum allowed")
                    qualityScore -= 0.2
                }
                
                if metrics.peakLevel > -1.0 {
                    validationIssues.append("Peak level (\(String(format: "%.1f", metrics.peakLevel)) dBFS) is too high")
                    qualityScore -= 0.1
                }
            }
        }
        
        // Determine overall quality status
        let qualityStatus: AudioQualityStatus
        if qualityScore >= 0.9 {
            qualityStatus = .excellent
        } else if qualityScore >= 0.7 {
            qualityStatus = .good
        } else if qualityScore >= 0.5 {
            qualityStatus = .acceptable
        } else {
            qualityStatus = .poor
        }
        
        return AudioQualityValidationResult(
            status: qualityStatus,
            qualityScore: qualityScore,
            issues: validationIssues,
            metrics: currentMetrics,
            recommendations: generateQualityRecommendations(issues: validationIssues, score: qualityScore, config: config)
        )
    }
    
    /// Validate enhancement settings for quality and compatibility
    /// - Parameter settings: Enhancement settings to validate
    /// - Returns: Validation result with issues and score
    private func validateEnhancementSettings(_ settings: AudioEnhancementSettings) -> (issues: [String], score: Float) {
        var issues: [String] = []
        var score: Float = 1.0
        
        // Check if settings are valid
        if !settings.isValid {
            issues.append(contentsOf: settings.validationErrors)
            score *= 0.5
        }
        
        // Check for potentially problematic settings
        if settings.masterGain > 15.0 {
            issues.append("Very high gain (\(String(format: "%.1f", settings.masterGain)) dB) may cause distortion")
            score -= 0.2
        }
        
        if settings.compressionRatio > 5.0 {
            issues.append("High compression ratio (\(String(format: "%.1f", settings.compressionRatio)):1) may reduce audio quality")
            score -= 0.1
        }
        
        if settings.limiterThreshold > -0.5 {
            issues.append("Limiter threshold (\(String(format: "%.1f", settings.limiterThreshold)) dBFS) is very aggressive")
            score -= 0.1
        }
        
        // Check for quality protection conflicts
        if !settings.qualityProtectionEnabled && (settings.masterGain > 10.0 || settings.compressionRatio > 4.0) {
            issues.append("Quality protection is disabled with aggressive processing settings")
            score -= 0.15
        }
        
        return (issues: issues, score: max(0.0, score))
    }
    
    /// Generate quality improvement recommendations
    /// - Parameters:
    ///   - issues: Identified quality issues
    ///   - score: Current quality score
    ///   - config: Recording configuration
    /// - Returns: Array of recommendations
    private func generateQualityRecommendations(issues: [String], score: Float, config: RecordingConfiguration) -> [String] {
        var recommendations: [String] = []
        
        if score < 0.7 {
            recommendations.append("Consider using higher audio quality settings")
        }
        
        if config.audioSettings.hasEnhancement {
            let settings = config.audioSettings.enhancementSettings
            
            if settings.masterGain > 12.0 {
                recommendations.append("Reduce master gain to avoid distortion")
            }
            
            if settings.compressionRatio > 4.0 {
                recommendations.append("Lower compression ratio for better audio quality")
            }
            
            if !settings.qualityProtectionEnabled {
                recommendations.append("Enable quality protection for safer processing")
            }
            
            if !settings.losslessModeEnabled && score < 0.6 {
                recommendations.append("Consider enabling lossless mode for critical audio")
            }
        }
        
        if config.audioSettings.sampleRate < 48000 && config.audioSettings.hasEnhancement {
            recommendations.append("Use 48 kHz sample rate for optimal enhancement quality")
        }
        
        if config.audioSettings.bitRate < 192_000 && config.audioSettings.hasEnhancement {
            recommendations.append("Increase bit rate to at least 192 kbps for enhanced audio")
        }
        
        return recommendations
    }
    
    /// Finalize recording and wait for completion with quality validation
    /// - Parameters:
    ///   - writer: AVAssetWriter to finalize
    ///   - videoInput: Video input to mark as finished
    ///   - audioInput: Optional audio input to mark as finished
    ///   - config: Recording configuration for quality validation
    ///   - qualityMonitor: Optional quality monitor for final validation
    ///   - verbose: Whether to show verbose output
    /// - Throws: OutputError if finalization fails
    func finalizeRecording(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        config: RecordingConfiguration? = nil,
        qualityMonitor: AudioQualityMonitor? = nil,
        verbose: Bool = false
    ) async throws {
        // Perform quality validation before finalization if config is provided
        if let config = config, audioInput != nil {
            let qualityResult = validateAudioQuality(for: config, qualityMonitor: qualityMonitor)
            
            if verbose {
                print("🎵 Audio Quality Validation:")
                print("   Status: \(qualityResult.status.description)")
                print("   Score: \(String(format: "%.2f", qualityResult.qualityScore))")
                
                if !qualityResult.issues.isEmpty {
                    print("   Issues:")
                    for issue in qualityResult.issues {
                        print("     • \(issue)")
                    }
                }
                
                if !qualityResult.recommendations.isEmpty {
                    print("   Recommendations:")
                    for recommendation in qualityResult.recommendations {
                        print("     • \(recommendation)")
                    }
                }
            }
            
            // Log quality metrics if available
            if let metrics = qualityResult.metrics, verbose {
                print("   Peak: \(String(format: "%.1f", metrics.peakLevel)) dBFS")
                print("   RMS: \(String(format: "%.1f", metrics.rmsLevel)) dBFS")
                print("   THD: \(String(format: "%.3f", metrics.thd * 100))%")
                print("   Clipping: \(metrics.clippingDetected ? "⚠️ Detected" : "✅ None")")
            }
        }
        
        try await finalizeRecordingInternal(writer: writer, videoInput: videoInput, audioInput: audioInput, verbose: verbose)
    }
    
    /// Internal finalization method (original implementation)
    /// - Parameters:
    ///   - writer: AVAssetWriter to finalize
    ///   - videoInput: Video input to mark as finished
    ///   - audioInput: Optional audio input to mark as finished
    ///   - verbose: Whether to show verbose output
    /// - Throws: OutputError if finalization fails
    private func finalizeRecordingInternal(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        verbose: Bool = false
    ) async throws {
        // Inputs should already be marked as finished by the caller
        // This avoids double-marking which could cause issues
        
        if verbose {
            print("💾 Starting file finalization...")
            print("   Writer status: \(writer.status.rawValue) (\(Self.writerStatusDescription(writer.status)))")
            print("   Video input ready: \(videoInput.isReadyForMoreMediaData)")
            if let audioInput = audioInput {
                print("   Audio input ready: \(audioInput.isReadyForMoreMediaData)")
            }
        }
        
        // Note: Inputs should already be marked as finished by the caller
        // We don't mark them here to avoid double-marking
        
        // Wait for writing to complete
        try await withCheckedThrowingContinuation { continuation in
            if verbose {
                print("💾 Calling writer.finishWriting...")
            }
            let startTime = Date()
            
            writer.finishWriting {
                let duration = Date().timeIntervalSince(startTime)
                if verbose {
                    print("💾 finishWriting completion handler called after \(String(format: "%.2f", duration))s")
                    let statusDescription = Self.writerStatusDescription(writer.status)
                    print("   Final writer status: \(writer.status.rawValue) (\(statusDescription))")
                }
                
                if writer.status == .completed {
                    if verbose {
                        print("✅ Writer finalization completed successfully")
                    }
                    continuation.resume()
                } else if let error = writer.error {
                    if verbose {
                        print("❌ Writer finalization failed with error: \(error.localizedDescription)")
                        print("   Error domain: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: OutputError.writerCreationFailed(error))
                } else {
                    if verbose {
                        print("❌ Writer finalization failed with unknown error")
                        print("   Writer status: \(writer.status.rawValue)")
                    }
                    let unknownError = NSError(
                        domain: "com.swiftcapture.output",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown writing error - status: \(writer.status.rawValue)"]
                    )
                    continuation.resume(throwing: OutputError.writerCreationFailed(unknownError))
                }
            }
        }
        
        if verbose {
            print("💾 File finalization completed")
        }
    }
    
    /// Finalize recording (backward compatibility method)
    /// - Parameters:
    ///   - writer: AVAssetWriter to finalize
    ///   - videoInput: Video input to mark as finished
    ///   - audioInput: Optional audio input to mark as finished
    ///   - verbose: Whether to show verbose output
    /// - Throws: OutputError if finalization fails
    func finalizeRecording(
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        verbose: Bool = false
    ) async throws {
        try await finalizeRecordingInternal(writer: writer, videoInput: videoInput, audioInput: audioInput, verbose: verbose)
    }
    
    /// Get human-readable description of AVAssetWriter status
    /// - Parameter status: AVAssetWriter.Status
    /// - Returns: Human-readable description
    private static func writerStatusDescription(_ status: AVAssetWriter.Status) -> String {
        switch status {
        case .unknown:
            return "unknown"
        case .writing:
            return "writing"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        case .cancelled:
            return "cancelled"
        @unknown default:
            return "unknown_case_\(status.rawValue)"
        }
    }
}