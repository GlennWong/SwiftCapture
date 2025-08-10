# ScreenRecorder 屏幕录制工具

一个专业的 macOS 屏幕录制工具，基于 ScreenCaptureKit 开发，支持强大的命令行界面、多屏录制、应用窗口录制，以及高级音视频控制。

```sh
# 查看屏幕列表
./.build/release/ScreenRecorder --screen-list

# 录制屏幕


# 正常录制
./.build/release/ScreenRecorder \
 --screen 2 \
 --area 0:0:1620:2160 \
 --duration 5000 \
 --format mp4 \
 --output ~/Desktop/presentation.mp4

# Built In Screen
./.build/release/ScreenRecorder \
 --screen 1 \
 --area 0:74:1417:1890 \
 --duration 5000 \
 --format mp4 \
 --output ~/Desktop/presentation-1.mp4

# 查看运行App列表
./.build/release/ScreenRecorder --app-list
# 录制App
./.build/release/ScreenRecorder --duration 5000 --app NetEaseMusic
```

## Issues

- Issue 1: duration 默认改为 10 秒，但实际输出的视频不够 10 秒
- Issue 2: 窗口录制分辨率问题
- Issue 3: 代码中所有的内容、录制过程中的输出信息全部用英文
- Issue 4: 简化 --help 的输出信息

只保留以下即可：

```
• Use --help for this comprehensive help information
• Use --screen-list to identify available displays
• Use --app-list to see recordable applications
• Use --list-presets to see saved configurations
• Check system permissions in System Preferences > Security & Privacy

USAGE: screenrecorder <options>

OPTIONS:
  -d, --duration <duration>
                          Recording duration in milliseconds (default: 10000) (default: 10000)
  -o, --output <output>   Output file path (default: current directory with timestamp)
  -a, --area <area>       Recording area in format x:y:width:height (default: full screen)
  -l, --screen-list       List all available screens with their indices
  -s, --screen <screen>   Screen index to record from (1=primary, 2+=secondary) (default: 1)
  -L, --app-list          List all running applications
  -A, --app <app>         Application name to record (instead of screen)
  -e, --enable-microphone Enable microphone recording
  --audio-quality <audio-quality>
                          Audio quality: low, medium, or high (default: medium) (default: medium)
  --fps <fps>             Frame rate: 15, 30, or 60 fps (default: 30) (default: 30)
  --quality <quality>     Quality preset: low, medium, or high (default: medium) (default: medium)
  --format <format>       Output format: mov or mp4 (default: mov) (default: mov)
  --show-cursor           Show cursor in recording
  --countdown <countdown> Countdown seconds before recording starts (default: 0) (default: 0)
  --save-preset <save-preset>
                          Save current settings as a named preset
  --preset <preset>       Load settings from a saved preset
  --list-presets          List all saved presets
  --delete-preset <delete-preset>
                          Delete a saved preset
  --version               Show the version.
  -h, --help, --help      Show help information.
```

## 功能特色

- **专业命令行界面**：基于 Swift ArgumentParser，体验强大 CLI
- **多屏支持**：自动检测并录制任意连接的显示器
- **应用窗口录制**：可录制指定应用窗口而非整个屏幕
- **高级音频控制**：支持系统音频录制，可选麦克风输入
- **灵活区域选择**：支持全屏、自定义区域或居中区域录制
- **画质控制**：可配置帧率（15/30/60 fps）和画质预设
- **多种输出格式**：支持 MOV 和 MP4 格式
- **预设管理**：保存并复用录制配置
- **倒计时功能**：录制前可设置倒计时
- **鼠标指针控制**：可选择是否在录制中显示鼠标
- **详细帮助文档**：包含丰富用例和故障排查指南

## 系统要求

- **macOS 12.3 及以上**（ScreenCaptureKit 必需）
- **Xcode 14.3 及以上**（源码编译）
- **系统偏好设置中开启屏幕录制权限**
- **麦克风权限**（仅在使用 `--enable-microphone` 时需要）

## 安装方法

### 源码安装

```bash
# 克隆仓库
git clone <repository-url>
cd ScreenRecorder

# 编译发布版本
swift build -c release

# 可执行文件位置：
.build/release/ScreenRecorder
```

### Homebrew（即将上线）

```bash
# 即将通过 Homebrew 提供
brew install screenrecorder
```

## 快速开始

