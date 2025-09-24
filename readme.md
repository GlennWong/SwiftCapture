# SwiftCapture

[English](README.md) | [中文](README_zh.md)

A professional screen recording tool for macOS built with ScreenCaptureKit, featuring comprehensive CLI interface, multi-screen support, application window recording, and advanced audio/video controls.

## Features

- **Professional CLI Interface**: Built with Swift ArgumentParser for robust command-line experience
- **Multi-Screen Support**: Record from any connected display with automatic detection
- **Application Window Recording**: Record specific applications instead of entire screens
- **Advanced Audio Control**: System audio recording with optional microphone input
- **Flexible Area Selection**: Record full screen, custom areas, or centered regions
- **Quality Controls**: Configurable frame rates (15/30/60 fps) and quality presets
- **High-Quality Output**: Professional MOV format with optimized encoding
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

### Brew

```bash
brew tap GlennWong/swiftcapture
brew install swiftcapture
```

### From Source

```bash
# Clone the repository
git clone https://github.com/GlennWong/SwiftCapture.git
cd SwiftCapture

# Build release version
swift build -c release

# The executable will be available at:
.build/release/SwiftCapture
```

## Quick Start

```bash
# Continuous recording (default) - press Ctrl+C to stop
scap

# Continuous recording with custom output
scap --output ~/Desktop/demo.mov

# Timed recording for 30 seconds
scap --duration 30000

# Record with microphone audio (continuous)
scap --enable-microphone
```

## Usage

### Basic Syntax

```bash
scap [OPTIONS]
```

### Duration Control

```bash
# Continuous recording (default) - no duration specified
scap                          # Record until Ctrl+C is pressed
scap --output video.mov       # Continuous with custom output

# Timed recording - specify duration in milliseconds
scap --duration 5000          # 5 seconds
scap -d 30000                 # 30 seconds (short flag)
scap --duration 120000        # 2 minutes

# Both modes support early termination with Ctrl+C
# Timed recordings require confirmation to prevent accidental termination
```

### Output File Management

```bash
# Save to specific location
scap --output ~/Desktop/recording.mov
scap -o ./videos/demo.mov

# Default: Current directory with timestamp (YYYY-MM-DD_HH-MM-SS.mov)
scap  # Creates: 2024-01-15_14-30-25.mov

# File conflict handling
scap --output existing.mov    # Interactive prompt: overwrite, auto-number, or cancel
scap --output existing.mov --force  # Force overwrite without prompt
# Auto-numbering: existing-2.mov, existing-3.mov, etc.
```

### Screen and Display Selection

```bash
# List available screens
scap --screen-list
scap -l

# Record from specific screen
scap --screen 1               # Primary display
scap --screen 2               # Secondary display
scap -s 2                     # Short flag
```

### Area Selection

```bash
# Record specific area (x:y:width:height)
scap --area 0:0:1920:1080     # Full HD area
scap --area 100:100:800:600   # 800x600 at position 100,100
scap -a 0:0:1280:720          # 720p area (short flag)

# Centered area recording (center:width:height)
scap --area center:1280:720   # 720p centered on screen
scap --area center:800:600    # 800x600 centered area

# Combine with screen selection
scap --screen 2 --area 0:0:1920:1080
```

### Application Window Recording

```bash
# List running applications
scap --app-list
scap -L

# Record specific application
scap --app Safari
scap --app "Final Cut Pro"      # Quote names with spaces
scap -A Terminal                # Short flag

# Smart application recording features:
# - Automatically selects main window (largest with title)
# - Brings application to front before recording
# - Works across multiple desktop spaces
# - Handles window switching and activation
```

### Audio Recording

```bash
# Enable microphone recording (system audio always included)
scap --enable-microphone
scap -m                       # Short flag

# Set audio quality
scap --enable-microphone --audio-quality high
```

### Quality and Format Options

```bash
# Frame rate control
scap --fps 15                 # Lower for static content
scap --fps 30                 # Standard (default)
scap --fps 60                 # Smooth motion

# Quality presets
scap --quality low            # Smaller files (~2Mbps)
scap --quality medium         # Balanced (default, ~5Mbps)
scap --quality high           # Best quality (~10Mbps)

# Output is always in MOV format (QuickTime)
# High-quality, macOS-native format with excellent compatibility

# Verbose output for debugging
scap --verbose                # Show detailed configuration and debug information
scap --duration 30000 --verbose --quality high  # Combine with other options
```

