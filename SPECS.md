# SwiftCapture 参数规格与录制效果完整文档

## 概述

SwiftCapture 是一个专业的 macOS 屏幕录制工具，基于 ScreenCaptureKit 构建。本文档详细说明所有参数组合及其录制效果。

## 1. 基础参数

### 1.1 时长控制

#### `--duration` / `-d`
- **类型**: 整数（毫秒）
- **默认值**: 10000ms (10秒)
- **范围**: 100ms - 3600000ms (1小时)
- **验证**: 
  - 最小值 100ms
  - 超过 1小时 会显示警告
- **效果**: 控制录制的总时长

**示例**:
```bash
scap --duration 30000    # 30秒录制
scap -d 5000            # 5秒录制
```

### 1.2 输出控制

#### `--output` / `-o`
- **类型**: 字符串（文件路径）
- **默认值**: 当前目录 + 时间戳文件名 (YYYY-MM-DD_HH-mm-ss.mov)
- **格式**: 支持相对路径和绝对路径
- **验证**: 
  - 文件扩展名必须与 `--format` 匹配
  - 自动创建不存在的目录
- **效果**: 指定录制文件保存位置

#### `--force` / `-f`
- **类型**: 布尔标志
- **默认值**: false
- **效果**: 强制覆盖现有文件，跳过确认提示

**示例**:
```bash
scap --output video.mov --force
scap -f -o ~/Desktop/recording.mp4
```

## 2. 录制区域参数

### 2.1 屏幕选择

#### `--screen` / `-s`
- **类型**: 整数（屏幕索引）
- **默认值**: 1（主屏幕）
- **范围**: 1+（1=主屏，2+=副屏）
- **验证**: 屏幕索引必须存在
- **效果**: 选择录制的显示器

#### `--screen-list` / `-l`
- **类型**: 布尔标志
- **效果**: 列出所有可用屏幕及其索引和分辨率
- **冲突**: 与录制参数互斥

### 2.2 区域定义

#### `--area` / `-a`
- **类型**: 字符串
- **格式1**: `x:y:width:height`（像素坐标）
- **格式2**: `center:width:height`（居中区域）
- **默认**: 全屏录制
- **验证**:
  - 坐标必须为非负整数
  - 宽度和高度必须大于 0
  - 区域必须在目标屏幕范围内
  - 最小尺寸 1x1 像素
  - 推荐最小尺寸 100x100 像素
- **效果**: 精确控制录制范围

**示例**:
```bash
scap --area 0:0:1920:1080        # 录制指定矩形区域
scap --area center:800:600       # 录制屏幕中央 800x600 区域
scap --screen 2 --area 100:100:1280:720  # 在第二屏幕录制指定区域
```

### 2.3 应用录制

#### `--app` / `-A`
- **类型**: 字符串（应用名称）
- **格式**: 应用的确切名称（区分大小写）
- **验证**: 应用名称不能为空
- **效果**: 录制指定应用的所有窗口
- **冲突**: 与 `--screen`/`--area` 参数互斥（除非使用 `--system-audio-only`）

#### `--app-list` / `-L`
- **类型**: 布尔标志
- **效果**: 列出所有可录制的运行中应用
- **冲突**: 与录制参数互斥

**示例**:
```bash
scap --app Safari --duration 15000
scap --app "Final Cut Pro" --fps 60
```

## 3. 音频参数

### 3.1 音频源

#### `--enable-microphone` / `-m`
- **类型**: 布尔标志
- **默认值**: false（仅系统音频）
- **效果**: 启用麦克风录制，同时录制麦克风和系统音频
- **权限**: 需要麦克风访问权限

#### `--system-audio-only`
- **类型**: 布尔标志
- **默认值**: false
- **效果**: 强制使用系统级音频录制
- **用途**: 应用录制时使用系统音频而非应用特定音频

### 3.2 音频质量

#### `--audio-quality`
- **类型**: 字符串枚举
- **选项**: 
  - `low`: 22kHz 采样率, 64kbps 比特率
  - `medium`: 44kHz 采样率, 128kbps 比特率  
  - `high`: 48kHz 采样率, 192kbps 比特率
- **默认值**: medium
- **效果**: 控制音频采样率和比特率

**示例**:
```bash
scap --enable-microphone --audio-quality high
scap --app Terminal --system-audio-only --audio-quality low
```

## 4. 视频参数

### 4.1 帧率控制

#### `--fps`
- **类型**: 整数
- **选项**: 15 / 30 / 60
- **默认值**: 30fps
- **效果**: 
  - 15fps: 适合长时间录制，文件较小
  - 30fps: 标准帧率，平衡质量和大小
  - 60fps: 高流畅度，适合游戏录制

