# Homebrew Tap for ScreenRecorder

This is the official Homebrew tap for ScreenRecorder, a professional screen recording tool for macOS.

## Installation

```bash
# Add the tap
brew tap your-username/screenrecorder

# Install ScreenRecorder
brew install screenrecorder
```

## Alternative Installation

```bash
# Install directly from this tap
brew install your-username/screenrecorder/screenrecorder
```

## Usage

After installation, you can use ScreenRecorder from anywhere:

```bash
# Show help
screenrecorder --help

# Quick 10-second recording
screenrecorder

# Record for 30 seconds with microphone
screenrecorder --duration 30000 --enable-microphone

# List available screens
screenrecorder --screen-list

# List running applications
screenrecorder --app-list
```

## System Requirements

- macOS 12.3 or later (required for ScreenCaptureKit)
- Screen Recording permission in System Preferences
- Microphone permission (optional, for audio recording)

## Permissions Setup

ScreenRecorder requires Screen Recording permission to function:

1. Open **System Preferences** > **Security & Privacy** > **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the lock icon and enter your password
4. Add your terminal application (Terminal, iTerm2, etc.)
5. Enable the checkbox next to your terminal
6. Restart your terminal application

## Support

- [GitHub Repository](https://github.com/your-username/ScreenRecorder)
- [Issues](https://github.com/your-username/ScreenRecorder/issues)
- [Documentation](https://github.com/your-username/ScreenRecorder#readme)

## License

MIT License - see the main repository for details.