### Advanced Features

```bash
# Show cursor in recording
scap --show-cursor

# Countdown before recording
scap --countdown 5            # 5-second countdown
scap --countdown 3 --show-cursor

# Combine multiple options
scap --screen 2 --area 0:0:1920:1080 --enable-microphone \
               --fps 30 --quality high --countdown 5 --show-cursor \
               --output ~/Desktop/presentation.mov
```

### Preset Management

```bash
# Save current settings as preset
scap --save-preset "meeting"
scap --duration 30000 --enable-microphone --quality high \
               --save-preset "presentation"

# Use saved preset
scap --preset "meeting"
scap --preset "presentation" --output ~/Desktop/demo.mov

# List all presets
scap --list-presets

# Delete preset
scap --delete-preset "old-config"
```

### JSON Output for Programmatic Use

SwiftCapture supports JSON output for all list operations, making it easy to integrate with scripts and other tools:

```bash
# Get screen information in JSON format
scap --screen-list --json

# Get application list in JSON format
scap --app-list --json

# Get presets in JSON format
scap --list-presets --json
```

#### JSON Output Examples

**Screen List JSON:**

```json
{
  "count": 2,
  "screens": [
    {
      "index": 1,
      "displayID": 1,
      "name": "Built-in Display - 3024x1964 - @120Hz - (2.0x scale) - Primary",
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

**Application List JSON:**

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
          "title": "SwiftCapture Documentation",
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

**Preset List JSON:**

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

#### Using JSON Output in Scripts

```bash
#!/bin/bash
# Example: Find the primary screen index programmatically
PRIMARY_SCREEN=$(scap --screen-list --json | jq -r '.screens[] | select(.isPrimary == true) | .index')
echo "Primary screen index: $PRIMARY_SCREEN"

# Example: Get all Safari windows
scap --app-list --json | jq -r '.applications[] | select(.name == "Safari") | .windows[].title'

# Example: Check if a preset exists
PRESET_EXISTS=$(scap --list-presets --json | jq -r '.presets[] | select(.name == "meeting") | .name')
if [ "$PRESET_EXISTS" = "meeting" ]; then
    echo "Meeting preset exists"
fi
```

## Examples

### Quick Recording Scenarios

```bash
# Continuous screen recording (default)
scap                          # Record until Ctrl+C is pressed

# Continuous recording with custom settings
scap --output ~/Desktop/demo.mov --quality high

# 30-second timed recording with countdown
scap --duration 30000 --countdown 3 --show-cursor

# High-quality application demo (continuous)
scap --app Safari --quality high --fps 60 \
               --output ~/Desktop/safari-demo.mov
```

### Multi-Screen Setups

```bash
# List available displays
scap --screen-list

# Record secondary display in full HD
scap --screen 2 --area 0:0:1920:1080 --quality high

# Record primary display with custom area
scap --screen 1 --area 0:0:2560:1440

# Centered recording works across different screen sizes
scap --screen 2 --area center:1920:1080  # Auto-centers on any screen size
```

### Audio Recording

```bash
# Continuous recording with microphone for tutorials
scap --enable-microphone --quality high \
               --show-cursor --countdown 5

# High-quality continuous audio recording
scap --enable-microphone --audio-quality high --quality high

# Timed recording with microphone
scap --enable-microphone --duration 300000 --quality high
```

### Preset Workflows

```bash
# Create presets for different scenarios
scap --duration 30000 --enable-microphone --quality high \
               --fps 30 --show-cursor --save-preset "tutorial"

scap --app Safari --duration 60000 --quality medium \
               --fps 60 --save-preset "browser-demo"

scap --screen 2 --quality low --fps 15 \
               --save-preset "secondary-screen"

# Advanced preset with centered area and countdown
scap --area center:1280:720 --countdown 5 --quality high \
               --enable-microphone --save-preset "presentation"

# Use presets
scap --preset "tutorial" --output ~/Desktop/lesson1.mov
scap --preset "browser-demo"
scap --preset "secondary-screen" --duration 120000

