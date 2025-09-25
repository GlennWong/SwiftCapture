# SwiftCapture Code Logic Documentation

## Overview

SwiftCapture is a professional screen recording tool for macOS built with ScreenCaptureKit, featuring a comprehensive CLI interface, multi-screen support, application window recording, and advanced audio/video controls. This document provides a detailed overview of the code architecture and logic flow.

## Project Structure

```
SwiftCapture/
├── CLI/                 # Command-line interface components
├── Capture/             # Screen capture implementation
├── Configuration/       # Configuration management
├── Core/                # Core functionality
├── Managers/            # Specialized managers for different functions
├── Models/              # Data models and structures
└── Resources/           # Additional resources
```

## Core Architecture

### 1. Command-Line Interface (CLI)

**Main Entry Point**: `SwiftCaptureCommand.swift`

The CLI uses Swift ArgumentParser to provide a robust command-line interface. Key features include:

- Duration control (`--duration`, `-d`)
- Output options (`--output`, `-o`, `--force`)
- Screen/area selection (`--area`, `--screen`, `--screen-list`)
- Application recording (`--app`, `--app-list`)
- Audio options (`--enable-microphone`, `--audio-quality`)
- Video settings (`--fps`, `--quality`, `--show-cursor`)
- Preset management (`--save-preset`, `--preset`, `--list-presets`, `--delete-preset`)
- Utility options (`--json`, `--verbose`)

### 2. Configuration Management

**Key Components**:
- `ConfigurationManager.swift`: Central configuration management
- `ParameterValidator.swift`: Input parameter validation
- `PresetStorage.swift`: Preset persistence

The configuration system handles:
- CLI parameter parsing and validation
- Preset loading/saving
- Configuration resolution and updating

### 3. Core Recording Engine

**Main Components**:
- `ScreenRecorder.swift`: Main recording coordinator
- `CaptureController.swift`: ScreenCaptureKit integration
- `SignalHandler.swift`: Graceful shutdown handling
- `ProgressIndicator.swift`: Recording progress tracking

### 4. Specialized Managers

- `DisplayManager.swift`: Screen detection and management
- `ApplicationManager.swift`: Application detection and management
- `AudioManager.swift`: Audio device management
- `OutputManager.swift`: File output and AVAssetWriter management

### 5. Data Models

- `RecordingConfiguration.swift`: Complete recording configuration
- `RecordingPreset.swift`: Serializable preset configuration
- `RecordingArea.swift`: Recording area definitions
- `VideoSettings.swift`: Video encoding settings
- `AudioSettings.swift`: Audio recording settings
- `ScreenInfo.swift`: Screen information
- `ApplicationInfo.swift`: Application information
- `WindowInfo.swift`: Window information

## Detailed Logic Flow

### 1. Application Startup

1. **Command Parsing**: `SwiftCaptureCommand` parses CLI arguments
2. **Validation**: Parameters are validated using `ParameterValidator`
3. **Configuration Creation**: `ConfigurationManager` creates `RecordingConfiguration`
4. **Preset Handling**: If specified, presets are loaded and applied

### 2. Recording Process

1. **Configuration Resolution**: Screen and application details are resolved
2. **Output Setup**: `OutputManager` prepares AVAssetWriter and inputs
3. **Capture Initialization**: `CaptureController` sets up ScreenCaptureKit stream
4. **Recording Execution**: `ScreenRecorder` manages the recording lifecycle
5. **Signal Handling**: `SignalHandler` manages graceful shutdown
6. **Progress Tracking**: `ProgressIndicator` shows recording progress
7. **Finalization**: Output is finalized and file is written

### 3. Key Technical Implementations

#### ScreenCaptureKit Integration

The `CaptureController` handles all ScreenCaptureKit operations:
- Content filtering for screen vs. application recording
- Stream configuration with proper resolution and frame rates
- Output handling for both video and audio streams
- Error handling and recovery mechanisms

#### Resolution Handling

The system properly handles:
- Retina display scaling factors
- Screen coordinate systems
- Application window boundaries
- Custom area definitions (including centered areas)

#### Audio Management

Audio recording supports:
- System audio capture (macOS 13.0+)
- Microphone audio mixing
- Quality settings (low/medium/high)
- Force system audio mode for application recording

#### File Output

The output system provides:
- MOV format with H.264/HEVC codecs
- Automatic bitrate calculation based on resolution/fps
- Conflict resolution (overwrite, auto-number, cancel)
- Directory creation and permission handling
- Graceful file finalization with timeout protection

## Error Handling

The system implements comprehensive error handling:
- **Validation Errors**: Detailed error messages with suggestions
- **Runtime Errors**: Graceful recovery and cleanup
- **Signal Handling**: Proper Ctrl+C handling with confirmation prompts
- **File Errors**: Disk space checking and permission validation

## Preset System

Presets allow users to save and reuse configurations:
- JSON-based storage in user preferences
- Full configuration serialization
- Preset listing and management
- Last used tracking

## Performance Considerations

The implementation includes several optimizations:
- Efficient memory management for long recordings
- Adaptive bitrate calculation
- Proper codec selection for different scenarios
- Resolution-aware processing
- Signal handling that doesn't interfere with recording

## Version Compatibility

The code includes version-specific handling:
- macOS 12.3+ requirement for ScreenCaptureKit
- macOS 13.0+ features for system audio
- Backward compatibility for older APIs

## Testing

The project includes unit tests for:
- Configuration management
- Parameter validation
- Preset storage
- Mock managers for isolated testing

## Key Features Implementation

### Continuous vs. Timed Recording

- **Continuous Recording**: Runs until Ctrl+C, with graceful shutdown
- **Timed Recording**: Runs for specified duration with early termination confirmation

### Multi-Screen Support

- Automatic screen detection
- Screen-specific coordinate systems
- Resolution-aware area validation

### Application Recording

- Application window detection
- Intelligent window selection (largest with title)
- Desktop space switching
- Application activation

### Area Selection

- Full screen recording
- Custom rectangular areas
- Centered area recording
- Resolution and bounds validation

## Conclusion

SwiftCapture implements a modular, well-structured architecture that separates concerns while maintaining efficient communication between components. The system provides robust error handling, comprehensive feature coverage, and optimized performance for professional screen recording on macOS.