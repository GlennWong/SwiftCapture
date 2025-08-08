# ScreenRecorder

一个使用 ScreenCaptureKit 的屏幕录制工具，支持第二显示器录制和音频切换。

## 功能特性

- 使用 ScreenCaptureKit 进行高质量屏幕录制
- 支持第二显示器录制
- 支持全屏或 3:4 竖屏比例录制
- 自动音频设备切换（BlackHole 16ch）
- 支持命令行参数配置

## 构建和运行

```bash
# 清理构建
swift package clean

# 构建发布版本
swift build -c release

# 运行（使用构建的可执行文件）
.build/release/ScreenRecorder [时长毫秒] [输出路径] [录制模式]

# 或者直接运行
swift run ScreenRecorder [时长毫秒] [输出路径] [录制模式]
```

## 使用方法

### 参数说明

1. **时长毫秒**（可选）：录制时长，单位毫秒，默认 10000（10秒）
2. **输出路径**（可选）：视频输出路径，默认为当前目录下的 `screenRecording.mov`
3. **录制模式**（可选）：传入 "full" 为全屏录制，默认为 3:4 竖屏比例

### 使用示例

```bash
# 默认录制 10 秒，3:4 竖屏比例
swift run ScreenRecorder

# 录制 30 秒
swift run ScreenRecorder 3000

# 录制 15 秒，保存到指定路径
swift run ScreenRecorder 1500 ~/Desktop/recording.mov

# 录制 20 秒，全屏模式
swift run ScreenRecorder 20000 ~/Desktop/recording.mov full

# 使用构建的可执行文件
.build/release/ScreenRecorder 15000
```

## 系统要求

- macOS 12.3+ （ScreenCaptureKit 要求）
- Xcode 14.3+ （构建工具要求）
