# SwiftCapture

[English](README.md) | [中文](README_zh.md)

基于 ScreenCaptureKit 构建的专业 macOS 屏幕录制工具，具有全面的命令行界面、多屏幕支持、应用程序窗口录制和高级音视频控制功能。

## 功能特性

- **专业命令行界面**：基于 Swift ArgumentParser 构建，提供强大的命令行体验
- **多屏幕支持**：支持从任何连接的显示器录制，自动检测屏幕
- **应用程序窗口录制**：录制特定应用程序而非整个屏幕
- **高级音频控制**：系统音频录制，可选麦克风输入
- **灵活区域选择**：支持全屏、自定义区域或居中区域录制
- **质量控制**：可配置帧率（15/30/60 fps）和质量预设
- **高质量输出**：专业 MOV 格式，优化编码
- **预设管理**：保存和重用录制配置
- **倒计时功能**：录制开始前的可选倒计时
- **光标控制**：在录制中显示或隐藏光标
- **全面帮助**：详细的使用示例和故障排除指南

## 系统要求

- **macOS 12.3 或更高版本**（ScreenCaptureKit 必需）
- **Xcode 14.3 或更高版本**（从源码构建时需要）
- **屏幕录制权限**（在系统偏好设置中）
- **麦克风权限**（仅在使用 `--enable-microphone` 时需要）

## 安装

### 从源码构建

```bash
# 克隆仓库
git clone <repository-url>
cd SwiftCapture

# 构建发布版本
swift build -c release

# 可执行文件位于：
.build/release/SwiftCapture
```

### Homebrew（即将推出）

```bash
# 将通过 Homebrew 提供
brew install swiftcapture
```

## 快速开始

```bash
swift run SwiftCapture --duration 60000 -o ./60000-final.mov
swift run SwiftCapture --duration 120000 -o ./120000-final.mov
swift run SwiftCapture --duration 300000 -o ./300000-final.mov
swift run SwiftCapture --duration 420000 -o ./420000-final.mov

还是有问题：

swift run SwiftCapture --duration 420000 -o ./420000-2.mov

我希望录制7分钟的视频，结果生成的视频只有几秒钟。

# 基本 10 秒录制
scap

# 录制 30 秒
scap --duration 30000

# 录制到指定文件
scap --output ~/Desktop/demo.mov

# 录制时包含麦克风音频
scap --enable-microphone --duration 15000
```

## 使用方法

### 基本语法

```bash
scap [选项]
```

### 持续时间控制

```bash
# 录制指定持续时间（毫秒）
scap --duration 5000          # 5 秒
scap -d 30000                  # 30 秒（短标志）
scap --duration 120000         # 2 分钟
```

### 输出文件管理

```bash
# 保存到指定位置
scap --output ~/Desktop/recording.mov
scap -o ./videos/demo.mov

# 默认：当前目录，带时间戳（YYYY-MM-DD_HH-MM-SS.mov）
scap  # 创建：2024-01-15_14-30-25.mov

# 文件冲突处理
scap --output existing.mov    # 交互式提示：覆盖、自动编号或取消
scap --output existing.mov --force  # 强制覆盖，无提示
# 自动编号：existing-2.mov, existing-3.mov 等
```

### 屏幕和显示器选择

```bash
# 列出可用屏幕
scap --screen-list
scap -l

# 从指定屏幕录制
scap --screen 1               # 主显示器
scap --screen 2               # 副显示器
scap -s 2                     # 短标志
```

### 区域选择

```bash
# 录制指定区域（x:y:width:height）
scap --area 0:0:1920:1080     # 全高清区域
scap --area 100:100:800:600   # 位置 100,100 的 800x600 区域
scap -a 0:0:1280:720          # 720p 区域（短标志）

# 居中区域录制（center:width:height）
scap --area center:1280:720   # 屏幕居中的 720p
scap --area center:800:600    # 800x600 居中区域

# 与屏幕选择结合
scap --screen 2 --area 0:0:1920:1080
```

### 应用程序窗口录制

