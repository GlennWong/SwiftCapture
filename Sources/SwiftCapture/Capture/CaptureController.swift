import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit
import CoreGraphics

/// Controls the actual screen capture process using ScreenCaptureKit
/// Provides modular recording functionality with proper error handling
@available(macOS 12.3, *)
class CaptureController {
    
    private var currentDelegate: CaptureDelegate?
    private var currentStream: SCStream?
    private var isStreamStopped = false
    
    /// Access to the current quality monitor for external validation
    var qualityMonitor: AudioQualityMonitor? {
        return currentDelegate?.audioQualityMonitor
    }
    
    /// Error types for capture operations
    enum CaptureError: LocalizedError {
        case contentRetrievalFailed(Error)
        case streamCreationFailed(Error)
        case captureStartFailed(Error)
        case captureStopFailed(Error)
        case configurationError(String)
        
        var errorDescription: String? {
            switch self {
            case .contentRetrievalFailed(let error):
                return "Failed to retrieve shareable content: \(error.localizedDescription)"
            case .streamCreationFailed(let error):
                return "Failed to create capture stream: \(error.localizedDescription)"
            case .captureStartFailed(let error):
                return "Failed to start capture: \(error.localizedDescription)"
            case .captureStopFailed(let error):
                return "Failed to stop capture: \(error.localizedDescription)"
            case .configurationError(let message):
                return "Configuration error: \(message)"
            }
        }
    }
    
    /// Delegate for handling capture output
    private class CaptureDelegate: NSObject, SCStreamOutput, AudioLevelMeterDelegate, AudioSpectrumAnalyzerDelegate, AudioQualityMonitorDelegate {
        let videoInput: AVAssetWriterInput
        let audioInput: AVAssetWriterInput?
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let writer: AVAssetWriter
        private var startTime: CMTime?
        private var shouldStop = false
        private var frameCount = 0
        private var audioSampleCount = 0
        
        // 麦克风录制相关
        private var audioEngine: AVAudioEngine?
        private var microphoneInput: AVAssetWriterInput?
        private var audioMixer: AVAudioMixerNode?
        private let includeMicrophone: Bool
        
        // 音频处理管道
        private var audioProcessor: AudioProcessor?
        private var audioSettings: AudioSettings
        private var processingQueue: DispatchQueue
        private var audioBufferPool: [AVAudioPCMBuffer] = []
        private let maxPoolSize: Int = 10
        
        // 实时监测组件
        private var levelMeter: AudioLevelMeter?
        private var spectrumAnalyzer: AudioSpectrumAnalyzer?
        private var qualityMonitor: AudioQualityMonitor?
        private var monitoringDisplay: AudioMonitoringDisplay?
        
        // 音频状态显示
        private var audioStatusDisplay: AudioStatusDisplay?
        
        /// Access to quality monitor for external validation
        var audioQualityMonitor: AudioQualityMonitor? {
            return qualityMonitor
        }
        
        init(videoInput: AVAssetWriterInput, 
             audioInput: AVAssetWriterInput?, 
             adaptor: AVAssetWriterInputPixelBufferAdaptor, 
             writer: AVAssetWriter,
             audioSettings: AudioSettings,
             includeMicrophone: Bool = false,
             audioStatusDisplay: AudioStatusDisplay? = nil) {
            self.videoInput = videoInput
            self.audioInput = audioInput
            self.adaptor = adaptor
            self.writer = writer
            self.audioSettings = audioSettings
            self.includeMicrophone = includeMicrophone
            self.processingQueue = DispatchQueue(label: "audioProcessingQueue", qos: .userInitiated)
            self.audioStatusDisplay = audioStatusDisplay
            
            super.init()
            
            // 初始化音频处理器（如果启用了音频增强）
            if audioSettings.hasEnhancement {
                setupAudioProcessor()
            }
            
            // 初始化实时监测组件（如果启用了质量监测）
            if audioSettings.qualityMonitoringEnabled {
                setupRealtimeMonitoring()
            }
            
            // 如果需要麦克风，设置音频引擎
            if includeMicrophone {
                setupMicrophoneRecording()
            }
        }
        
        private func setupMicrophoneRecording() {
            do {
                audioEngine = AVAudioEngine()
                guard let audioEngine = audioEngine else { return }
                
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                
                // 创建混音器节点
                audioMixer = AVAudioMixerNode()
                guard let audioMixer = audioMixer else { return }
                
                audioEngine.attach(audioMixer)
                audioEngine.connect(inputNode, to: audioMixer, format: recordingFormat)
                audioEngine.connect(audioMixer, to: audioEngine.outputNode, format: recordingFormat)
                
                // 安装音频处理回调
                audioMixer.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
                    self?.processMicrophoneAudio(buffer: buffer, time: time)
                }
                
                try audioEngine.start()
                print("🎤 Microphone audio engine started successfully")
                
            } catch {
                print("⚠️ Failed to setup microphone recording: \(error.localizedDescription)")
                audioEngine = nil
                audioMixer = nil
            }
        }
        
        private func processMicrophoneAudio(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
            // 暂时只记录麦克风音频处理，避免干扰系统音频录制
            // 实际的音频混合需要更复杂的实现
            if frameCount % 1000 == 0 { // 减少日志频率
                print("🎤 Microphone audio detected (not yet mixed)")
            }
        }
        