```bash
# 基础 10 秒录制
screenrecorder

# 录制 30 秒
screenrecorder --duration 30000

# 保存到指定文件
screenrecorder --output ~/Desktop/demo.mov

# 录制并包含麦克风音频
screenrecorder --enable-microphone --duration 15000
```

## 用法说明

### 基本语法

```bash
screenrecorder [OPTIONS]
```

### 时长控制

```bash
# 指定录制时长（毫秒）
screenrecorder --duration 5000          # 5 秒
screenrecorder -d 30000                 # 30 秒（短参数）
screenrecorder --duration 120000        # 2 分钟
```

### 输出文件管理

```bash
# 保存到指定位置
screenrecorder --output ~/Desktop/recording.mov
screenrecorder -o ./videos/demo.mp4

# 默认：当前目录下按时间戳命名（YYYY-MM-DD_HH-MM-SS.mov）
screenrecorder  # 生成如：2024-01-15_14-30-25.mov
```

### 屏幕与显示器选择

```bash
# 列出可用屏幕	screenrecorder --screen-list
screenrecorder -l

# 录制指定屏幕
screenrecorder --screen 1               # 主显示器
screenrecorder --screen 2               # 次显示器
screenrecorder -s 2                     # 短参数
```

### 区域选择

```bash
# 录制指定区域（x:y:width:height）
screenrecorder --area 0:0:1920:1080     # 全高清区域
screenrecorder --area 100:100:800:600   # 800x600，起点 100,100
screenrecorder -a 0:0:1280:720          # 720p 区域（短参数）

# 可与屏幕选择组合
screenrecorder --screen 2 --area 0:0:1920:1080
```

### 应用窗口录制

```bash
# 列出正在运行的应用	screenrecorder --app-list
screenrecorder -L

# 录制指定应用窗口
screenrecorder --app Safari
screenrecorder --app "Final Cut Pro"    # 带空格需加引号
screenrecorder -A Terminal              # 短参数
```

### 音频录制

```bash
# 启用麦克风录制（系统音频默认包含）
screenrecorder --enable-microphone
screenrecorder -m                       # 短参数

# 设置音频质量
screenrecorder --enable-microphone --audio-quality high
```

### 画质与格式选项

```bash
# 帧率控制
screenrecorder --fps 15                 # 静态内容建议
screenrecorder --fps 30                 # 标准（默认）
screenrecorder --fps 60                 # 流畅运动

# 画质预设
screenrecorder --quality low            # 文件较小（约 2Mbps）
screenrecorder --quality medium         # 平衡（默认，约 5Mbps）
screenrecorder --quality high           # 最佳画质（约 10Mbps）

# 输出格式
screenrecorder --format mov             # QuickTime（默认）
screenrecorder --format mp4             # MP4，兼容性更好
```

### 高级功能

```bash
# 录制中显示鼠标指针
screenrecorder --show-cursor

# 录制前倒计时
screenrecorder --countdown 5            # 5 秒倒计时
screenrecorder --countdown 3 --show-cursor

# 多参数组合
screenrecorder --screen 2 --area 0:0:1920:1080 --enable-microphone \
               --fps 30 --quality high --countdown 5 --show-cursor \
               --output ~/Desktop/presentation.mp4
```

### 预设管理

```bash
# 保存当前配置为预设
screenrecorder --save-preset "meeting"
screenrecorder --duration 30000 --enable-microphone --quality high \
               --save-preset "presentation"

# 使用已保存预设
screenrecorder --preset "meeting"
screenrecorder --preset "presentation" --output ~/Desktop/demo.mov

# 列出所有预设
screenrecorder --list-presets

# 删除预设
screenrecorder --delete-preset "old-config"
```

## 示例

### 快速录制场景

```bash
# 快速 10 秒屏幕录制
screenrecorder

# 30 秒演示录制并倒计时
screenrecorder --duration 30000 --countdown 3 --show-cursor

# 高质量应用演示
screenrecorder --app Safari --duration 60000 --quality high --fps 60 \
               --output ~/Desktop/safari-demo.mp4
```

### 多屏场景

```bash
# 列出可用显示器
screenrecorder --screen-list

# 录制次显示器全高清
screenrecorder --screen 2 --area 0:0:1920:1080 --quality high

# 主显示器自定义区域
screenrecorder --screen 1 --area 0:0:2560:1440 --format mp4
```