```bash
# 列出运行中的应用程序
scap --app-list
scap -L

# 录制指定应用程序
scap --app Safari
scap --app "Final Cut Pro"    # 带空格的名称需要引号
scap -A Terminal               # 短标志

# 智能应用程序录制功能：
# - 自动选择主窗口（最大的有标题窗口）
# - 录制前将应用程序置于前台
# - 跨多个桌面空间工作
# - 处理窗口切换和激活
```

### 音频录制

```bash
# 启用麦克风录制（始终包含系统音频）
scap --enable-microphone
scap -m                       # 短标志

# 设置音频质量
scap --enable-microphone --audio-quality high
```

### 质量和格式选项

```bash
# 帧率控制
scap --fps 15                 # 适用于静态内容
scap --fps 30                 # 标准（默认）
scap --fps 60                 # 流畅运动

# 质量预设
scap --quality low            # 较小文件（~2Mbps）
scap --quality medium         # 平衡（默认，~5Mbps）
scap --quality high           # 最佳质量（~10Mbps）

# 输出格式始终为 MOV（QuickTime）
# 高质量的 macOS 原生格式，具有出色的兼容性
```

### 高级功能

```bash
# 在录制中显示光标
scap --show-cursor

# 录制前倒计时
scap --countdown 5            # 5 秒倒计时
scap --countdown 3 --show-cursor

# 组合多个选项
scap --screen 2 --area 0:0:1920:1080 --enable-microphone \
               --fps 30 --quality high --countdown 5 --show-cursor \
               --output ~/Desktop/presentation.mov
```

### 预设管理

```bash
# 将当前设置保存为预设
scap --save-preset "meeting"
scap --duration 30000 --enable-microphone --quality high \
               --save-preset "presentation"

# 使用保存的预设
scap --preset "meeting"
scap --preset "presentation" --output ~/Desktop/demo.mov

# 列出所有预设
scap --list-presets

# 删除预设
scap --delete-preset "old-config"
```

### JSON 输出用于程序化使用

SwiftCapture 支持所有列表操作的 JSON 输出，便于与脚本和其他工具集成：

```bash
# 以 JSON 格式获取屏幕信息
scap --screen-list --json

# 以 JSON 格式获取应用程序列表
scap --app-list --json

# 以 JSON 格式获取预设
scap --list-presets --json
```

#### JSON 输出示例

**屏幕列表 JSON：**
```json
{
  "count": 2,
  "screens": [
    {
      "index": 1,
      "displayID": 1,
      "name": "内置显示器 - 3024x1964 - @120Hz - (2.0x scale) - Primary",
      "isPrimary": true,
      "scaleFactor": 2.0,
      "frame": {
        "x": 0,
        "y": 0,
        "width": 1512,
        "height": 982
      },
      "resolution": {
        "width": 3024,
        "height": 1964,
        "pointWidth": 1512,
        "pointHeight": 982
      }
    }
  ]
}
```

**应用程序列表 JSON：**
```json
{
  "count": 1,
  "applications": [
    {
      "name": "Safari",
      "bundleIdentifier": "com.apple.Safari",
      "processID": 1234,
      "isRunning": true,
      "windowCount": 2,
      "windows": [
        {
          "windowID": 567,
          "title": "SwiftCapture 文档",
          "frame": {
            "x": 100,
            "y": 100,
            "width": 1200,
            "height": 800
          },
          "isOnScreen": true,
          "size": {
            "width": 1200,
            "height": 800,
            "pointWidth": 1200,
            "pointHeight": 800
          }
        }
      ]
    }
  ]
}
```

**预设列表 JSON：**
```json
{
  "count": 1,
  "presets": [
    {
      "name": "meeting",
      "duration": 30000,
      "area": null,
      "screen": 1,
      "app": null,
      "enableMicrophone": true,
      "fps": 30,
      "quality": "high",
      "format": "mov",
      "showCursor": false,
      "countdown": 0,
      "audioQuality": "medium",
      "createdAt": "2025-08-19T12:00:00Z",
      "lastUsed": null
    }
  ]
}
```

#### 在脚本中使用 JSON 输出