# Override preset settings
scap --preset "tutorial" --duration 60000 --output custom.mov
```

## Command Reference

### Information Commands

| Command               | Description                          |
| --------------------- | ------------------------------------ |
| `--help`, `-h`        | Show comprehensive help and examples |
| `--version`           | Display version information          |
| `--verbose`           | Enable verbose output with detailed configuration and debug info |
| `--screen-list`, `-l` | List available screens with details  |
| `--app-list`, `-L`    | List running applications            |
| `--list-presets`      | Show all saved presets               |
| `--json`              | Output list results in JSON format   |

### Recording Options

| Option       | Short | Description                                              | Default          |
| ------------ | ----- | -------------------------------------------------------- | ---------------- |
| `--duration` | `-d`  | Recording duration in milliseconds (optional)            | Continuous       |
| `--output`   | `-o`  | Output file path                                         | Timestamped file |
| `--screen`   | `-s`  | Screen index to record                                   | 1 (primary)      |
| `--area`     | `-a`  | Recording area (x:y:width:height or center:width:height) | Full screen      |
| `--app`      | `-A`  | Application name to record                               | None             |
| `--force`    | `-f`  | Force overwrite existing files                           | Off              |

### Quality Options

| Option            | Description          | Values            | Default |
| ----------------- | -------------------- | ----------------- | ------- |
| `--fps`           | Frame rate           | 15, 30, 60        | 30      |
| `--quality`       | Video quality preset | low, medium, high | medium  |
| `--audio-quality` | Audio quality preset | low, medium, high | medium  |

### Audio and Visual

| Option                | Short | Description                    | Default |
| --------------------- | ----- | ------------------------------ | ------- |
| `--enable-microphone` | `-m`  | Include microphone audio       | Off     |
| `--show-cursor`       |       | Show cursor in recording       | Off     |
| `--countdown`         |       | Countdown seconds before start | 0       |

### Preset Management

| Option                   | Description                     |
| ------------------------ | ------------------------------- |
| `--save-preset <name>`   | Save current settings as preset |
| `--preset <name>`        | Load settings from preset       |
| `--delete-preset <name>` | Delete saved preset             |

### Early Termination Behavior

SwiftCapture handles Ctrl+C (SIGINT) differently based on recording mode:

**Continuous Recording (no `--duration`):**
- Ctrl+C immediately stops recording and saves the file
- No confirmation required

**Timed Recording (with `--duration`):**
- Ctrl+C shows a confirmation prompt to prevent accidental termination
- Type `y` or `yes` to confirm early termination
- Press Enter or type `n`/`no` to continue recording
- Multiple interrupts are allowed (each shows confirmation)

```bash
# Example: Timed recording with early termination
scap --duration 60000 --output demo.mov
# ... recording starts ...
# Press Ctrl+C
# Prompt: "Recording has a specified duration. Are you sure you want to stop early?"
# Type 'y' to stop or press Enter to continue
```

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

**Application window not visible in recording**

- SwiftCapture automatically brings applications to front
- Wait 1-2 seconds after command starts for window switching
- Ensure application isn't minimized or hidden
- Check if application is on a different desktop space

**Recording shows wrong window**

- SwiftCapture selects the largest window with a title
- Close unnecessary windows before recording
- Use window titles to identify the correct application instance

#### File Output Issues

**"Permission denied" when saving**

- Check write permissions for output directory
- Try saving to `~/Desktop` or `~/Documents`
- Ensure parent directories exist

**"File extension mismatch"**

- Output files are always in MOV format
- Use `.mov` extension for output files

**File conflicts and overwriting**

- Without `--force`: Interactive prompt or auto-numbering
- With `--force`: Automatically overwrites existing files
- Auto-numbered files: `recording-2.mov`, `recording-3.mov`

**"Insufficient disk space" warnings**

- SwiftCapture checks available space before recording
- High-quality recordings can be 1GB+ for longer sessions
- Use `--quality low` for space-constrained situations

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
- Record specific areas instead of full screen

**For Best Quality:**

- Use `--quality high` with `--fps 60`
- MOV format provides excellent macOS compatibility
- Ensure sufficient disk space (1GB+ for longer recordings)

**Automatic Optimizations:**

- SwiftCapture automatically adjusts bitrates based on resolution
- HEVC codec used for high-resolution MOV files (better compression)
- H.264/HEVC codecs provide optimal quality and compatibility
- Quality recommendations based on content type and resolution

### System Requirements Issues

**"System requirements not met"**

- Requires macOS 12.3 or later
- Update macOS through System Preferences > Software Update
- ScreenCaptureKit is not available on older macOS versions

## Technical Details

### Advanced Area Selection

SwiftCapture provides pixel-perfect area recording with intelligent scaling:

- **Retina Display Support**: Automatically handles high-DPI displays with proper scaling
- **Coordinate Systems**: Supports both logical and pixel coordinates
- **Bounds Validation**: Real-time validation against target screen dimensions
- **Smart Centering**: `center:width:height` format for responsive positioning

```bash
# Examples of advanced area selection
scap --area 0:0:3840:2160                 # 4K area on Retina display (auto-scaled)
scap --area center:1920:1080              # 1080p centered regardless of screen size
scap --screen 2 --area 100:100:1280:720   # Specific area on secondary display
```

### Smart Application Recording

Application recording includes advanced window management:

- **Intelligent Window Selection**: Prioritizes main windows with titles over utility windows
- **Cross-Desktop Recording**: Automatically switches to application's desktop space
- **Window Activation**: Brings target application to front for unobstructed recording
- **Multi-Window Handling**: Selects optimal window when applications have multiple windows

```bash
# Application recording with automatic optimization
scap --app "Final Cut Pro" --duration 60000  # Automatically finds and activates main window
scap --app Safari --area center:1280:720     # Records Safari with custom area (not recommended)
```

### File Management & Conflict Resolution

Comprehensive file handling with multiple conflict resolution strategies:

- **Interactive Mode**: Prompts for user choice when files exist
- **Auto-Numbering**: Generates `filename-2.mov`, `filename-3.mov` sequences
- **Force Overwrite**: `--force` flag bypasses all confirmations
- **Directory Creation**: Automatically creates output directories
- **Disk Space Validation**: Checks available space before recording

### Performance Optimization

SwiftCapture automatically optimizes settings based on recording parameters:

- **Adaptive Bitrates**: Calculates optimal bitrate based on resolution and frame rate
- **Codec Selection**: Chooses H.264 or HEVC based on format and quality requirements
- **Memory Management**: Efficient buffer handling for long recordings
- **Quality Scaling**: Recommends quality settings for high-resolution content

## Advanced Usage

### Scripting and Automation

```bash
#!/bin/bash
# Example script for automated recording with advanced features