        /// 设置音频处理器
        private func setupAudioProcessor() {
            audioProcessor = AudioProcessor(settings: audioSettings.enhancementSettings)
            print("🎛️ Audio processor initialized with preset: \(audioSettings.enhancementSettings.preset.rawValue)")
            print("   Master Gain: \(audioSettings.enhancementSettings.masterGain) dB")
            print("   Auto Gain: \(audioSettings.enhancementSettings.autoGainEnabled ? "enabled" : "disabled")")
            print("   Quality Protection: \(audioSettings.enhancementSettings.qualityProtectionEnabled ? "enabled" : "disabled")")
        }
        
        /// 设置实时监测组件
        private func setupRealtimeMonitoring() {
            // 初始化音频电平表
            levelMeter = AudioLevelMeter()
            levelMeter?.delegate = self
            
            // 初始化频谱分析器
            spectrumAnalyzer = AudioSpectrumAnalyzer()
            spectrumAnalyzer?.delegate = self
            
            // 初始化质量监测器
            qualityMonitor = AudioQualityMonitor()
            qualityMonitor?.delegate = self
            
            // 初始化监测显示（如果需要）
            if audioSettings.enhancementSettings.qualityMonitoringEnabled {
                monitoringDisplay = AudioMonitoringDisplay(settings: audioSettings.enhancementSettings)
            }
            
            print("📊 Real-time audio monitoring initialized")
            print("   Level Meter: enabled")
            print("   Spectrum Analyzer: enabled") 
            print("   Quality Monitor: enabled")
            print("   Display Monitor: \(monitoringDisplay != nil ? "enabled" : "disabled")")
        }
        
        /// 获取或创建音频缓冲区
        private func getAudioBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
            // 尝试从池中获取缓冲区
            for (index, buffer) in audioBufferPool.enumerated() {
                if buffer.format.isEqual(format) && buffer.frameCapacity >= frameCapacity {
                    audioBufferPool.remove(at: index)
                    buffer.frameLength = 0 // 重置长度
                    return buffer
                }
            }
            