```bash
#!/bin/bash
# 示例：程序化查找主屏幕索引
PRIMARY_SCREEN=$(scap --screen-list --json | jq -r '.screens[] | select(.isPrimary == true) | .index')
echo "主屏幕索引: $PRIMARY_SCREEN"

# 示例：获取所有 Safari 窗口
scap --app-list --json | jq -r '.applications[] | select(.name == "Safari") | .windows[].title'

# 示例：检查预设是否存在
PRESET_EXISTS=$(scap --list-presets --json | jq -r '.presets[] | select(.name == "meeting") | .name')
if [ "$PRESET_EXISTS" = "meeting" ]; then
    echo "会议预设存在"
fi
```

## 使用示例

### 快速录制场景

```bash
# 快速 10 秒屏幕录制
scap

# 30 秒演示录制，带倒计时
scap --duration 30000 --countdown 3 --show-cursor

# 高质量应用程序演示
scap --app Safari --duration 60000 --quality high --fps 60 \
               --output ~/Desktop/safari-demo.mov
```

### 多屏幕设置

```bash
# 列出可用显示器
scap --screen-list

# 录制副显示器的全高清内容
scap --screen 2 --area 0:0:1920:1080 --quality high

# 录制主显示器的自定义区域
scap --screen 1 --area 0:0:2560:1440

# 居中录制适用于不同屏幕尺寸
scap --screen 2 --area center:1920:1080  # 在任何屏幕尺寸上自动居中
```

### 音频录制

```bash
# 录制教程时包含麦克风
scap --enable-microphone --duration 300000 --quality high \
               --show-cursor --countdown 5

# 高质量音频录制
scap --enable-microphone --audio-quality high --quality high
```

### 预设工作流

```bash
# 为不同场景创建预设
scap --duration 30000 --enable-microphone --quality high \
               --fps 30 --show-cursor --save-preset "tutorial"

scap --app Safari --duration 60000 --quality medium \
               --fps 60 --save-preset "browser-demo"

scap --screen 2 --quality low --fps 15 \
               --save-preset "secondary-screen"

# 带居中区域和倒计时的高级预设
scap --area center:1280:720 --countdown 5 --quality high \
               --enable-microphone --save-preset "presentation"

# 使用预设
scap --preset "tutorial" --output ~/Desktop/lesson1.mov
scap --preset "browser-demo"
scap --preset "secondary-screen" --duration 120000

# 覆盖预设设置
scap --preset "tutorial" --duration 60000 --output custom.mov
```

## 命令参考

### 信息命令

| 命令                  | 描述                   |
| --------------------- | ---------------------- |
| `--help`, `-h`        | 显示全面帮助和示例     |
| `--version`           | 显示版本信息           |
| `--screen-list`, `-l` | 列出可用屏幕及详细信息 |
| `--app-list`, `-L`    | 列出运行中的应用程序   |
| `--list-presets`      | 显示所有保存的预设     |
| `--json`              | 以 JSON 格式输出列表结果 |

### 录制选项

| 选项         | 短标志 | 描述                                                | 默认值         |
| ------------ | ------ | --------------------------------------------------- | -------------- |
| `--duration` | `-d`   | 录制持续时间（毫秒）                                | 10000（10 秒） |
| `--output`   | `-o`   | 输出文件路径                                        | 带时间戳的文件 |
| `--screen`   | `-s`   | 要录制的屏幕索引                                    | 1（主屏幕）    |
| `--area`     | `-a`   | 录制区域（x:y:width:height 或 center:width:height） | 全屏           |
| `--app`      | `-A`   | 要录制的应用程序名称                                | 无             |
| `--force`    | `-f`   | 强制覆盖现有文件                                    | 关闭           |

### 质量选项

| 选项              | 描述         | 值                | 默认值 |
| ----------------- | ------------ | ----------------- | ------ |
| `--fps`           | 帧率         | 15, 30, 60        | 30     |
| `--quality`       | 视频质量预设 | low, medium, high | medium |
| `--audio-quality` | 音频质量预设 | low, medium, high | medium |

### 音频和视觉

| 选项                  | 短标志 | 描述             | 默认值 |
| --------------------- | ------ | ---------------- | ------ |
| `--enable-microphone` | `-m`   | 包含麦克风音频   | 关闭   |
| `--show-cursor`       |        | 在录制中显示光标 | 关闭   |
| `--countdown`         |        | 开始前倒计时秒数 | 0      |

### 预设管理