### 4.2 视频质量

#### `--quality`
- **类型**: 字符串枚举
- **选项**:
  - `low`: 2Mbps 基础比特率，H.264 Baseline
  - `medium`: 5Mbps 基础比特率，H.264 Main
  - `high`: 10Mbps 基础比特率，H.264 High
- **默认值**: medium
- **效果**: 控制视频比特率和压缩设置
- **自适应**: 比特率根据分辨率和帧率自动调整

### 4.3 输出格式

#### `--format`
- **类型**: 字符串枚举
- **选项**:
  - `mov`: QuickTime 格式，macOS 原生，支持更多编解码器
  - `mp4`: MPEG-4 格式，通用兼容性更好
- **默认值**: mov
- **编解码器选择**:
  - MOV: 高质量高分辨率时可使用 HEVC
  - MP4: 始终使用 H.264 确保兼容性

### 4.4 视觉选项

#### `--show-cursor`
- **类型**: 布尔标志
- **默认值**: false（隐藏光标）
- **效果**: 控制录制中是否显示鼠标指针

**示例**:
```bash
scap --fps 60 --quality high --format mov --show-cursor
scap --fps 15 --quality low --format mp4  # 性能优化配置
```

## 5. 高级功能

### 5.1 倒计时

#### `--countdown`
- **类型**: 整数（秒）
- **范围**: 0-60秒
- **默认值**: 0（立即开始）
- **效果**: 录制开始前的倒计时，可按 Ctrl+C 取消
- **用途**: 给用户准备时间

### 5.2 预设管理

#### `--save-preset <name>`
- **类型**: 字符串（预设名称）
- **验证**: 
  - 名称不能为空
  - 只能包含字母、数字、连字符、下划线
  - 最大长度 50 字符
  - 不能与现有预设重名
- **效果**: 保存当前所有设置为命名预设

#### `--preset <name>`
- **类型**: 字符串（预设名称）
- **效果**: 加载已保存的预设配置
- **优先级**: 预设参数可被命令行参数覆盖

#### `--list-presets`
- **类型**: 布尔标志
- **效果**: 显示所有已保存的预设及其详细信息
- **冲突**: 与录制参数互斥

#### `--delete-preset <name>`
- **类型**: 字符串（预设名称）
- **效果**: 删除指定的预设
- **冲突**: 与所有其他参数互斥

**示例**:
```bash
# 保存预设
scap --save-preset "meeting" --duration 30000 --enable-microphone --fps 30

# 使用预设
scap --preset "meeting" --output meeting-2025.mov

# 管理预设
scap --list-presets
scap --delete-preset "old-config"
```

## 6. 参数组合效果

### 6.1 屏幕录制组合

#### 基础全屏录制
```bash
scap --duration 30000 --fps 60 --quality high
```
**效果**: 30秒，60fps，高质量主屏幕全屏录制

#### 多屏幕指定区域录制
```bash
scap --screen 2 --area 0:0:1920:1080 --duration 15000 --format mp4
```
**效果**: 在第二个屏幕录制指定区域15秒，MP4格式

#### 居中区域录制
```bash
scap --area center:800:600 --fps 30 --quality medium --show-cursor
```
**效果**: 录制屏幕中央800x600区域，显示光标

### 6.2 应用录制组合

#### 基础应用录制
```bash
scap --app Safari --duration 20000 --enable-microphone --audio-quality high
```
**效果**: 录制Safari应用20秒，包含高质量麦克风和系统音频

#### 应用录制+系统音频
```bash
scap --app "Final Cut Pro" --system-audio-only --fps 60 --quality high
```
**效果**: 录制Final Cut Pro，60fps高质量，仅系统级音频

### 6.3 高质量录制组合

#### 4K高质量录制
```bash
scap --area 0:0:3840:2160 --fps 30 --quality high --format mov --audio-quality high
```
**效果**: 4K分辨率，高质量视频和音频，MOV格式

#### 性能优化长时间录制
```bash
scap --fps 15 --quality low --format mp4 --duration 300000 --audio-quality low
```
**效果**: 5分钟长时间录制，优化性能和文件大小

### 6.4 专业工作流

#### 会议录制预设
```bash
# 创建预设
scap --save-preset "meeting" --duration 60000 --enable-microphone --fps 30 --quality medium --show-cursor --countdown 3

# 使用预设
scap --preset "meeting" --output "meeting-$(date +%Y%m%d).mov"
```

#### 演示录制预设
```bash
# 创建预设
scap --save-preset "demo" --area center:1280:720 --fps 30 --quality high --show-cursor --countdown 5

# 使用预设
scap --preset "demo" --duration 45000 --output demo-video.mp4
```

## 7. 参数冲突和限制

