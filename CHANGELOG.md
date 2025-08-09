# Changelog

All notable changes to ScreenRecorder will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-01-15

### Added

#### Core Features
- **Complete CLI Interface Rewrite**: Professional command-line interface using Swift ArgumentParser
- **Multi-Screen Support**: Record from any connected display with automatic detection
- **Application Window Recording**: Record specific applications instead of entire screens
- **Advanced Audio Control**: System audio recording with optional microphone input
- **Flexible Area Selection**: Record full screen, custom areas, or centered regions
- **Quality Controls**: Configurable frame rates (15/30/60 fps) and quality presets (low/medium/high)
- **Multiple Output Formats**: Support for both MOV and MP4 formats
- **Preset Management**: Save and reuse recording configurations
- **Countdown Timer**: Optional countdown before recording starts (1-10 seconds)
- **Cursor Control**: Show or hide cursor in recordings

#### CLI Options
- `--duration` / `-d`: Recording duration in milliseconds
- `--output` / `-o`: Custom output file path
- `--screen` / `-s`: Screen selection by index
- `--screen-list` / `-sl`: List available screens
- `--area` / `-a`: Custom recording area (x:y:width:height)
- `--app` / `-ap`: Application name to record
- `--app-list` / `-al`: List running applications
- `--enable-microphone` / `-m`: Include microphone audio
- `--fps`: Frame rate control (15, 30, 60)
- `--quality`: Quality presets (low, medium, high)
- `--format`: Output format (mov, mp4)
- `--show-cursor`: Include cursor in recording
- `--countdown`: Countdown before recording starts
- `--save-preset`: Save current settings as preset
- `--preset`: Load settings from preset
- `--list-presets`: Show all saved presets
- `--delete-preset`: Delete saved preset

#### User Experience
- **Comprehensive Help System**: Detailed help with examples and usage information
- **Real-time Progress Indicators**: Recording duration display and status updates
- **Intelligent Error Handling**: Clear error messages with suggested solutions
- **Graceful Shutdown**: Ctrl+C handling with partial recording save
- **File Management**: Automatic timestamp-based naming and directory creation
- **Permission Guidance**: Clear instructions for Screen Recording and Microphone permissions

#### Technical Improvements
- **Modular Architecture**: Clean separation of concerns with dedicated managers
- **ScreenCaptureKit Integration**: Full utilization of modern macOS recording APIs
- **Memory Optimization**: Efficient resource management for long recordings
- **Error Recovery**: Robust error handling and recovery mechanisms
- **Performance Optimization**: Optimized for different recording scenarios

#### Documentation
- **Comprehensive README**: Detailed usage examples and troubleshooting guide
- **Bilingual Support**: Complete documentation in English and Chinese
- **Installation Guide**: Multiple installation methods including Homebrew
- **Permission Setup**: Step-by-step permission configuration guide
- **Advanced Usage**: Scripting examples and automation workflows

#### Distribution
- **Homebrew Formula**: Professional Homebrew package for easy installation
- **Release Automation**: Automated build and release process
- **Cross-Architecture**: Universal binary supporting Intel and Apple Silicon
- **System Integration**: Proper macOS integration with permissions and frameworks

### Changed
- **Minimum System Requirements**: Now requires macOS 12.3+ (for ScreenCaptureKit)
- **Command Interface**: Complete rewrite of command-line argument parsing
- **File Naming**: Default naming changed to timestamp format (YYYY-MM-DD_HH-MM-SS.mov)
- **Audio Handling**: Enhanced audio recording with quality controls
- **Error Messages**: Improved error messages with actionable suggestions

### Technical Details
- **Swift Version**: Updated to Swift 5.6+
- **Dependencies**: Added Swift ArgumentParser for robust CLI handling
- **Frameworks**: ScreenCaptureKit, AVFoundation, CoreMedia, AppKit
- **Architecture**: Universal binary (arm64 + x86_64)
- **Build System**: Swift Package Manager with release optimization

### Migration from 1.x
- Update command-line usage to new argument format
- Grant Screen Recording permission in System Preferences
- Review new default file naming convention
- Explore new features like presets and multi-screen support

### System Requirements
- macOS 12.3 or later (required for ScreenCaptureKit)
- Xcode 14.3 or later (for building from source)
- Screen Recording permission in System Preferences
- Microphone permission (optional, for `--enable-microphone`)

### Installation
```bash
# Homebrew (recommended)
brew install screenrecorder

# From source
git clone <repository-url>
cd ScreenRecorder
swift build -c release
```

### Breaking Changes
- Command-line interface completely changed
- Minimum macOS version increased to 12.3
- Default output naming format changed
- Some legacy options removed or renamed

---

## [1.0.0] - 2023-12-01

### Added
- Initial release with basic screen recording functionality
- ScreenCaptureKit integration for modern macOS recording
- Basic command-line interface
- MOV output format support
- System audio recording

### Technical Details
- Swift 5.5+
- macOS 11.0+ support
- Basic argument parsing
- Single-screen recording only

---

## Upcoming Features (Roadmap)

### Version 2.1.0 (Planned)
- **Shell Completions**: Bash, Zsh, and Fish completion scripts
- **Configuration Files**: YAML/JSON configuration file support
- **Recording Profiles**: Advanced preset system with inheritance
- **Hotkey Support**: Global hotkeys for start/stop recording
- **Live Preview**: Optional preview window during recording
- **Annotation Tools**: Basic drawing and text overlay support

### Version 2.2.0 (Planned)
- **Streaming Support**: RTMP streaming capabilities
- **Cloud Integration**: Direct upload to cloud services
- **Advanced Filters**: Video filters and effects
- **Batch Processing**: Multiple recording queue management
- **Plugin System**: Extensible plugin architecture

### Version 3.0.0 (Future)
- **GUI Application**: Optional graphical user interface
- **Advanced Editing**: Built-in video editing capabilities
- **Team Features**: Shared presets and configurations
- **Analytics**: Recording analytics and optimization suggestions

---

## Support

- **Documentation**: [README.md](README.md) | [README_zh.md](README_zh.md)
- **Issues**: [GitHub Issues](https://github.com/your-username/ScreenRecorder/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/ScreenRecorder/discussions)
- **License**: MIT License

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

---

*For detailed usage instructions and examples, see the [README.md](README.md) file.*