| 选项                     | 描述                 |
| ------------------------ | -------------------- |
| `--save-preset <name>`   | 将当前设置保存为预设 |
| `--preset <name>`        | 从预设加载设置       |
| `--delete-preset <name>` | 删除保存的预设       |

## 权限设置

### 屏幕录制权限

1. 打开 **系统偏好设置** > **安全性与隐私** > **隐私**
2. 从左侧边栏选择 **屏幕录制**
3. 点击锁图标并输入密码
4. 添加您的终端应用程序（Terminal、iTerm2 等）
5. 启用终端旁边的复选框
6. 重启终端应用程序

### 麦克风权限（可选）

仅在使用 `--enable-microphone` 时需要：

1. 打开 **系统偏好设置** > **安全性与隐私** > **隐私**
2. 从左侧边栏选择 **麦克风**
3. 添加并启用您的终端应用程序
4. 重启终端应用程序

## 故障排除

### 常见问题

#### 权限错误

**"屏幕录制权限被拒绝"**

- 向您的终端授予屏幕录制权限（参见权限设置）
- 授予权限后重启终端
- 确保在系统偏好设置中使用正确的终端应用程序

**"麦克风权限被拒绝"**

- 向您的终端授予麦克风权限（参见权限设置）
- 仅在使用 `--enable-microphone` 时出现
- 如果麦克风失败，录制将仅使用系统音频继续

#### 屏幕/显示器问题

**"未找到屏幕 X"**

- 使用 `--screen-list` 查看可用屏幕
- 屏幕索引从 1 开始，不是 0
- 外部显示器断开连接时索引可能会改变

**"无效的区域坐标"**

- 使用 `--screen-list` 检查屏幕分辨率
- 确保坐标在屏幕边界内
- 格式：`x:y:width:height`（所有正整数）

#### 应用程序录制问题

**"未找到应用程序 'X'"**

- 使用 `--app-list` 查看确切的应用程序名称
- 名称区分大小写
- 应用程序必须正在运行且有可见窗口
- 带空格的名称使用引号：`"Final Cut Pro"`

**录制中应用程序窗口不可见**

- SwiftCapture 自动将应用程序置于前台
- 命令启动后等待 1-2 秒进行窗口切换
- 确保应用程序未最小化或隐藏
- 检查应用程序是否在不同的桌面空间

**录制显示错误窗口**

- SwiftCapture 选择最大的有标题窗口
- 录制前关闭不必要的窗口
- 使用窗口标题识别正确的应用程序实例

#### 文件输出问题

**保存时"权限被拒绝"**

- 检查输出目录的写入权限
- 尝试保存到 `~/Desktop` 或 `~/Documents`
- 确保父目录存在

**"文件扩展名不匹配"**

- 输出文件始终为 MOV 格式
- 输出文件请使用 `.mov` 扩展名

**文件冲突和覆盖**

- 不使用 `--force`：交互式提示或自动编号
- 使用 `--force`：自动覆盖现有文件
- 自动编号文件：`recording-2.mov`、`recording-3.mov`

**"磁盘空间不足"警告**

- SwiftCapture 在录制前检查可用空间
- 高质量录制长时间可能超过 1GB
- 在空间受限情况下使用 `--quality low`

### 性能提示

**提高性能：**

- 长时间录制使用 `--quality low`
- 静态内容（演示、代码）使用 `--fps 15`
- 标准录制使用 `--fps 30`
- 仅在流畅运动捕获时使用 `--fps 60`
- 使用 `--area` 录制较小区域而非全屏
- 录制前关闭不必要的应用程序

**减小文件大小：**

- 使用 `--quality low` 或 `--quality medium`
- 使用 `--fps 15` 或 `--fps 30` 降低帧率
- 录制特定区域而非全屏

**最佳质量：**

- 使用 `--quality high` 配合 `--fps 60`
- MOV 格式提供最佳 macOS 兼容性
- 确保足够的磁盘空间（长录制需要 1GB+）

**自动优化：**

- SwiftCapture 根据分辨率自动调整比特率
- 高分辨率 MOV 文件使用 HEVC 编解码器（更好的压缩）
- H.264/HEVC 编解码器提供最佳质量和兼容性
- 基于内容类型和分辨率的质量建议

### 系统要求问题