### 7.1 互斥参数组合

#### 录制模式冲突
- `--app` 与 `--screen`/`--area` 互斥
- **例外**: 使用 `--system-audio-only` 时可以组合

#### 操作模式冲突
- 列表操作互斥: `--screen-list`, `--app-list`, `--list-presets`
- 预设操作互斥: `--save-preset`, `--preset`, `--delete-preset`
- 列表操作与录制参数互斥
- 预设删除与所有其他参数互斥

### 7.2 验证规则

#### 区域验证
- 录制区域必须完全在目标屏幕范围内
- 自定义区域坐标使用屏幕本地坐标系
- 居中区域尺寸不能超过屏幕尺寸

#### 文件验证
- 输出文件扩展名必须与 `--format` 参数匹配
- 自动检查磁盘空间，少于1GB时警告

#### 预设验证
- 预设名称只能包含: 字母、数字、连字符(-)、下划线(_)
- 预设名称长度限制: 1-50 字符
- 保存时检查重名冲突

### 7.3 性能考虑

#### 高负载组合
```bash
# 高CPU/内存使用
scap --area 0:0:3840:2160 --fps 60 --quality high --enable-microphone
```

#### 优化组合
```bash
# 平衡性能
scap --fps 30 --quality medium --audio-quality medium

# 最小资源使用
scap --fps 15 --quality low --audio-quality low
```

## 8. 实际录制效果预期

### 8.1 文件大小估算

| 分辨率 | 帧率 | 质量 | 时长 | 预期大小 |
|--------|------|------|------|----------|
| 1080p | 30fps | medium | 10秒 | 50-100MB |
| 1080p | 60fps | high | 10秒 | 150-250MB |
| 4K | 30fps | high | 10秒 | 500-800MB |
| 720p | 15fps | low | 60秒 | 100-200MB |

### 8.2 系统要求

#### 最低要求
- **macOS**: 12.3+ (ScreenCaptureKit 支持)
- **系统音频**: macOS 13.0+ 
- **权限**: 屏幕录制权限（必需）
- **权限**: 麦克风权限（使用 `--enable-microphone` 时）

#### 推荐配置
- **CPU**: Apple Silicon 或 Intel i5+
- **内存**: 8GB+ (4K录制建议16GB+)
- **存储**: SSD，足够可用空间

### 8.3 质量与性能权衡

#### 高质量配置
```bash
scap --fps 60 --quality high --audio-quality high --format mov
```
- **优点**: 最佳视觉和音频质量
- **缺点**: 大文件，高CPU使用

#### 平衡配置
```bash
scap --fps 30 --quality medium --audio-quality medium --format mp4
```
- **优点**: 良好质量，合理文件大小
- **缺点**: 无

#### 性能优先配置
```bash
scap --fps 15 --quality low --audio-quality low --format mp4
```
- **优点**: 小文件，低CPU使用，适合长时间录制
- **缺点**: 质量较低

## 9. 错误处理和故障排除

### 9.1 常见错误

#### 权限错误
- **屏幕录制权限**: 系统偏好设置 > 安全性与隐私 > 屏幕录制
- **麦克风权限**: 系统偏好设置 > 安全性与隐私 > 麦克风

#### 参数错误
- **无效区域**: 检查坐标是否在屏幕范围内
- **无效应用**: 使用 `--app-list` 查看可用应用
- **文件冲突**: 使用 `--force` 或更改输出路径

#### 资源错误
- **磁盘空间不足**: 清理空间或选择其他输出位置
- **内存不足**: 降低质量设置或缩小录制区域

### 9.2 性能优化建议

#### 长时间录制
```bash
scap --fps 15 --quality low --duration 1800000  # 30分钟
```

#### 高分辨率录制
```bash
scap --area 0:0:3840:2160 --fps 30 --quality medium  # 4K平衡设置
```

#### 多任务环境
```bash
scap --fps 30 --quality low --app "Specific App"  # 减少系统负载
```

## 10. 使用场景最佳实践

### 10.1 教学演示
```bash
scap --save-preset "tutorial" --area center:1280:720 --fps 30 --quality high --show-cursor --enable-microphone --countdown 5
```

### 10.2 软件测试
```bash
scap --save-preset "testing" --app "Test App" --fps 30 --quality medium --duration 120000
```

### 10.3 游戏录制
```bash
scap --save-preset "gaming" --fps 60 --quality high --format mov --duration 300000
```

### 10.4 会议记录
```bash
scap --save-preset "meeting" --enable-microphone --audio-quality high --fps 30 --quality medium --show-cursor
```

---

**版本**: SwiftCapture 2.1.5  
**更新日期**: 2025年1月  
**兼容性**: macOS 12.3+