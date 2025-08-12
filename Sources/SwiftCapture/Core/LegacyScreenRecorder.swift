import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit

/// Legacy screen recorder implementation
/// This will be refactored in later tasks into a more modular architecture
class LegacyScreenRecorder {
    
    // 音频设备切换功能
    static func switchAudioOutput(to deviceName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/SwitchAudioSource")
        task.arguments = ["-s", deviceName]
        do {
            try task.run()
            task.waitUntilExit()
            print("✅ 切换音频输出设备到：\(deviceName)")
        } catch {
            print("⚠️ 切换音频输出设备失败: \(error)")
        }
    }
    
    @available(macOS 12.3, *)
    static func recordWithArea(durationMs: Int, outputPath: String?, fullScreen: Bool, areaString: String?, screenIndex: Int, fps: Int = 30, quality: VideoQuality = .medium, format: OutputFormat = .mov, showCursor: Bool = false) async {
        do {
            let content: SCShareableContent
            do {
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                print("❌ 获取共享内容失败: \(error)")
                return
            }

            guard content.displays.count >= screenIndex else {
                print("❌ 找不到第\(screenIndex)个显示器")
                return
            }
            let targetDisplay = content.displays[screenIndex - 1] // Convert to 0-based index
            let display = targetDisplay

            let config = SCStreamConfiguration()
            
            // 通过 NSScreen 获取实际像素尺寸（考虑 Retina 缩放）
            let screens = NSScreen.screens
            guard screens.count >= screenIndex else {
                print("❌ NSScreen 找不到第\(screenIndex)个显示器")
                return
            }
            let screen = screens[screenIndex - 1] // Convert to 0-based index
            let scaleFactor = screen.backingScaleFactor
            let logicalWidth = Int(screen.frame.width)
            let logicalHeight = Int(screen.frame.height)
            let actualWidth = Int(Double(logicalWidth) * scaleFactor)
            let actualHeight = Int(Double(logicalHeight) * scaleFactor)
            
            print("🖥️ 显示器信息:")
            print("   NSScreen 逻辑尺寸: \(logicalWidth) × \(logicalHeight)")
            print("   缩放因子: \(scaleFactor)")
            print("   实际像素尺寸: \(actualWidth) × \(actualHeight)")
            print("   ScreenCaptureKit 尺寸: \(display.width) × \(display.height)")
            
            let captureWidth: Int
            let captureHeight: Int
            let sourceRect: CGRect
            
            if let areaString = areaString {
                // 解析区域字符串 "x:y:width:height"
                let components = areaString.split(separator: ":").compactMap { Int($0) }
                guard components.count == 4 else {
                    print("❌ 区域格式错误，应为 x:y:width:height")
                    return
                }
                
                let x = components[0]
                let y = components[1] 
                let width = components[2]
                let height = components[3]
                
                print("📹 指定录制区域:")
                print("   区域（像素坐标）: \(x):\(y):\(width):\(height)")
                
                // 验证区域是否在屏幕范围内
                if x + width > actualWidth || y + height > actualHeight {
                    print("❌ 录制区域超出屏幕范围")
                    print("   屏幕尺寸: \(actualWidth) × \(actualHeight)")
                    print("   请求区域: \(x + width) × \(y + height)")
                    return
                }
                
                // 输出尺寸就是指定的像素尺寸
                captureWidth = width
                captureHeight = height
                
                // sourceRect 需要转换为逻辑坐标给 ScreenCaptureKit
                let logicalX = Double(x) / scaleFactor
                let logicalY = Double(y) / scaleFactor
                let logicalW = Double(width) / scaleFactor
                let logicalH = Double(height) / scaleFactor
                sourceRect = CGRect(x: logicalX, y: logicalY, width: logicalW, height: logicalH)
                
                print("   逻辑坐标: \(logicalX):\(logicalY):\(logicalW):\(logicalH)")
                print("   输出尺寸: \(captureWidth) × \(captureHeight)")
                
            } else if fullScreen {
                // 整屏录制
                captureWidth = actualWidth
                captureHeight = actualHeight
                sourceRect = CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
            } else {
                // 3:4 竖屏比例裁剪，从左上角开始截取
                captureHeight = actualHeight
                captureWidth = actualHeight * 3 / 4
                let logicalCropWidth = logicalHeight * 3 / 4
                sourceRect = CGRect(x: 0, y: 0, width: logicalCropWidth, height: logicalHeight)
            }
            
            config.sourceRect = sourceRect
            config.width = captureWidth
            config.height = captureHeight
            
            print("📹 录制配置:")
            print("   源区域（逻辑坐标）: \(sourceRect)")
            print("   输出尺寸（实际像素）: \(captureWidth) × \(captureHeight)")
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
            
            // 关键：确保捕获高分辨率内容
            config.scalesToFit = false  // 不要缩放以适应
            
            // 提高质量设置
            if #available(macOS 14.0, *) {
                config.queueDepth = 8
            }
            config.colorSpaceName = CGColorSpace.displayP3
            config.backgroundColor = CGColor.clear
            config.showsCursor = showCursor

            if #available(macOS 13.0, *) {
                config.capturesAudio = true
            }