**"不满足系统要求"**

- 需要 macOS 12.3 或更高版本
- 通过系统偏好设置 > 软件更新来更新 macOS
- 较旧的 macOS 版本不支持 ScreenCaptureKit

## 技术细节

### 高级区域选择

SwiftCapture 提供像素级精确的区域录制和智能缩放：

- **Retina 显示器支持**：自动处理高 DPI 显示器的适当缩放
- **坐标系统**：支持逻辑和像素坐标
- **边界验证**：针对目标屏幕尺寸的实时验证
- **智能居中**：`center:width:height` 格式用于响应式定位

```bash
# 高级区域选择示例
scap --area 0:0:3840:2160     # Retina 显示器上的 4K 区域（自动缩放）
scap --area center:1920:1080  # 1080p 居中，不受屏幕尺寸影响
scap --screen 2 --area 100:100:1280:720  # 副显示器上的特定区域
```

### 智能应用程序录制

应用程序录制包含高级窗口管理：

- **智能窗口选择**：优先选择有标题的主窗口而非实用程序窗口
- **跨桌面录制**：自动切换到应用程序的桌面空间
- **窗口激活**：将目标应用程序置于前台以进行无遮挡录制
- **多窗口处理**：当应用程序有多个窗口时选择最佳窗口

```bash
# 带自动优化的应用程序录制
scap --app "Final Cut Pro" --duration 60000  # 自动查找并激活主窗口
scap --app Safari --area center:1280:720     # 录制 Safari 的自定义区域（不推荐）
```

### 文件管理和冲突解决

具有多种冲突解决策略的全面文件处理：

- **交互模式**：文件存在时提示用户选择
- **自动编号**：生成 `filename-2.mov`、`filename-3.mov` 序列
- **强制覆盖**：`--force` 标志绕过所有确认
- **目录创建**：自动创建输出目录
- **磁盘空间验证**：录制前检查可用空间

### 性能优化

SwiftCapture 根据录制参数自动优化设置：

- **自适应比特率**：根据分辨率和帧率计算最佳比特率
- **编解码器选择**：根据格式和质量要求选择 H.264 或 HEVC
- **内存管理**：长录制的高效缓冲区处理
- **质量缩放**：为高分辨率内容推荐质量设置

## 高级用法

### 脚本和自动化

```bash
#!/bin/bash
# 带高级功能的自动录制示例脚本

# 设置变量
DURATION=30000
OUTPUT_DIR="$HOME/Desktop/recordings"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 检查可用屏幕并选择合适的
SCREEN_COUNT=$(scap --screen-list | grep -c "Screen")
if [ "$SCREEN_COUNT" -gt 1 ]; then
    SCREEN=2  # 如果可用，使用副屏幕
else
    SCREEN=1  # 使用主屏幕
fi

# 使用智能设置录制
scap --screen "$SCREEN" \
     --area center:1920:1080 \
     --duration "$DURATION" \
     --quality high \
     --fps 30 \
     --countdown 3 \
     --force \
     --output "$OUTPUT_DIR/meeting_$TIMESTAMP.mov"

echo "录制已保存到：$OUTPUT_DIR/meeting_$TIMESTAMP.mov"

# 可选：如需要可进行格式转换
# ffmpeg -i "$OUTPUT_DIR/meeting_$TIMESTAMP.mov" \
#        -c:v libx264 -c:a aac \
#        "$OUTPUT_DIR/meeting_$TIMESTAMP_converted.mov"
```

### 批量录制

```bash
# 智能处理的多应用程序序列录制
apps=("Safari" "Terminal" "Finder")

for app in "${apps[@]}"; do
    echo "正在录制 $app..."

    # 在批处理模式下使用 force 标志避免交互式提示
    scap --app "$app" \
         --duration 10000 \
         --quality medium \
         --countdown 2 \
         --force \
         --output "~/Desktop/${app}_demo_$(date +%H%M%S).mov"

    sleep 3  # 为应用程序切换和文件写入留出时间
done

# 批量录制不同屏幕区域
areas=("0:0:1920:1080" "center:1280:720" "100:100:800:600")

for i in "${!areas[@]}"; do
    echo "正在录制区域：${areas[$i]}"
    scap --area "${areas[$i]}" \
         --duration 5000 \
         --output "~/Desktop/area_${i}_$(date +%H%M%S).mov"
done
```

