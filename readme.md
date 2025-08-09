# ScreenRecorder

A professional screen recording tool for macOS built with ScreenCaptureKit, featuring comprehensive CLI interface, multi-screen support, application window recording, and advanced audio/video controls.

## Features

- **Professional CLI Interface**: Built with Swift ArgumentParser for robust command-line experience
- **Multi-Screen Support**: Record from any connected display with automatic detection
- **Application Window Recording**: Record specific applications instead of entire screens
- **Advanced Audio Control**: System audio recording with optional microphone input
- **Flexible Area Selection**: Record full screen, custom areas, or centered regions
- **Quality Controls**: Configurable frame rates (15/30/60 fps) and quality presets
- **Multiple Output Formats**: Support for MOV and MP4 formats
- **Preset Management**: Save and reuse recording configurations
- **Countdown Timer**: Optional countdown before recording starts
- **Cursor Control**: Show or hide cursor in recordings
- **Comprehensive Help**: Detailed usage examples and troubleshooting guide

## System Requirements

- **macOS 12.3 or later** (required for ScreenCaptureKit)
- **Xcode 14.3 or later** (for building from source)
- **Screen Recording permission** in System Preferences
- **Microphone permission** (only when using `--enable-microphone`)

## Installation

### From Source

```bash
# Clone the repository
git clone <repository-url>
cd ScreenRecorder

# Build release version
swift build -c release

# The executable will be available at:
.build/release/ScreenRecorder
```

### Homebrew (Coming Soon)

```bash
# Will be available via Homebrew
brew install screenrecorder
```

## Quick Start

```bash
# Basic 10-second recording
screenrecorder

# Record for 30 seconds
screenrecorder --duration 30000

# Record to specific file
screenrecorder --output ~/Desktop/demo.mov

# Record with microphone audio
screenrecorder --enable-microphone --duration 15000
```

## Usage

### Basic Syntax

```bash
screenrecorder [OPTIONS]
```

### Duration Control

```bash
# Record for specific duration (in milliseconds)
screenrecorder --duration 5000          # 5 seconds
screenrecorder -d 30000                  # 30 seconds (short flag)
screenrecorder --duration 120000         # 2 minutes
```

### Output File Management

```bash
# Save to specific location
screenrecorder --output ~/Desktop/recording.mov
screenrecorder -o ./videos/demo.mp4

# Default: Current directory with timestamp (YYYY-MM-DD_HH-MM-SS.mov)
screenrecorder  # Creates: 2024-01-15_14-30-25.mov
```

### Screen and Display Selection

```bash
# List available screens
screenrecorder --screen-list
screenrecorder -l

# Record from specific screen
screenrecorder --screen 1               # Primary display
screenrecorder --screen 2               # Secondary display
screenrecorder -s 2                     # Short flag
```

### Area Selection

```bash
# Record specific area (x:y:width:height)
screenrecorder --area 0:0:1920:1080     # Full HD area
screenrecorder --area 100:100:800:600   # 800x600 at position 100,100
screenrecorder -a 0:0:1280:720          # 720p area (short flag)

# Combine with screen selection
screenrecorder --screen 2 --area 0:0:1920:1080
```

### Application Window Recording

```bash
# List running applications
screenrecorder --app-list
screenrecorder -L

# Record specific application
screenrecorder --app Safari
screenrecorder --app "Final Cut Pro"    # Quote names with spaces
screenrecorder -A Terminal               # Short flag
```

### Audio Recording

```bash
# Enable microphone recording (system audio always included)
screenrecorder --enable-microphone
screenrecorder -m                       # Short flag

# Set audio quality
screenrecorder --enable-microphone --audio-quality high
```

### Quality and Format Options

```bash
# Frame rate control
screenrecorder --fps 15                 # Lower for static content
screenrecorder --fps 30                 # Standard (default)
screenrecorder --fps 60                 # Smooth motion

# Quality presets
screenrecorder --quality low            # Smaller files (~2Mbps)
screenrecorder --quality medium         # Balanced (default, ~5Mbps)
screenrecorder --quality high           # Best quality (~10Mbps)

# Output format
screenrecorder --format mov             # QuickTime (default)
screenrecorder --format mp4             # MP4 for broader compatibility
```

### Advanced Features

