# Homebrew Tap for SwiftCapture

This is the official Homebrew tap for SwiftCapture, a professional screen recording tool for macOS.

## Installation

```bash
# Add the tap
brew tap GlennWong/scap

# Install SwiftCapture
brew install scap
```

## Alternative Installation

```bash
# Install directly from this tap
brew install GlennWong/scap/scap
```

## Usage

After installation, you can use SwiftCapture from anywhere:

```bash
# Show help
scap --help

# Quick 10-second recording
scap

# Record for 30 seconds with microphone
scap --duration 30000 --enable-microphone

# List available screens
scap --screen-list

# List running applications
scap --app-list
```

## System Requirements

- macOS 12.3 or later (required for ScreenCaptureKit)
- Screen Recording permission in System Preferences
- Microphone permission (optional, for audio recording)

## Permissions Setup

SwiftCapture requires Screen Recording permission to function:

1. Open **System Preferences** > **Security & Privacy** > **Privacy**
2. Select **Screen Recording** from the left sidebar
3. Click the lock icon and enter your password
4. Add your terminal application (Terminal, iTerm2, etc.)
5. Enable the checkbox next to your terminal
6. Restart your terminal application

## Support

- [GitHub Repository](https://github.com/GlennWong/SwiftCapture)
- [Issues](https://github.com/GlennWong/SwiftCapture/issues)
- [Documentation](https://github.com/GlennWong/SwiftCapture#readme)

## License

MIT License - see the main repository for details.