# Set up variables
DURATION=30000
OUTPUT_DIR="$HOME/Desktop/recordings"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check available screens and select appropriate one
SCREEN_COUNT=$(scap --screen-list | grep -c "Screen")
if [ "$SCREEN_COUNT" -gt 1 ]; then
    SCREEN=2  # Use secondary screen if available
else
    SCREEN=1  # Use primary screen
fi

# Record with intelligent settings
scap --screen "$SCREEN" \
     --area center:1920:1080 \
     --duration "$DURATION" \
     --quality high \
     --fps 30 \
     --countdown 3 \
     --force \
     --output "$OUTPUT_DIR/meeting_$TIMESTAMP.mov"

echo "Recording saved to: $OUTPUT_DIR/meeting_$TIMESTAMP.mov"

# Optional: Convert for sharing if needed
# ffmpeg -i "$OUTPUT_DIR/meeting_$TIMESTAMP.mov" \
#        -c:v libx264 -c:a aac \
#        "$OUTPUT_DIR/meeting_$TIMESTAMP_converted.mov"
```

### Batch Recording

```bash
# Record multiple applications in sequence with smart handling
apps=("Safari" "Terminal" "Finder")

for app in "${apps[@]}"; do
    echo "Recording $app..."

    # Use force flag to avoid interactive prompts in batch mode
    scap --app "$app" \
         --duration 10000 \
         --quality medium \
         --countdown 2 \
         --force \
         --output "~/Desktop/${app}_demo_$(date +%H%M%S).mov"

    sleep 3  # Allow time for app switching and file writing
done

# Batch record different screen areas
areas=("0:0:1920:1080" "center:1280:720" "100:100:800:600")

for i in "${!areas[@]}"; do
    echo "Recording area: ${areas[$i]}"
    scap --area "${areas[$i]}" \
         --duration 5000 \
         --output "~/Desktop/area_${i}_$(date +%H%M%S).mov"