            // 创建新缓冲区
            return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        }
        
        /// 回收音频缓冲区到池中
        private func recycleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
            guard audioBufferPool.count < maxPoolSize else { return }
            buffer.frameLength = 0
            audioBufferPool.append(buffer)
        }
        
        /// 处理音频样本缓冲区
        private func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
            // 转换 CMSampleBuffer 到 AVAudioPCMBuffer 用于监测和处理
            guard let audioBuffer = convertToAudioBuffer(sampleBuffer) else {
                print("⚠️ Failed to convert CMSampleBuffer to AVAudioPCMBuffer")
                return sampleBuffer
            }
            
            var processedBuffer = audioBuffer
            
            // 应用音频处理（如果启用）
            if let audioProcessor = audioProcessor, audioSettings.hasEnhancement {
                let processingStartTime = CFAbsoluteTimeGetCurrent()
                do {
                    processedBuffer = try audioProcessor.processAudioBuffer(audioBuffer, settings: audioSettings.enhancementSettings)
                    
                    // 报告处理统计信息到状态显示
                    let processingTime = CFAbsoluteTimeGetCurrent() - processingStartTime
                    let metrics = audioProcessor.getAudioMetrics()
                    audioStatusDisplay?.updateProcessingStats(
                        processingTime: processingTime,
                        peakLevel: metrics.peakLevel,
                        rmsLevel: metrics.rmsLevel,
                        thd: metrics.thd,
                        gain: audioSettings.enhancementSettings.masterGain
                    )
                    
                } catch {
                    print("⚠️ Audio processing failed: \(error.localizedDescription)")
                    audioStatusDisplay?.reportQualityIssue("Audio processing failed: \(error.localizedDescription)", severity: 0.8)
                    processedBuffer = audioBuffer // 使用原始缓冲区作为后备
                }
            }
            
            // 更新实时监测组件
            updateRealtimeMonitoring(with: processedBuffer)
            
            // 转换回 CMSampleBuffer
            let result: CMSampleBuffer?
            if processedBuffer === audioBuffer {
                // 如果没有处理，直接返回原始缓冲区
                result = sampleBuffer
            } else {
                // 转换处理后的缓冲区
                result = convertToCMSampleBuffer(processedBuffer, originalSampleBuffer: sampleBuffer) ?? sampleBuffer
            }
            
            // 回收缓冲区
            recycleAudioBuffer(audioBuffer)
            if processedBuffer !== audioBuffer {
                recycleAudioBuffer(processedBuffer)
            }
            
            return result
        }
        
        /// 更新实时监测组件
        private func updateRealtimeMonitoring(with buffer: AVAudioPCMBuffer) {
            // 更新音频电平表
            levelMeter?.processBuffer(buffer)
            
            // 更新频谱分析器
            spectrumAnalyzer?.processBuffer(buffer)
            
            // 更新质量监测器
            do {
                try qualityMonitor?.processAudioBuffer(buffer)
                
                // 检查质量问题并报告给状态显示
                if let qualityMonitor = qualityMonitor {
                    let metrics = qualityMonitor.getCurrentMetrics()
                    
                    // 检查削波
                    if metrics.clippingDetected {
                        audioStatusDisplay?.reportClipping(at: metrics.peakLevel)
                    }
                    
                    // 检查THD超标
                    if metrics.thd > audioSettings.enhancementSettings.maxTHD {
                        audioStatusDisplay?.reportQualityIssue(
                            "THD exceeded threshold: \(String(format: "%.3f", metrics.thd * 100))%",
                            severity: 0.6
                        )
                    }
                }
                
            } catch {
                // 质量监测错误不应该影响录制，只记录日志
                if frameCount % 1000 == 0 { // 减少错误日志频率
                    print("⚠️ Quality monitoring error: \(error.localizedDescription)")
                    audioStatusDisplay?.reportQualityIssue("Quality monitoring error: \(error.localizedDescription)", severity: 0.4)
                }
            }
            
            // 更新监测显示
            monitoringDisplay?.processBuffer(buffer)
        }
        
        /// 将 CMSampleBuffer 转换为 AVAudioPCMBuffer
        private func convertToAudioBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
            guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return nil
            }
            
            guard let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
                return nil
            }
            
            let audioFormat = AVAudioFormat(streamDescription: audioStreamBasicDescription)
            guard let format = audioFormat else { return nil }
            
            let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
            guard let audioBuffer = getAudioBuffer(format: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
                return nil
            }
            
            audioBuffer.frameLength = AVAudioFrameCount(frameCount)
            
            // 复制音频数据
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                return nil
            }
            
            var dataPointer: UnsafeMutablePointer<Int8>?
            var lengthAtOffset: Int = 0
            let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: nil, dataPointerOut: &dataPointer)
            
            guard status == noErr, let data = dataPointer else {
                return nil
            }
            
            // 复制数据到 AVAudioPCMBuffer
            let channelCount = Int(format.channelCount)
            let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
            let _ = bytesPerFrame / channelCount // bytesPerSample not used in current implementation
            
            if let floatChannelData = audioBuffer.floatChannelData {
                let sourceData = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: lengthAtOffset / MemoryLayout<Float>.size)
                
                if format.isInterleaved {
                    // 交错格式：需要分离通道
                    for frame in 0..<frameCount {
                        for channel in 0..<channelCount {
                            floatChannelData[channel][frame] = sourceData[frame * channelCount + channel]
                        }
                    }
                } else {
                    // 非交错格式：直接复制
                    for channel in 0..<channelCount {
                        let channelData = sourceData.advanced(by: channel * frameCount)
                        floatChannelData[channel].update(from: channelData, count: frameCount)
                    }
                }
            }
            
            return audioBuffer
        }
        
        /// 将 AVAudioPCMBuffer 转换回 CMSampleBuffer
        private func convertToCMSampleBuffer(_ audioBuffer: AVAudioPCMBuffer, originalSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
            // 这是一个简化的实现，实际项目中可能需要更复杂的转换
            // 对于实时处理，通常直接修改原始缓冲区会更高效
            
            guard let formatDescription = CMSampleBufferGetFormatDescription(originalSampleBuffer) else {
                return nil
            }
            
            let frameCount = Int(audioBuffer.frameLength)
            let channelCount = Int(audioBuffer.format.channelCount)
            let bytesPerFrame = channelCount * MemoryLayout<Float>.size
            let dataSize = frameCount * bytesPerFrame
            
            // 创建数据缓冲区
            var blockBuffer: CMBlockBuffer?
            let status = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataSize,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataSize,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            guard status == noErr, let buffer = blockBuffer else {
                return nil
            }
            
            // 复制音频数据
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(buffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
            
            if let data = dataPointer, let floatChannelData = audioBuffer.floatChannelData {
                let floatData = UnsafeMutableRawPointer(data).bindMemory(to: Float.self, capacity: dataSize / MemoryLayout<Float>.size)
                
                if audioBuffer.format.isInterleaved {
                    // 交错格式
                    for frame in 0..<frameCount {
                        for channel in 0..<channelCount {
                            floatData[frame * channelCount + channel] = floatChannelData[channel][frame]
                        }
                    }
                } else {
                    // 非交错格式
                    for channel in 0..<channelCount {
                        let channelData = floatData.advanced(by: channel * frameCount)
                        for frame in 0..<frameCount {
                            channelData[frame] = floatChannelData[channel][frame]
                        }
                    }
                }
            }
            
            // 创建新的 CMSampleBuffer
            var newSampleBuffer: CMSampleBuffer?
            var timing = CMSampleTimingInfo()
            let timingStatus = CMSampleBufferGetSampleTimingInfo(originalSampleBuffer, at: 0, timingInfoOut: &timing)
            
            guard timingStatus == noErr else {
                return nil
            }
            
            CMSampleBufferCreate(
                allocator: kCFAllocatorDefault,
                dataBuffer: buffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: formatDescription,
                sampleCount: frameCount,
                sampleTimingEntryCount: 1,
                sampleTimingArray: [timing],
                sampleSizeEntryCount: 0,
                sampleSizeArray: nil,
                sampleBufferOut: &newSampleBuffer
            )
            
            return newSampleBuffer
        }
        
        func stopCapture() {
            shouldStop = true
            
            // 停止音频处理器
            audioProcessor?.reset()
            audioProcessor = nil
            
            // 清理音频缓冲区池
            audioBufferPool.removeAll()
            
            // 停止麦克风录制
            if let audioEngine = audioEngine {
                audioMixer?.removeTap(onBus: 0)
                audioEngine.stop()
                print("🎤 Microphone audio engine stopped")
            }
            
            print("🎵 Audio processing pipeline stopped")
        }
        
        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
            // Stop processing if we've been told to stop
            if shouldStop {
                return
            }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            // Initialize session timing on first frame
            if startTime == nil {
                startTime = timestamp
                writer.startSession(atSourceTime: startTime!)
            }
            
            // Don't check duration here - let the main recording loop handle timing
            
            switch outputType {
            case .screen:
                guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
                

                
                if videoInput.isReadyForMoreMediaData && !shouldStop {
                    let success = adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                    frameCount += 1
                    if !success {
                        print("⚠️ Failed to append video frame at timestamp: \(CMTimeGetSeconds(timestamp))")
                        print("   Frame count: \(frameCount), Video input ready: \(videoInput.isReadyForMoreMediaData)")
                    } else if frameCount % 600 == 0 { // Log every 600 frames (20 seconds at 30fps)
                        print("📹 Video frames processed: \(frameCount) (timestamp: \(String(format: "%.2f", CMTimeGetSeconds(timestamp)))s)")
                    }
                }
            case .audio:
                if let audioInput = audioInput, audioInput.isReadyForMoreMediaData && !shouldStop {
                    // 在后台队列中处理音频以避免阻塞主录制流程
                    processingQueue.async { [weak self] in
                        guard let self = self else { return }
                        
                        // 应用音频处理（如果启用）
                        let processedSampleBuffer = self.processAudioSampleBuffer(sampleBuffer) ?? sampleBuffer
                        
                        // 在主队列中写入处理后的音频
                        DispatchQueue.main.async {
                            guard !self.shouldStop && audioInput.isReadyForMoreMediaData else { return }
                            
                            let success = audioInput.append(processedSampleBuffer)
                            self.audioSampleCount += 1
                            
                            if !success {
                                print("⚠️ Failed to append processed audio sample at timestamp: \(CMTimeGetSeconds(timestamp))")
                                print("   Audio samples: \(self.audioSampleCount), Audio input ready: \(audioInput.isReadyForMoreMediaData)")
                            } else if self.audioSampleCount % 1000 == 0 { // Log every 1000 audio samples
                                let processingStatus = self.audioProcessor != nil ? "enhanced" : "direct"
                                print("🎵 Audio samples processed: \(self.audioSampleCount) (\(processingStatus), timestamp: \(String(format: "%.2f", CMTimeGetSeconds(timestamp)))s)")
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        
        /// 开始实时监测显示
        func startMonitoringDisplay() {
            monitoringDisplay?.startDisplay()
        }
        
        /// 停止实时监测显示
        func stopMonitoringDisplay() {
            monitoringDisplay?.stopDisplay()
        }
        
        /// 获取当前监测状态
        func getMonitoringStatus() -> [String: Any] {
            var status: [String: Any] = [
                "frameCount": frameCount,
                "audioSampleCount": audioSampleCount,
                "processingEnabled": audioProcessor != nil,
                "monitoringEnabled": levelMeter != nil
            ]
            
            if let levelMeter = levelMeter {
                status["audioLevels"] = [
                    "peak": levelMeter.peakLevel,
                    "rms": levelMeter.rmsLevel,
                    "description": levelMeter.getLevelsDescription()
                ]
            }
            
            if let spectrumAnalyzer = spectrumAnalyzer {
                status["spectrum"] = spectrumAnalyzer.getBandSpectrum()
            }
            
            if let qualityMonitor = qualityMonitor {
                let metrics = qualityMonitor.getCurrentMetrics()
                status["quality"] = [
                    "thd": metrics.thd,
                    "clippingDetected": metrics.clippingDetected,
                    "dynamicRange": metrics.dynamicRange
                ]
            }
            
            return status
        }
        
        // MARK: - AudioLevelMeterDelegate
        
        func levelMeterUpdated(peak: Float, rms: Float) {
            // 可以在这里添加实时电平监测的回调处理
            // 例如：检测音频电平过低或过高的情况
            if peak > -3.0 && frameCount % 100 == 0 { // 每100帧检查一次，避免过多日志
                print("⚠️ Audio level approaching clipping: \(String(format: "%.1f", peak)) dBFS")
            }
        }
        
        // MARK: - AudioSpectrumAnalyzerDelegate
        
        func spectrumAnalyzerUpdated(magnitudes: [Float], frequencies: [Float]) {
            // 可以在这里添加频谱分析的回调处理
            // 例如：检测特定频率范围的能量分布
        }
        
        // MARK: - AudioQualityMonitorDelegate
        
        func audioQualityUpdated(_ metrics: AudioMetrics) {
            // 质量指标更新，可以用于实时质量监控
        }
        
        func audioQualityIssueDetected(_ issue: String, severity: Float) {
            // 音频质量问题检测
            if severity > 0.5 {
                print("⚠️ Audio quality issue in capture: \(issue)")
            }
        }
        
        func clippingDetected(at level: Float) {
            // 削波检测
            print("📢 Audio clipping detected in capture at \(String(format: "%.1f", level)) dBFS")
        }
        
        func qualityDegradationDetected(originalMetrics: AudioMetrics, processedMetrics: AudioMetrics, recommendedAction: QualityProtectionAction) {
            // 质量退化检测
            print("🔍 Quality degradation detected in capture - recommended action: \(recommendedAction)")
        }
        
        func losslessModeRecommended(reason: String) {
            // 无损模式推荐
            print("🔒 Lossless mode recommended in capture: \(reason)")
        }
    }
    
    /// Start screen capture with the given configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - writer: AVAssetWriter for output
    ///   - videoInput: Video input for the writer
    ///   - audioInput: Optional audio input for the writer
    ///   - adaptor: Pixel buffer adaptor for video
    /// - Returns: SCStream instance for the capture
    /// - Throws: CaptureError if capture setup fails
    func startCapture(
        with config: RecordingConfiguration,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        audioStatusDisplay: AudioStatusDisplay? = nil
    ) async throws -> SCStream {
        
        // 🔧 修复：对于应用录制，先将应用置于前台
        if config.recordingMode == .application, let targetApp = config.targetApplication {
            do {
                let appManager = ApplicationManager()
                try appManager.bringApplicationToFront(targetApp)
                
                // 给系统更多时间来完成窗口切换和桌面空间切换
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                
                print("   Waiting for application to be fully visible...")
            } catch {
                print("⚠️ Warning: Could not bring application to front: \(error.localizedDescription)")
                print("   Recording will continue, but the application may be obscured")
            }
        }
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.contentRetrievalFailed(error)
        }
        
        // Create stream configuration
        let streamConfig = try createStreamConfiguration(from: config, content: content)
        
        // Create content filter
        let filter = try createContentFilter(from: config, content: content)
        
        // Create capture delegate
        let delegate = CaptureDelegate(
            videoInput: videoInput,
            audioInput: audioInput,
            adaptor: adaptor,
            writer: writer,
            audioSettings: config.audioSettings,
            includeMicrophone: config.audioSettings.includeMicrophone,
            audioStatusDisplay: audioStatusDisplay
        )
        
        // Store delegate reference for later use
        self.currentDelegate = delegate
        
        // Create stream
        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        
        // Store stream reference and reset stopped flag
        self.currentStream = stream
        self.isStreamStopped = false
        
        // Add stream outputs
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
        let audioQueue = DispatchQueue(label: "audioQueue", qos: .userInitiated)
        
        do {
            try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: videoQueue)
        } catch {
            throw CaptureError.captureStartFailed(error)
        }
        
        // Add audio output if enabled
        if config.audioSettings.hasAudio {
            do {
                if #available(macOS 13.0, *) {
                    try stream.addStreamOutput(delegate, type: .audio, sampleHandlerQueue: audioQueue)
                    if config.verbose {
                        print("✅ System audio stream added successfully")
                        if config.audioSettings.hasEnhancement {
                            print("🎛️ Audio enhancement pipeline enabled:")
                            print("   Preset: \(config.audioSettings.enhancementSettings.preset.rawValue)")
                            print("   Master Gain: \(config.audioSettings.enhancementSettings.masterGain) dB")
                            print("   Auto Gain: \(config.audioSettings.enhancementSettings.autoGainEnabled ? "enabled" : "disabled")")
                            print("   Quality Protection: \(config.audioSettings.enhancementSettings.qualityProtectionEnabled ? "enabled" : "disabled")")
                        }
                    }
                }
            } catch {
                print("⚠️ Warning: Failed to add system audio output: \(error.localizedDescription)")
                // Continue without system audio rather than failing completely
            }
        }
        
        // 🔧 新增：如果启用了麦克风，需要单独处理麦克风音频
        if config.audioSettings.includeMicrophone {
            print("🎤 Microphone recording enabled - will be mixed with system audio")
            // 注意：ScreenCaptureKit 主要处理系统音频，麦克风音频需要通过 AVAudioEngine 单独处理
            // 这需要在 OutputManager 中实现音频混合逻辑
        }
        
        // Start capture
        do {
            try await stream.startCapture()
        } catch {
            throw CaptureError.captureStartFailed(error)
        }
        
        return stream
    }
    
    /// Stop screen capture
    /// - Parameter stream: SCStream to stop
    /// - Throws: CaptureError if stop fails
    func stopCapture(_ stream: SCStream) async throws {
        // Check if this stream has already been stopped
        guard !isStreamStopped else {
            print("ℹ️ Stream stop already in progress or completed, skipping...")
            return
        }
        
        // Mark as stopped to prevent concurrent stop attempts
        isStreamStopped = true
        
        // First tell the delegate to stop processing new frames
        currentDelegate?.stopCapture()
        
        // Stop monitoring display before stopping capture
        currentDelegate?.stopMonitoringDisplay()
        
        do {
            try await stream.stopCapture()
        } catch {
            // Check if the error is about stopping an already stopped stream
            let nsError = error as NSError
            if nsError.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" && nsError.code == -3808 {
                // Stream is already stopped, this is not an error in our context
                print("ℹ️ Stream was already stopped, continuing cleanup...")
            } else {
                throw CaptureError.captureStopFailed(error)
            }
        }
        
        // Clear references
        currentDelegate = nil
        currentStream = nil
    }
    
    /// Start real-time audio monitoring display
    func startMonitoringDisplay() {
        currentDelegate?.startMonitoringDisplay()
    }
    
    /// Stop real-time audio monitoring display
    func stopMonitoringDisplay() {
        currentDelegate?.stopMonitoringDisplay()
    }
    
    /// Get current monitoring status
    /// - Returns: Dictionary with monitoring information
    func getMonitoringStatus() -> [String: Any] {
        return currentDelegate?.getMonitoringStatus() ?? [
            "error": "No active capture session"
        ]
    }
    
    /// Create ScreenCaptureKit stream configuration from recording configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content for validation
    /// - Returns: Configured SCStreamConfiguration
    /// - Throws: CaptureError if configuration is invalid
    private func createStreamConfiguration(
        from config: RecordingConfiguration, 
        content: SCShareableContent
    ) throws -> SCStreamConfiguration {
        
        let streamConfig = SCStreamConfiguration()
        
        // Configure recording area and resolution
        let (sourceRect, outputSize) = try calculateRecordingDimensions(
            config: config, 
            content: content
        )
        
        streamConfig.sourceRect = sourceRect
        streamConfig.width = Int(outputSize.width)
        streamConfig.height = Int(outputSize.height)
        
        // Configure video settings
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.minimumFrameInterval = config.videoSettings.frameInterval
        streamConfig.showsCursor = config.videoSettings.showCursor
        
        // 🔧 修复：对于应用录制的特殊配置
        if config.recordingMode == .application {
            // 应用录制时的关键设置
            streamConfig.scalesToFit = false  // 禁用自动缩放
            
            // 版本兼容的设置
            if #available(macOS 14.0, *) {
                streamConfig.preservesAspectRatio = true  // 保持宽高比
                streamConfig.captureResolution = .best
            }
            
            // 对于应用录制，不设置sourceRect，让系统自动处理
            if sourceRect == CGRect.null {
                // 不设置sourceRect，使用完整窗口
                print("   Using full window capture (no sourceRect)")
            }
        } else {
            // 屏幕录制时保持原有设置
            streamConfig.scalesToFit = false
        }
        
        // Configure color space and quality
        streamConfig.colorSpaceName = CGColorSpace.displayP3
        streamConfig.backgroundColor = CGColor.clear
        
        // Configure advanced settings for macOS 14+
        if #available(macOS 14.0, *) {
            streamConfig.queueDepth = 8
        }
        
        // Configure audio if enabled
        if config.audioSettings.hasAudio {
            if #available(macOS 13.0, *) {
                streamConfig.capturesAudio = true
            }
        }
        
        // Log capture configuration only in verbose mode
        if config.verbose {
            print("📹 Capture Configuration:")
            print("   Recording Mode: \(config.recordingMode)")
            if let screen = config.targetScreen {
                print("   Target Screen: \(screen.index) (\(screen.name))")
                print("   Screen Frame: \(screen.frame)")
                print("   Scale Factor: \(screen.scaleFactor)x")
            }
            print("   Source Rect: \(sourceRect)")
            print("   Output Size: \(Int(outputSize.width)) × \(Int(outputSize.height))")
            print("   Frame Rate: \(config.videoSettings.fps) fps")
            print("   Show Cursor: \(config.videoSettings.showCursor)")
            print("   Audio Enabled: \(config.audioSettings.hasAudio)")
        }
        return streamConfig
    }
    
    /// Create content filter based on recording configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content
    /// - Returns: Configured SCContentFilter
    /// - Throws: CaptureError if filter creation fails
    private func createContentFilter(
        from config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> SCContentFilter {
        
        // 🔧 智能混合模式：当应用录制需要系统音频且不包含麦克风时，切换到屏幕录制模式
        // 如果同时需要麦克风，保持应用录制模式并尝试混合音频
        if config.recordingMode == .application && config.audioSettings.forceSystemAudio && !config.audioSettings.includeMicrophone {
            print("🔄 Smart Hybrid Mode: Switching to screen recording for system-wide audio")
            print("   Will record the screen area containing the application window")
            
            guard let targetApp = config.targetApplication else {
                throw CaptureError.configurationError("No target application specified")
            }
            
            // 找到应用窗口
            let appWindows = content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
            }
            
            guard let appWindow = appWindows.first else {
                throw CaptureError.configurationError("No windows found for target application '\(targetApp.name)'")
            }
            
            // 找到包含应用窗口的显示器
            let windowCenter = CGPoint(
                x: appWindow.frame.origin.x + appWindow.frame.width / 2,
                y: appWindow.frame.origin.y + appWindow.frame.height / 2
            )
            
            var targetDisplay: SCDisplay?
            let screens = NSScreen.screens
            
            for screen in screens {
                if screen.frame.contains(windowCenter) {
                    let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    targetDisplay = content.displays.first { $0.displayID == screenNumber }
                    break
                }
            }
            
            if targetDisplay == nil {
                targetDisplay = content.displays.first { $0.displayID == CGMainDisplayID() } ?? content.displays.first!
            }
            
            print("   Target Display: ID \(targetDisplay!.displayID)")
            print("   Window Area: \(Int(appWindow.frame.origin.x)), \(Int(appWindow.frame.origin.y)), \(Int(appWindow.frame.width)) × \(Int(appWindow.frame.height))")
            
            return SCContentFilter(display: targetDisplay!, excludingWindows: [])
        }
        
        switch config.recordingMode {
        case .screen:
            // Screen recording mode
            let targetDisplay: SCDisplay
            
            if let screenInfo = config.targetScreen {
                // Find the display matching the screen info
                guard let display = content.displays.first(where: { $0.displayID == screenInfo.displayID }) else {
                    throw CaptureError.configurationError("Target screen not found in available displays")
                }
                targetDisplay = display
            } else {
                // Use primary display
                guard let display = content.displays.first else {
                    throw CaptureError.configurationError("No displays available for recording")
                }
                targetDisplay = display
            }
            
            return SCContentFilter(display: targetDisplay, excludingWindows: [])
            
        case .application:
            // Application recording mode
            guard let targetApp = config.targetApplication else {
                throw CaptureError.configurationError("No target application specified for application recording")
            }
            
            // Find the application in shareable content
            guard content.applications.contains(where: { 
                $0.bundleIdentifier == targetApp.bundleIdentifier 
            }) else {
                throw CaptureError.configurationError("Target application not found in shareable content")
            }
            
            // Get windows for the application
            let appWindows = content.windows.filter { window in
                window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
            }
            
            if appWindows.isEmpty {
                throw CaptureError.configurationError("No windows found for target application '\(targetApp.name)'")
            }
            
            // 🔧 修复：选择最佳窗口进行录制
            // 优先选择有标题且尺寸较大的窗口（通常是主窗口）
            let bestWindow = appWindows.max { lhs, rhs in
                // 首先比较是否有标题
                let lhsHasTitle = !(lhs.title?.isEmpty ?? true)
                let rhsHasTitle = !(rhs.title?.isEmpty ?? true)
                
                if lhsHasTitle != rhsHasTitle {
                    return rhsHasTitle // 有标题的窗口优先
                }
                
                // 如果都有标题或都没标题，比较窗口面积
                let lhsArea = lhs.frame.width * lhs.frame.height
                let rhsArea = rhs.frame.width * rhs.frame.height
                return lhsArea < rhsArea // 面积大的窗口优先
            } ?? appWindows.first!
            
            print("🎯 Selected window for recording:")
            print("   Title: '\((bestWindow.title?.isEmpty ?? true) ? "Untitled" : bestWindow.title!)'")
            print("   Size: \(Int(bestWindow.frame.width)) × \(Int(bestWindow.frame.height))")
            print("   Position: (\(Int(bestWindow.frame.origin.x)), \(Int(bestWindow.frame.origin.y)))")
            

            
            return SCContentFilter(desktopIndependentWindow: bestWindow)
        }
    }
    
    /// Calculate recording dimensions based on configuration
    /// - Parameters:
    ///   - config: Recording configuration
    ///   - content: Shareable content for screen information
    /// - Returns: Tuple of source rect and output size
    /// - Throws: CaptureError if calculation fails
    private func calculateRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        // 🔧 处理混合模式：应用录制 + 系统音频 = 屏幕录制模式但使用应用窗口区域
        if config.recordingMode == .application && config.audioSettings.forceSystemAudio {
            return try calculateHybridRecordingDimensions(config: config, content: content)
        }
        
        switch config.recordingMode {
        case .screen:
            return try calculateScreenRecordingDimensions(config: config, content: content)
        case .application:
            return try calculateApplicationRecordingDimensions(config: config, content: content)
        }
    }
    
    /// Calculate dimensions for screen recording
    private func calculateScreenRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        let targetDisplay: SCDisplay
        
        if let screenInfo = config.targetScreen {
            guard let display = content.displays.first(where: { $0.displayID == screenInfo.displayID }) else {
                throw CaptureError.configurationError("Target screen not found")
            }
            targetDisplay = display
        } else {
            guard let display = content.displays.first else {
                throw CaptureError.configurationError("No displays available")
            }
            targetDisplay = display
        }
        
        // Get screen information from NSScreen for scale factor
        let screens = NSScreen.screens
        guard let nsScreen = screens.first(where: { 
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == targetDisplay.displayID 
        }) else {
            throw CaptureError.configurationError("Could not find NSScreen for display")
        }
        
        let scaleFactor = nsScreen.backingScaleFactor
        let logicalFrame = nsScreen.frame
        
        // 🔧 修复：使用屏幕本地坐标系计算录制区域
        let screenInfo = ScreenInfo(
            index: 1,
            displayID: targetDisplay.displayID,
            frame: logicalFrame,
            name: "Display",
            isPrimary: true,
            scaleFactor: scaleFactor
        )
        
        // 获取录制区域（像素坐标）
        let recordingRect = config.recordingArea.toCGRect(for: screenInfo)
        let actualWidth = Int(recordingRect.width)
        let actualHeight = Int(recordingRect.height)
        
        // 🔧 关键修复：对于ScreenCaptureKit，使用屏幕本地逻辑坐标
        // 不需要考虑屏幕在全局坐标系中的偏移
        let logicalSourceRect = config.recordingArea.toLogicalRect(for: screenInfo)
        
        return (
            sourceRect: logicalSourceRect,
            outputSize: CGSize(width: actualWidth, height: actualHeight)
        )
    }
    
    /// Calculate dimensions for application recording
    private func calculateApplicationRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        guard let targetApp = config.targetApplication else {
            throw CaptureError.configurationError("No target application specified")
        }
        
        // Find application windows in ScreenCaptureKit content
        let appWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
        }
        
        guard !appWindows.isEmpty else {
            throw CaptureError.configurationError("No windows found for target application '\(targetApp.name)'")
        }
        
        // 🔧 修复：使用与内容过滤器相同的窗口选择逻辑
        let scWindow = appWindows.max { lhs, rhs in
            // 首先比较是否有标题
            let lhsHasTitle = !(lhs.title?.isEmpty ?? true)
            let rhsHasTitle = !(rhs.title?.isEmpty ?? true)
            
            if lhsHasTitle != rhsHasTitle {
                return rhsHasTitle // 有标题的窗口优先
            }
            
            // 如果都有标题或都没标题，比较窗口面积
            let lhsArea = lhs.frame.width * lhs.frame.height
            let rhsArea = rhs.frame.width * rhs.frame.height
            return lhsArea < rhsArea // 面积大的窗口优先
        } ?? appWindows.first!
        
        // Get the ScreenCaptureKit window frame (this is already in the correct coordinate system)
        let scWindowFrame = scWindow.frame
        
        // Find the display that contains this window to get the correct scale factor
        let windowCenter = CGPoint(
            x: scWindowFrame.origin.x + scWindowFrame.width / 2,
            y: scWindowFrame.origin.y + scWindowFrame.height / 2
        )
        
        // Get the display containing the window center
        let screens = NSScreen.screens
        var scaleFactor: CGFloat = 1.0
        var containingScreen: NSScreen?
        
        for screen in screens {
            // Convert screen frame to match ScreenCaptureKit coordinate system
            let screenFrame = screen.frame
            let flippedScreenFrame = CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: screenFrame.height
            )
            
            if flippedScreenFrame.contains(windowCenter) {
                scaleFactor = screen.backingScaleFactor
                containingScreen = screen
                break
            }
        }
        
        // If no screen contains the window center, use the main screen's scale factor
        if scaleFactor == 1.0 {
            scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
            containingScreen = NSScreen.main
        }
        
        // 🔧 修复：使用ScreenCaptureKit窗口的实际尺寸
        // ScreenCaptureKit已经提供了正确的窗口边界，不需要额外的坐标转换
        let actualWidth = scWindowFrame.width
        let actualHeight = scWindowFrame.height
        
        // 计算输出像素尺寸 - 使用实际窗口尺寸乘以缩放因子
        let outputWidth = Int(actualWidth * scaleFactor)
        let outputHeight = Int(actualHeight * scaleFactor)
        
        print("🔍 Application Recording Debug:")
        print("   Found \(appWindows.count) windows for '\(targetApp.name)'")
        for (index, window) in appWindows.enumerated() {
            let title = (window.title?.isEmpty ?? true) ? "Untitled" : window.title!
            print("     \(index + 1). '\(title)' - \(Int(window.frame.width))×\(Int(window.frame.height))")
        }
        print("   Selected Window: '\((scWindow.title?.isEmpty ?? true) ? "Untitled" : scWindow.title!)'")
        print("   SCWindow Frame: \(Int(scWindowFrame.origin.x)), \(Int(scWindowFrame.origin.y)), \(Int(actualWidth)) × \(Int(actualHeight))")
        print("   Scale Factor: \(scaleFactor)x")
        print("   Output Size (pixels): \(outputWidth) × \(outputHeight)")
        print("   Containing Screen: \(containingScreen?.localizedName ?? "Unknown")")
        
        // 🔧 关键修复：不使用sourceRect，让ScreenCaptureKit自动处理窗口边界
        // 对于应用窗口录制，sourceRect应该设置为CGRect.null或窗口的完整区域
        return (
            sourceRect: CGRect.null, // 让ScreenCaptureKit自动使用完整窗口区域
            outputSize: CGSize(width: outputWidth, height: outputHeight)
        )
    }
    
    /// Calculate dimensions for hybrid recording (app window area on screen for system audio)
    private func calculateHybridRecordingDimensions(
        config: RecordingConfiguration,
        content: SCShareableContent
    ) throws -> (sourceRect: CGRect, outputSize: CGSize) {
        
        guard let targetApp = config.targetApplication else {
            throw CaptureError.configurationError("No target application specified")
        }
        
        // 找到应用窗口
        let appWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == targetApp.bundleIdentifier
        }
        
        guard let appWindow = appWindows.first else {
            throw CaptureError.configurationError("No windows found for target application '\(targetApp.name)'")
        }
        
        // 获取窗口所在的屏幕信息
        let windowCenter = CGPoint(
            x: appWindow.frame.origin.x + appWindow.frame.width / 2,
            y: appWindow.frame.origin.y + appWindow.frame.height / 2
        )
        
        let screens = NSScreen.screens
        var scaleFactor: CGFloat = 1.0
        var containingScreen: NSScreen?
        
        for screen in screens {
            if screen.frame.contains(windowCenter) {
                scaleFactor = screen.backingScaleFactor
                containingScreen = screen
                break
            }
        }
        
        if scaleFactor == 1.0 {
            scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0
            containingScreen = NSScreen.main
        }
        
        // 🔧 混合模式：使用屏幕录制但限制在应用窗口区域
        let windowFrame = appWindow.frame
        let actualWidth = windowFrame.width
        let actualHeight = windowFrame.height
        
        // 计算输出像素尺寸
        let outputWidth = Int(actualWidth * scaleFactor)
        let outputHeight = Int(actualHeight * scaleFactor)
        
        // 🔧 关键：设置 sourceRect 为应用窗口在屏幕上的位置（逻辑坐标）
        // 这样屏幕录制模式只会录制窗口区域，同时获得系统音频
        let sourceRect = CGRect(
            x: windowFrame.origin.x,
            y: windowFrame.origin.y,
            width: actualWidth,
            height: actualHeight
        )
        
        print("🔍 Hybrid Recording Debug:")
        print("   Window Frame: \(Int(windowFrame.origin.x)), \(Int(windowFrame.origin.y)), \(Int(actualWidth)) × \(Int(actualHeight))")
        print("   Scale Factor: \(scaleFactor)x")
        print("   Source Rect (logical): \(Int(sourceRect.origin.x)), \(Int(sourceRect.origin.y)), \(Int(sourceRect.width)) × \(Int(sourceRect.height))")
        print("   Output Size (pixels): \(outputWidth) × \(outputHeight)")
        print("   Containing Screen: \(containingScreen?.localizedName ?? "Unknown")")
        
        return (
            sourceRect: sourceRect,
            outputSize: CGSize(width: outputWidth, height: outputHeight)
        )
    }
}