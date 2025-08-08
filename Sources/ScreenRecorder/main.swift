import Foundation
import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit

// 音频设备切换功能
func switchAudioOutput(to deviceName: String) {
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

@main
struct ScreenRecorder {
    static func main() async {
        if #available(macOS 12.3, *) {
            // 解析命令行参数
            let args = CommandLine.arguments
            // 第1参数：时长，毫秒，默认10000
            let durationMs = (args.count > 1) ? Int(args[1]) ?? 10000 : 10000
            // 第2参数：输出文件路径，默认空，使用当前目录下的 screenRecording.mov
            let outputPath = (args.count > 2) ? args[2] : nil
            // 第3参数：是否整屏录制，传 "full" 则为整屏，默认竖屏裁剪
            let fullScreen = (args.count > 3) ? (args[3].lowercased() == "full") : false
            
            await record(durationMs: durationMs, outputPath: outputPath, fullScreen: fullScreen)
        } else {
            print("❌ 当前系统版本不支持 ScreenCaptureKit（需要 macOS 12.3+）")
        }
    }

    @available(macOS 12.3, *)
    static func record(durationMs: Int, outputPath: String?, fullScreen: Bool) async {
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
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            
            // 关键：确保捕获高分辨率内容
            config.scalesToFit = false  // 不要缩放以适应
            
            // 提高质量设置
            if #available(macOS 14.0, *) {
                config.queueDepth = 8
            }
            config.colorSpaceName = CGColorSpace.displayP3
            config.backgroundColor = CGColor.clear
            config.showsCursor = false
            
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
                writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            } catch {
                print("❌ 创建 AVAssetWriter 失败: \(error)")
                return
            }
            
            // 使用更高质量的视频设置
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: captureWidth,
                AVVideoHeightKey: captureHeight,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: captureWidth * captureHeight * 4, // 高比特率
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                    AVVideoExpectedSourceFrameRateKey: 60,
                    AVVideoMaxKeyFrameIntervalKey: 60
                ]
            ]
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
            print("✅ 开始录制（\(durationSec) 秒）...")
            try await Task.sleep(nanoseconds: UInt64(durationMs * 1_000_000))

            print("🛑 停止录制...")
            do {
                try await stream.stopCapture()
            } catch {
                print("❌ 停止录制失败: \(error)")
            }
            input.markAsFinished()
            audioInput.markAsFinished()

            // 用异步方式等待写入完成
            try await withCheckedThrowingContinuation { continuation in
                writer.finishWriting {
                    if writer.status == .completed {
                        print("🎬 已保存视频: \(outputURL.path)")
                        // 录制完成后切换回默认音频设备
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume()
                    } else if let error = writer.error {
                        // 出错时也要切换回默认音频设备
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume(throwing: error)
                    } else {
                        // switchAudioOutput(to: "MacBook Pro Speakers")
                        continuation.resume(throwing: NSError(domain: "com.screenrecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "未知写入错误"]))
                    }
                }
            }

        } catch {
            print("⚠️ 录制失败：\(error)")
            // 出错时也要切换回默认音频设备
            // switchAudioOutput(to: "MacBook Pro Speakers")
            exit(EXIT_FAILURE)
        }
    }
}