done
```

### Integration with Other Tools

```bash
# Combine with ffmpeg for post-processing
scap --duration 30000 --quality high --output temp_recording.mov
ffmpeg -i temp_recording.mov -vf "scale=1280:720" final_recording.mov
rm temp_recording.mov
```

## Technical Specifications

### Supported Formats and Codecs

| Format | Codecs      | Max Resolution | Compatibility                      |
| ------ | ----------- | -------------- | ---------------------------------- |
| MOV    | H.264, HEVC | 8K (7680×4320) | macOS native, professional quality |

### Quality Settings and Bitrates

| Quality | Base Bitrate | Typical Use Case                | File Size (10min 1080p) |
| ------- | ------------ | ------------------------------- | ----------------------- |
| Low     | 2 Mbps       | Long recordings, static content | ~150 MB                 |
| Medium  | 5 Mbps       | General purpose, presentations  | ~375 MB                 |
| High    | 10 Mbps      | Professional content, motion    | ~750 MB                 |

_Bitrates automatically scale based on resolution and frame rate_

### Frame Rate Recommendations

| Content Type                      | Recommended FPS | Use Case                           |
| --------------------------------- | --------------- | ---------------------------------- |
| Static content (code, documents)  | 15 fps          | Smaller files, adequate quality    |
| General recording                 | 30 fps          | Balanced quality and file size     |
| Smooth motion (games, animations) | 60 fps          | Professional quality, larger files |

### Audio Specifications

| Quality | Sample Rate | Bitrate  | Channels |
| ------- | ----------- | -------- | -------- |
| Low     | 22.05 kHz   | 64 kbps  | Stereo   |
| Medium  | 44.1 kHz    | 128 kbps | Stereo   |
| High    | 48 kHz      | 192 kbps | Stereo   |

### System Performance

- **Memory Usage**: ~50-100 MB during recording
- **CPU Usage**: 5-15% on modern Macs (varies with resolution/fps)
- **Disk I/O**: Real-time writing, ~10-50 MB/s depending on quality
- **Supported Resolutions**: Up to 8K on compatible hardware

## Recent Updates

### Continuous Recording Fix (v2.2.0)

**Fixed**: Critical issue with continuous recording mode where files were corrupted when stopped with Ctrl+C.

**Problem**: Previously, when using continuous recording (default mode without `--duration`), pressing Ctrl+C to stop recording would result in corrupted MOV files with "moov atom not found" errors. Files could not be played or processed by video tools like ffmpeg.

**Solution**: Implemented synchronous file finalization using semaphore-based coordination to ensure proper MOV file closure before process exit.

**Impact**:

- ✅ Continuous recordings now produce valid MOV files compatible with all video players and tools
- ✅ Both continuous and timed recording modes work correctly
- ✅ Files can be validated with `ffmpeg -i filename.mov` without errors
- ✅ Graceful shutdown with proper progress indicators and file statistics

**Usage**:

```bash
# Continuous recording (now fully functional)
scap                    # Start recording, press Ctrl+C to stop
scap --output demo.mov  # Continuous with custom output

# Verify file integrity after recording
ffmpeg -i demo.mov -hide_banner  # Should show valid video/audio streams
```

## Building from Source

### Prerequisites

- macOS 12.3 or later
- Xcode 14.3 or later
- Swift 5.6 or later

### Build Steps

```bash
# Clone repository
git clone https://github.com/GlennWong/SwiftCapture.git
cd Swiftcapture

# Clean previous builds
swift package clean

# Build debug version (for development)
swift build

# Build release version (optimized)
swift build -c release

# Run tests
swift test

# Install globally (optional)
cp .build/release/Swiftcapture /usr/local/bin/scap
```

### Development

```bash
# Run directly with Swift
swift run Swiftcapture --help

# Run with arguments
swift run Swiftcapture --duration 5000 --output test.mov

# Build and run release version
swift build -c release
.build/release/Swiftcapture --screen-list
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
- Added multi-screen support with automatic Retina scaling
- Added intelligent application window recording with auto-activation
- Added preset management system with JSON storage
- Added comprehensive CLI interface with validation
- Added audio quality controls and microphone support
- Added countdown functionality with cancellation support
- Added cursor visibility control
- Added optimized MOV output with advanced codec selection
- Added file conflict resolution (interactive/auto-numbering/force)
- Added centered area recording (`center:width:height`)
- Added automatic bitrate calculation based on resolution/fps
- Added disk space validation and performance warnings
- Added cross-desktop space recording support
- Added comprehensive help and troubleshooting

### Version 1.0.0

- Initial release with basic screen recording
- ScreenCaptureKit integration
- Basic command-line interface

---

For more information, use `scap --help` or visit the project repository.