### 音频录制

```bash
# 教学录制并启用麦克风
screenrecorder --enable-microphone --duration 300000 --quality high \
               --show-cursor --countdown 5

# 高质量音频录制
screenrecorder --enable-microphone --audio-quality high --quality high
```

### 预设工作流

```bash
# 为不同场景创建预设
screenrecorder --duration 30000 --enable-microphone --quality high \
               --fps 30 --show-cursor --save-preset "tutorial"

screenrecorder --app Safari --duration 60000 --quality medium \
               --fps 60 --save-preset "browser-demo"

screenrecorder --screen 2 --quality low --fps 15 \
               --save-preset "secondary-screen"

# 使用预设
screenrecorder --preset "tutorial" --output ~/Desktop/lesson1.mov
screenrecorder --preset "browser-demo"
screenrecorder --preset "secondary-screen" --duration 120000
```

## 命令参考

### 信息类命令

| 命令                  | 说明               |
| --------------------- | ------------------ |
| `--help`, `-h`        | 显示详细帮助和示例 |
| `--version`           | 显示版本信息       |
| `--screen-list`, `-l` | 列出可用屏幕及详情 |
| `--app-list`, `-L`    | 列出正在运行的应用 |
| `--list-presets`      | 显示所有已保存预设 |

### 录制选项

| 选项         | 短参数 | 说明                         | 默认值         |
| ------------ | ------ | ---------------------------- | -------------- |
| `--duration` | `-d`   | 录制时长（毫秒）             | 10000（10 秒） |
| `--output`   | `-o`   | 输出文件路径                 | 时间戳文件     |
| `--screen`   | `-s`   | 录制屏幕索引                 | 1（主屏幕）    |
| `--area`     | `-a`   | 录制区域（x:y:width:height） | 全屏           |
| `--app`      | `-A`   | 录制应用名称                 | 无             |

### 画质选项

| 选项              | 说明         | 可选值            | 默认值 |
| ----------------- | ------------ | ----------------- | ------ |
| `--fps`           | 帧率         | 15, 30, 60        | 30     |
| `--quality`       | 视频质量预设 | low, medium, high | medium |
| `--format`        | 输出格式     | mov, mp4          | mov    |
| `--audio-quality` | 音频质量预设 | low, medium, high | medium |

### 音频与视觉

| 选项                  | 短参数 | 说明               | 默认值 |
| --------------------- | ------ | ------------------ | ------ |
| `--enable-microphone` | `-m`   | 包含麦克风音频     | 关闭   |
| `--show-cursor`       |        | 录制中显示鼠标     | 关闭   |
| `--countdown`         |        | 录制前倒计时（秒） | 0      |

### 预设管理

| 选项                     | 说明               |
| ------------------------ | ------------------ |
| `--save-preset <name>`   | 保存当前配置为预设 |
| `--preset <name>`        | 加载预设配置       |
| `--delete-preset <name>` | 删除预设           |

## 权限设置

### 屏幕录制权限

1. 打开 **系统偏好设置** > **安全性与隐私** > **隐私**
2. 左侧选择 **屏幕录制**
3. 点击锁图标并输入密码
4. 添加你的终端应用（Terminal、iTerm2 等）
5. 勾选终端应用旁的复选框
6. 重启终端应用

### 麦克风权限（可选）

仅在使用 `--enable-microphone` 时需要：

1. 打开 **系统偏好设置** > **安全性与隐私** > **隐私**
2. 左侧选择 **麦克风**
3. 添加并勾选你的终端应用
4. 重启终端应用

## 故障排查

### 常见问题

#### 权限错误

**“屏幕录制权限被拒绝”**

- 按照权限设置部分为终端授予屏幕录制权限
- 授权后重启终端
- 确认在系统偏好设置中选择了正确的终端应用

**“麦克风权限被拒绝”**

- 按照权限设置部分为终端授予麦克风权限
- 仅在使用 `--enable-microphone` 时出现
- 若麦克风权限失败，仅录制系统音频

#### 屏幕/显示器问题

**“未找到屏幕 X”**

- 使用 `--screen-list` 查看可用屏幕
- 屏幕索引从 1 开始
- 外接显示器断开后索引可能变化

**“区域坐标无效”**

- 使用 `--screen-list` 查看屏幕分辨率
- 坐标需在屏幕范围内
- 格式：`x:y:width:height`（均为正整数）