### 与其他工具集成

```bash
# 与 ffmpeg 结合进行后处理
scap --duration 30000 --quality high --output temp_recording.mov
ffmpeg -i temp_recording.mov -vf "scale=1280:720" final_recording.mov
rm temp_recording.mov
```

## 技术规格

### 支持的格式和编解码器

| 格式 | 编解码器    | 最大分辨率     | 兼容性               |
| ---- | ----------- | -------------- | -------------------- |
| MOV  | H.264, HEVC | 8K (7680×4320) | macOS 原生，专业质量 |

### 质量设置和比特率

| 质量   | 基础比特率 | 典型用例         | 文件大小（10 分钟 1080p） |
| ------ | ---------- | ---------------- | ------------------------- |
| Low    | 2 Mbps     | 长录制，静态内容 | ~150 MB                   |
| Medium | 5 Mbps     | 通用目的，演示   | ~375 MB                   |
| High   | 10 Mbps    | 专业内容，运动   | ~750 MB                   |

_比特率根据分辨率和帧率自动缩放_

### 帧率建议

| 内容类型               | 推荐 FPS | 用例               |
| ---------------------- | -------- | ------------------ |
| 静态内容（代码、文档） | 15 fps   | 较小文件，足够质量 |
| 一般录制               | 30 fps   | 平衡质量和文件大小 |
| 流畅运动（游戏、动画） | 60 fps   | 专业质量，较大文件 |

### 音频规格

| 质量   | 采样率    | 比特率   | 声道   |
| ------ | --------- | -------- | ------ |
| Low    | 22.05 kHz | 64 kbps  | 立体声 |
| Medium | 44.1 kHz  | 128 kbps | 立体声 |
| High   | 48 kHz    | 192 kbps | 立体声 |

### 系统性能

- **内存使用**：录制期间约 50-100 MB
- **CPU 使用**：现代 Mac 上 5-15%（因分辨率/fps 而异）
- **磁盘 I/O**：实时写入，根据质量约 10-50 MB/s
- **支持分辨率**：在兼容硬件上最高 8K

## 从源码构建

### 先决条件

- macOS 12.3 或更高版本
- Xcode 14.3 或更高版本
- Swift 5.6 或更高版本

### 构建步骤

```bash
# 克隆仓库
git clone <repository-url>
cd ScreenRecorder

# 清理之前的构建
swift package clean

# 构建调试版本（用于开发）
swift build

# 构建发布版本（优化）
swift build -c release

# 运行测试
swift test

# 全局安装（可选）
cp .build/release/ScreenRecorder /usr/local/bin/scap
```

### 开发

```bash
# 直接使用 Swift 运行
swift run ScreenRecorder --help

# 带参数运行
swift run ScreenRecorder --duration 5000 --output test.mov

# 构建并运行发布版本
swift build -c release
.build/release/ScreenRecorder --screen-list
```

## 贡献

1. Fork 仓库
2. 创建功能分支
3. 进行更改
4. 为新功能添加测试
5. 确保所有测试通过：`swift test`
6. 提交拉取请求

## 许可证

[许可证信息待添加]

## 更新日志

### 版本 2.0.0

- 使用 Swift ArgumentParser 完全重写
- 添加多屏幕支持和自动 Retina 缩放
- 添加智能应用程序窗口录制和自动激活
- 添加带 JSON 存储的预设管理系统
- 添加带验证的全面 CLI 界面
- 添加音频质量控制和麦克风支持
- 添加带取消支持的倒计时功能
- 添加光标可见性控制
- 添加优化的 MOV 输出格式和高级编解码器选择
- 添加文件冲突解决（交互式/自动编号/强制）
- 添加居中区域录制（`center:width:height`）
- 添加基于分辨率/fps 的自动比特率计算
- 添加磁盘空间验证和性能警告
- 添加跨桌面空间录制支持
- 添加全面的帮助和故障排除

### 版本 1.0.0

- 基本屏幕录制的初始版本
- ScreenCaptureKit 集成
- 基本命令行界面

---

更多信息请使用 `scap --help` 或访问项目仓库。
