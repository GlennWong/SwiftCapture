import Foundation
@preconcurrency import AVFoundation
import CoreGraphics

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
    
    /// Create audio input with quality settings
    /// - Parameter config: Recording configuration
    /// - Returns: Configured AVAssetWriterInput for audio
    /// - Throws: OutputError if creation fails
    func createAudioInput(for config: RecordingConfiguration) throws -> AVAssetWriterInput {
        let settings = config.audioSettings.avSettings
        
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        return input
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
                print("   Audio Settings: \(config.audioSettings.quality.rawValue) quality, \(config.audioSettings.sampleRate) Hz")
            } else {
                print("   Audio: disabled")
            }
        }
        
        return (writer: writer, videoInput: videoInput, audioInput: audioInput, adaptor: adaptor)
    }
    
    /// Finalize recording and wait for completion
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