```bash
# Show cursor in recording
screenrecorder --show-cursor

# Countdown before recording
screenrecorder --countdown 5            # 5-second countdown
screenrecorder --countdown 3 --show-cursor

# Combine multiple options
screenrecorder --screen 2 --area 0:0:1920:1080 --enable-microphone \
               --fps 30 --quality high --countdown 5 --show-cursor \
               --output ~/Desktop/presentation.mp4
```

### Preset Management

```bash
# Save current settings as preset
screenrecorder --save-preset "meeting"
screenrecorder --duration 30000 --enable-microphone --quality high \
               --save-preset "presentation"

# Use saved preset
screenrecorder --preset "meeting"
screenrecorder --preset "presentation" --output ~/Desktop/demo.mov

# List all presets
screenrecorder --list-presets

# Delete preset
screenrecorder --delete-preset "old-config"
```

## Examples

### Quick Recording Scenarios

```bash
# Quick 10-second screen capture
screenrecorder

# 30-second presentation recording with countdown
screenrecorder --duration 30000 --countdown 3 --show-cursor

# High-quality application demo
screenrecorder --app Safari --duration 60000 --quality high --fps 60 \
               --output ~/Desktop/safari-demo.mp4
```

### Multi-Screen Setups

```bash
# List available displays
screenrecorder --screen-list

# Record secondary display in full HD
screenrecorder --screen 2 --area 0:0:1920:1080 --quality high

# Record primary display with custom area
screenrecorder --screen 1 --area 0:0:2560:1440 --format mp4
```

### Audio Recording

```bash
# Record with microphone for tutorials
screenrecorder --enable-microphone --duration 300000 --quality high \
               --show-cursor --countdown 5

# High-quality audio recording
screenrecorder --enable-microphone --audio-quality high --quality high
```

### Preset Workflows

```bash
# Create presets for different scenarios
screenrecorder --duration 30000 --enable-microphone --quality high \
               --fps 30 --show-cursor --save-preset "tutorial"

screenrecorder --app Safari --duration 60000 --quality medium \
               --fps 60 --save-preset "browser-demo"

screenrecorder --screen 2 --quality low --fps 15 \
               --save-preset "secondary-screen"

# Use presets
screenrecorder --preset "tutorial" --output ~/Desktop/lesson1.mov
screenrecorder --preset "browser-demo"
screenrecorder --preset "secondary-screen" --duration 120000
```

## Command Reference

### Information Commands

| Command | Description |
|---------|-------------|
| `--help`, `-h` | Show comprehensive help and examples |
| `--version` | Display version information |
| `--screen-list`, `-l` | List available screens with details |
| `--app-list`, `-L` | List running applications |
| `--list-presets` | Show all saved presets |

### Recording Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--duration` | `-d` | Recording duration in milliseconds | 10000 (10s) |
| `--output` | `-o` | Output file path | Timestamped file |
| `--screen` | `-s` | Screen index to record | 1 (primary) |
| `--area` | `-a` | Recording area (x:y:width:height) | Full screen |
| `--app` | `-A` | Application name to record | None |

### Quality Options

| Option | Description | Values | Default |
|--------|-------------|--------|---------|
| `--fps` | Frame rate | 15, 30, 60 | 30 |
| `--quality` | Video quality preset | low, medium, high | medium |
| `--format` | Output format | mov, mp4 | mov |
| `--audio-quality` | Audio quality preset | low, medium, high | medium |