            // 设置输出路径
            let outputURL: URL
            if let path = outputPath, !path.isEmpty {
                outputURL = URL(fileURLWithPath: path)
            } else {
                outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("screenRecording.mov")
            }

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            let writer: AVAssetWriter
            do {
                writer = try AVAssetWriter(outputURL: outputURL, fileType: format.avFileType)
            } catch {
                print("❌ 创建 AVAssetWriter 失败: \(error)")
                return
            }
            
            // Create enhanced video settings using VideoSettings model
            let videoSettings = VideoSettings.default(
                fps: fps,
                quality: quality,
                resolution: CGSize(width: captureWidth, height: captureHeight),
                showCursor: showCursor
            )
            let settings = videoSettings.avSettings
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 192000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            writer.add(audioInput)

            // 设置像素缓冲区属性以匹配源格式
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: captureWidth,
                kCVPixelBufferHeightKey as String: captureHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttributes)
            writer.add(input)
            writer.startWriting()

            class Delegate: NSObject, SCStreamOutput {
                let input: AVAssetWriterInput
                let audioInput: AVAssetWriterInput
                let adaptor: AVAssetWriterInputPixelBufferAdaptor
                var startTime: CMTime?
                let writer: AVAssetWriter

                init(input: AVAssetWriterInput, audioInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor, writer: AVAssetWriter) {
                    self.input = input
                    self.audioInput = audioInput
                    self.adaptor = adaptor
                    self.writer = writer
                }

                func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    if startTime == nil {
                        startTime = timestamp
                        writer.startSession(atSourceTime: startTime!)
                    }

                    switch outputType {
                    case .screen:
                        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
                        if input.isReadyForMoreMediaData {
                            adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                        }
                    case .audio:
                        if audioInput.isReadyForMoreMediaData {
                            audioInput.append(sampleBuffer)
                        }
                    default:
                        break
                    }
                }
            }

            let delegate = Delegate(input: input, audioInput: audioInput, adaptor: adaptor, writer: writer)

            let stream = SCStream(
                filter: SCContentFilter(display: display, excludingWindows: []),
                configuration: config,
                delegate: nil
            )

            // 使用专用的高优先级队列处理视频数据
            let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
            let audioQueue = DispatchQueue(label: "audioQueue", qos: .userInitiated)
            
            do {
                try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: videoQueue)
            } catch {
                print("❌ 添加视频流输出失败: \(error)")
                return
            }

            do {
                if #available(macOS 13.0, *) {
                    try stream.addStreamOutput(delegate, type: SCStreamOutputType.audio, sampleHandlerQueue: audioQueue)
                }
            } catch {
                print("❌ 添加音频流输出失败: \(error)")
                return
            }

            do {
                try await stream.startCapture()
            } catch {
                print("❌ 启动录制失败: \(error)")
                return
            }

            let durationSec = Double(durationMs) / 1000.0
            
            // Start progress indicator
            let progressIndicator = ProgressIndicator.startRecording(
                outputURL: outputURL, 
                duration: durationSec
            )
            
            // Setup graceful shutdown handling
            SignalHandler.shared.setupForRecording(
                progressIndicator: progressIndicator
            ) {
                // Graceful shutdown callback
                do {
                    try await stream.stopCapture()
                    input.markAsFinished()
                    audioInput.markAsFinished()
                } catch {
                    print("⚠️ Error during graceful shutdown: \(error.localizedDescription)")
                }
            }
            
            // Record for the specified duration
            try await Task.sleep(nanoseconds: UInt64(durationMs * 1_000_000))

            progressIndicator.updateProgress(message: "Stopping recording...")
            do {
                try await stream.stopCapture()
            } catch {
                print("❌ 停止录制失败: \(error)")
                progressIndicator.stopProgressWithError(error)
                return
            }
            input.markAsFinished()
            audioInput.markAsFinished()

            // 用异步方式等待写入完成
            try await withCheckedThrowingContinuation { continuation in
                writer.finishWriting {
                    if writer.status == .completed {
                        progressIndicator.stopProgress()
                        continuation.resume()
                    } else if let error = writer.error {
                        progressIndicator.stopProgressWithError(error)
                        continuation.resume(throwing: error)
                    } else {
                        let unknownError = NSError(domain: "com.swiftcapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知写入错误"])
                        progressIndicator.stopProgressWithError(unknownError)
                        continuation.resume(throwing: unknownError)
                    }
                }
            }
            
            // Clean up signal handler
            SignalHandler.shared.cleanup()

        } catch {
            print("⚠️ 录制失败：\(error)")
            exit(EXIT_FAILURE)
        }
    }

    @available(macOS 12.3, *)
    static func record(durationMs: Int, outputPath: String?, fullScreen: Bool, fps: Int = 30, quality: VideoQuality = .medium, format: OutputFormat = .mov, showCursor: Bool = false) async {
        do {
            let content: SCShareableContent
            do {
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                print("❌ 获取共享内容失败: \(error)")
                return
            }

            guard content.displays.count >= 2 else {
                print("❌ 找不到第二个显示器")
                return
            }
            let targetDisplay = content.displays[1]
            let display = targetDisplay

            let config = SCStreamConfiguration()
            
            // 使用与 .bak 文件相同的方法获取屏幕尺寸
            // 通过 NSScreen 获取实际像素尺寸（考虑 Retina 缩放）
            let screens = NSScreen.screens
            guard screens.count >= 2 else {
                print("❌ NSScreen 找不到第二个显示器")
                return
            }
            let screen1 = screens[1]
            let scaleFactor = screen1.backingScaleFactor
            let logicalWidth = Int(screen1.frame.width)
            let logicalHeight = Int(screen1.frame.height)
            let actualWidth = Int(Double(logicalWidth) * scaleFactor)
            let actualHeight = Int(Double(logicalHeight) * scaleFactor)
            
            print("🖥️ 显示器信息:")
            print("   NSScreen 逻辑尺寸: \(logicalWidth) × \(logicalHeight)")
            print("   缩放因子: \(scaleFactor)")
            print("   实际像素尺寸: \(actualWidth) × \(actualHeight)")
            print("   ScreenCaptureKit 尺寸: \(display.width) × \(display.height)")
            
            let captureWidth: Int
            let captureHeight: Int
            let sourceRect: CGRect
            
            if fullScreen {
                // 整屏录制
                captureWidth = actualWidth
                captureHeight = actualHeight
                // sourceRect 使用逻辑坐标
                sourceRect = CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
            } else {
                // 3:4 竖屏比例裁剪，从左上角开始截取
                captureHeight = actualHeight
                captureWidth = actualHeight * 3 / 4
                // sourceRect 使用逻辑坐标，但保持 3:4 比例
                let logicalCropWidth = logicalHeight * 3 / 4
                sourceRect = CGRect(x: 0, y: 0, width: logicalCropWidth, height: logicalHeight)
            }
            
            config.sourceRect = sourceRect
            config.width = captureWidth
            config.height = captureHeight
            
            print("📹 录制配置:")
            print("   源区域（逻辑坐标）: \(sourceRect)")
            print("   输出尺寸（实际像素）: \(captureWidth) × \(captureHeight)")
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
            
            // 关键：确保捕获高分辨率内容
            config.scalesToFit = false  // 不要缩放以适应
            
            // 提高质量设置
            if #available(macOS 14.0, *) {
                config.queueDepth = 8
            }
            config.colorSpaceName = CGColorSpace.displayP3
            config.backgroundColor = CGColor.clear
            config.showsCursor = showCursor
            
            print("📹 录制配置:")
            print("   源区域（逻辑坐标）: \(sourceRect)")
            print("   输出尺寸（实际像素）: \(captureWidth) × \(captureHeight)")
            print("   scalesToFit: \(config.scalesToFit)")

            if #available(macOS 13.0, *) {
                config.capturesAudio = true
            }

            // 设置输出路径
            let outputURL: URL
            if let path = outputPath, !path.isEmpty {
                outputURL = URL(fileURLWithPath: path)
            } else {
                outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("screenRecording.mov")
            }

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            let writer: AVAssetWriter
            do {
                writer = try AVAssetWriter(outputURL: outputURL, fileType: format.avFileType)
            } catch {
                print("❌ 创建 AVAssetWriter 失败: \(error)")
                return
            }
            
            // Create enhanced video settings using VideoSettings model
            let videoSettings = VideoSettings.default(
                fps: fps,
                quality: quality,
                resolution: CGSize(width: captureWidth, height: captureHeight),
                showCursor: showCursor
            )
            let settings = videoSettings.avSettings
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 192000
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            writer.add(audioInput)

            // 设置像素缓冲区属性以匹配源格式
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: captureWidth,
                kCVPixelBufferHeightKey as String: captureHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttributes)
            writer.add(input)
            writer.startWriting()
            // 移除 writer.startSession(atSourceTime: .zero)

            class Delegate: NSObject, SCStreamOutput {
                let input: AVAssetWriterInput
                let audioInput: AVAssetWriterInput
                let adaptor: AVAssetWriterInputPixelBufferAdaptor
                var startTime: CMTime?
                let writer: AVAssetWriter

                init(input: AVAssetWriterInput, audioInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor, writer: AVAssetWriter) {
                    self.input = input
                    self.audioInput = audioInput
                    self.adaptor = adaptor
                    self.writer = writer
                }

                func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    if startTime == nil {
                        startTime = timestamp
                        writer.startSession(atSourceTime: startTime!)
                    }

                    switch outputType {
                    case .screen:
                        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
                        if input.isReadyForMoreMediaData {
                            adaptor.append(pixelBuffer, withPresentationTime: timestamp)
                        }
                    case .audio:
                        if audioInput.isReadyForMoreMediaData {
                            audioInput.append(sampleBuffer)
                        }
                    default:
                        break
                    }
                }
            }

            let delegate = Delegate(input: input, audioInput: audioInput, adaptor: adaptor, writer: writer)

            let stream = SCStream(
                filter: SCContentFilter(display: display, excludingWindows: []),
                configuration: config,
                delegate: nil
            )

            // 使用专用的高优先级队列处理视频数据
            let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated)
            let audioQueue = DispatchQueue(label: "audioQueue", qos: .userInitiated)
            
            do {
                try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: videoQueue)
            } catch {
                print("❌ 添加视频流输出失败: \(error)")
                return
            }

            do {
                if #available(macOS 13.0, *) {
                    try stream.addStreamOutput(delegate, type: SCStreamOutputType.audio, sampleHandlerQueue: audioQueue)
                }
            } catch {
                print("❌ 添加音频流输出失败: \(error)")
                return
            }

            do {
                try await stream.startCapture()
            } catch {
                print("❌ 启动录制失败: \(error)")
                return
            }

            // 录制前切换音频输出到 BlackHole
            // switchAudioOutput(to: "BlackHole 16ch")
            
            let durationSec = Double(durationMs) / 1000.0
            
            // Start progress indicator
            let progressIndicator = ProgressIndicator.startRecording(
                outputURL: outputURL, 
                duration: durationSec
            )
            
            // Setup graceful shutdown handling
            SignalHandler.shared.setupForRecording(
                progressIndicator: progressIndicator
            ) {
                // Graceful shutdown callback
                do {
                    try await stream.stopCapture()
                    input.markAsFinished()
                    audioInput.markAsFinished()
                } catch {
                    print("⚠️ Error during graceful shutdown: \(error.localizedDescription)")
                }
            }
            
            // Record for the specified duration
            try await Task.sleep(nanoseconds: UInt64(durationMs * 1_000_000))

            progressIndicator.updateProgress(message: "Stopping recording...")
            do {
                try await stream.stopCapture()
            } catch {
                print("❌ 停止录制失败: \(error)")
                progressIndicator.stopProgressWithError(error)
                return
            }
            input.markAsFinished()
            audioInput.markAsFinished()

            // 用异步方式等待写入完成
            try await withCheckedThrowingContinuation { continuation in
                writer.finishWriting {
                    if writer.status == .completed {
                        progressIndicator.stopProgress()
                        // 录制完成后切换回默认音频设备
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume()
                    } else if let error = writer.error {
                        progressIndicator.stopProgressWithError(error)
                        // 出错时也要切换回默认音频设备
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume(throwing: error)
                    } else {
                        let unknownError = NSError(domain: "com.swiftcapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知写入错误"])
                        progressIndicator.stopProgressWithError(unknownError)
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume(throwing: unknownError)
                    }
                }
            }
            
            // Clean up signal handler
            SignalHandler.shared.cleanup()

        } catch {
            print("⚠️ 录制失败：\(error)")
            // 出错时也要切换回默认音频设备
            // switchAudioOutput(to: "MacBook Pro Speakers")
            exit(EXIT_FAILURE)
        }
    }
}