#### 应用录制问题

**“未找到应用 'X'”**

- 使用 `--app-list` 查看应用名称
- 名称区分大小写
- 应用需运行且有可见窗口
- 带空格名称需加引号，如：`"Final Cut Pro"`

#### 文件输出问题

**保存时“权限被拒绝”**

- 检查输出目录写入权限
- 尝试保存到 `~/Desktop` 或 `~/Documents`
- 确保父目录已存在

**文件扩展名不匹配**

- 确认文件扩展名与 `--format` 参数一致
- `.mov` 对应 `--format mov`，`.mp4` 对应 `--format mp4`

### 性能建议

**提升性能：**

- 长时间录制建议用 `--quality low`
- 静态内容用 `--fps 15`
- 标准录制用 `--fps 30`
- 流畅运动用 `--fps 60`
- 用 `--area` 录制部分区域可减小负载
- 录制前关闭不必要的应用

**减小文件体积：**

- 用 `--quality low` 或 `--quality medium`
- 降低帧率用 `--fps 15` 或 `--fps 30`
- 用 `--format mp4` 获得更好压缩
- 录制部分区域而非全屏

**最佳画质：**

- 用 `--quality high` 配合 `--fps 60`
- 用 `--format mov` 获得最佳 macOS 兼容性
- 确保磁盘空间充足（长录制建议 1GB+）

### 系统要求问题

**“系统要求不满足”**

- 需 macOS 12.3 及以上
- 通过系统偏好设置 > 软件更新升级 macOS
- 旧版 macOS 无法使用 ScreenCaptureKit

## 高级用法

### 脚本与自动化

```bash
#!/bin/bash
# 自动录制脚本示例

# 设置变量
DURATION=30000
OUTPUT_DIR="$HOME/Desktop/recordings"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 用预设录制
screenrecorder --preset "meeting" \
               --duration "$DURATION" \
               --output "$OUTPUT_DIR/meeting_$TIMESTAMP.mov"

echo "录制已保存到: $OUTPUT_DIR/meeting_$TIMESTAMP.mov"
```

### 批量录制

```bash
# 依次录制多个应用
apps=("Safari" "Terminal" "Finder")

for app in "${apps[@]}"; do
    echo "正在录制 $app..."
    screenrecorder --app "$app" --duration 10000 \
                   --output "~/Desktop/${app}_demo.mov"
    sleep 2  # 录制间隔
 done
```

### 与其他工具集成

```bash
# 与 ffmpeg 联合后处理
screenrecorder --duration 30000 --quality high --output temp_recording.mov
ffmpeg -i temp_recording.mov -vf "scale=1280:720" final_recording.mp4
rm temp_recording.mov
```

## 源码编译

### 依赖要求

- macOS 12.3 及以上
- Xcode 14.3 及以上
- Swift 5.6 及以上

### 编译步骤

```bash
# 克隆仓库
git clone <repository-url>
cd ScreenRecorder

# 清理旧构建
swift package clean

# 编译调试版（开发用）
swift build

# 编译发布版（优化）
swift build -c release

# 运行测试
swift test

# 全局安装（可选）
cp .build/release/ScreenRecorder /usr/local/bin/screenrecorder
```

### 开发调试

```bash
# 用 Swift 直接运行
swift run ScreenRecorder --help

# 运行带参数
swift run ScreenRecorder --duration 5000 --output test.mov

# 编译并运行发布版
swift build -c release
.build/release/ScreenRecorder --screen-list
```

## 贡献方式

1. Fork 仓库
2. 创建功能分支
3. 完成功能开发
4. 为新功能添加测试
5. 确保所有测试通过：`swift test`
6. 提交 Pull Request

## 许可证

[待补充 License 信息]

## 更新日志

### 2.0.0 版本

- 使用 Swift ArgumentParser 重写
- 新增多屏支持
- 新增应用窗口录制
- 新增预设管理系统
- 新增全面命令行界面
- 新增音频质量控制
- 新增倒计时功能
- 新增鼠标指针显示控制
- 新增多种输出格式（MOV, MP4）
- 新增详细帮助与故障排查

### 1.0.0 版本

- 基础屏幕录制功能
- 集成 ScreenCaptureKit
- 基础命令行界面

---

更多信息请使用 `screenrecorder --help` 或访问项目仓库。