### Audio and Visual

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--enable-microphone` | `-m` | Include microphone audio | Off |
| `--show-cursor` | | Show cursor in recording | Off |
| `--countdown` | | Countdown seconds before start | 0 |

### Preset Management

| Option | Description |
|--------|-------------|
| `--save-preset <name>` | Save current settings as preset |
| `--preset <name>` | Load settings from preset |
| `--delete-preset <name>` | Delete saved preset |

## Permissions Setup

### Screen Recording Permission

1. Open **System Preferences** > **Security & Privacy** > **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the lock icon and enter your password
4. Add your terminal application (Terminal, iTerm2, etc.)
5. Enable the checkbox next to your terminal
6. Restart your terminal application

### Microphone Permission (Optional)

Only required when using `--enable-microphone`:

1. Open **System Preferences** > **Security & Privacy** > **Privacy**
2. Select **Microphone** from the left sidebar
3. Add and enable your terminal application
4. Restart your terminal application

## Troubleshooting

### Common Issues

#### Permission Errors

**"Screen Recording permission denied"**
- Grant Screen Recording permission to your terminal (see Permissions Setup)
- Restart terminal after granting permission
- Ensure you're using the correct terminal app in System Preferences

**"Microphone permission denied"**
- Grant Microphone permission to your terminal (see Permissions Setup)
- Only occurs when using `--enable-microphone`
- Recording continues with system audio only if microphone fails

#### Screen/Display Issues

**"Screen X not found"**
- Use `--screen-list` to see available screens
- Screen indices start at 1, not 0
- External displays may change indices when disconnected

**"Invalid area coordinates"**
- Check screen resolution with `--screen-list`
- Ensure coordinates are within screen bounds
- Format: `x:y:width:height` (all positive integers)

#### Application Recording Issues

**"Application 'X' not found"**
- Use `--app-list` to see exact application names
- Names are case-sensitive
- Application must be running with visible windows
- Use quotes for names with spaces: `"Final Cut Pro"`

#### File Output Issues

**"Permission denied" when saving**
- Check write permissions for output directory
- Try saving to `~/Desktop` or `~/Documents`
- Ensure parent directories exist

**"File extension mismatch"**
- Ensure file extension matches `--format` option
- `.mov` for `--format mov`, `.mp4` for `--format mp4`

### Performance Tips

**For Better Performance:**
- Use `--quality low` for longer recordings
- Use `--fps 15` for static content (presentations, code)
- Use `--fps 30` for standard recordings
- Use `--fps 60` only for smooth motion capture
- Record smaller areas with `--area` instead of full screen
- Close unnecessary applications before recording

**For Smaller File Sizes:**
- Use `--quality low` or `--quality medium`
- Lower frame rate with `--fps 15` or `--fps 30`
- Use `--format mp4` for better compression
- Record specific areas instead of full screen

**For Best Quality:**
- Use `--quality high` with `--fps 60`
- Use `--format mov` for best macOS compatibility
- Ensure sufficient disk space (1GB+ for longer recordings)

### System Requirements Issues

**"System requirements not met"**
- Requires macOS 12.3 or later
- Update macOS through System Preferences > Software Update
- ScreenCaptureKit is not available on older macOS versions

## Advanced Usage

### Scripting and Automation

```bash
#!/bin/bash
# Example script for automated recording

# Set up variables
DURATION=30000
OUTPUT_DIR="$HOME/Desktop/recordings"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Record with preset
screenrecorder --preset "meeting" \
               --duration "$DURATION" \
               --output "$OUTPUT_DIR/meeting_$TIMESTAMP.mov"

echo "Recording saved to: $OUTPUT_DIR/meeting_$TIMESTAMP.mov"
```

### Batch Recording

```bash
# Record multiple applications in sequence
apps=("Safari" "Terminal" "Finder")

for app in "${apps[@]}"; do
    echo "Recording $app..."
    screenrecorder --app "$app" --duration 10000 \
                   --output "~/Desktop/${app}_demo.mov"
    sleep 2  # Brief pause between recordings
done
```

### Integration with Other Tools

```bash
# Combine with ffmpeg for post-processing
screenrecorder --duration 30000 --quality high --output temp_recording.mov
ffmpeg -i temp_recording.mov -vf "scale=1280:720" final_recording.mp4
rm temp_recording.mov
```

## Building from Source

### Prerequisites

- macOS 12.3 or later
- Xcode 14.3 or later
- Swift 5.6 or later

### Build Steps

```bash
# Clone repository
git clone <repository-url>
cd ScreenRecorder

# Clean previous builds
swift package clean

# Build debug version (for development)
swift build

# Build release version (optimized)
swift build -c release

# Run tests
swift test

# Install globally (optional)
cp .build/release/ScreenRecorder /usr/local/bin/screenrecorder
```

### Development

```bash
# Run directly with Swift
swift run ScreenRecorder --help

# Run with arguments
swift run ScreenRecorder --duration 5000 --output test.mov

# Build and run release version
swift build -c release
.build/release/ScreenRecorder --screen-list
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `swift test`
6. Submit a pull request

## License

[License information to be added]

## Changelog

### Version 2.0.0
- Complete rewrite with Swift ArgumentParser
- Added multi-screen support
- Added application window recording
- Added preset management system
- Added comprehensive CLI interface
- Added audio quality controls
- Added countdown functionality
- Added cursor visibility control
- Added multiple output formats (MOV, MP4)
- Added comprehensive help and troubleshooting

### Version 1.0.0
- Initial release with basic screen recording
- ScreenCaptureKit integration
- Basic command-line interface

---

For more information, use `screenrecorder --help` or visit the project repository.