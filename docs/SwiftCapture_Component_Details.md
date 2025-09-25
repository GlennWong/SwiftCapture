# SwiftCapture Component Details

## Core Components

### 1. SwiftCaptureCommand (CLI)

The main command-line interface that handles all user input and argument parsing.

**Key Responsibilities:**
- Parse command-line arguments using Swift ArgumentParser
- Validate parameters before execution
- Handle list operations (screens, applications, presets)
- Manage preset operations (save, load, delete, list)
- Execute recording process
- Handle error reporting

**Special Features:**
- Comprehensive help system with examples
- JSON output support for programmatic use
- Validation with detailed error messages and suggestions

### 2. ConfigurationManager

Central manager for recording configurations and presets.

**Key Responsibilities:**
- Create `RecordingConfiguration` from CLI parameters
- Load and apply presets
- Validate complete configurations
- Manage preset storage operations

**Key Methods:**
- `createConfiguration(from:)` - Creates configuration from CLI command
- `savePreset(named:configuration:)` - Saves preset to storage
- `loadPreset(named:)` - Loads preset from storage
- `listPresets(jsonOutput:)` - Lists all available presets

### 3. ScreenRecorder

Main coordinator for the recording process.

**Key Responsibilities:**
- Coordinate all recording components
- Manage recording lifecycle
- Handle configuration resolution
- Execute recording process
- Manage progress indication

**Key Methods:**
- `record(with:)` - Execute recording with given configuration
- `listScreens(jsonOutput:)` - List available screens
- `listApplications(jsonOutput:)` - List available applications
- `validateConfiguration(_:)` - Validate recording configuration

### 4. CaptureController

Handles direct integration with ScreenCaptureKit.

**Key Responsibilities:**
- Manage ScreenCaptureKit streams
- Handle content filtering
- Process video and audio samples
- Manage stream lifecycle

**Key Methods:**
- `startCapture(...)` - Start ScreenCaptureKit stream
- `stopCapture(_:)` - Stop ScreenCaptureKit stream
- `createStreamConfiguration(...)` - Create SCStreamConfiguration
- `createContentFilter(...)` - Create SCContentFilter

### 5. SignalHandler

Manages graceful shutdown on Ctrl+C.

**Key Responsibilities:**
- Handle SIGINT signals
- Manage user confirmation for timed recordings
- Coordinate graceful shutdown process
- Provide timeout protection

**Key Methods:**
- `setupGracefulShutdown(...)` - Setup signal handling
- `setupForRecording(...)` - Setup for recording sessions
- `setupForCountdown(...)` - Setup for countdown cancellation
- `cleanup()` - Clean up signal handling

## Manager Components

### 1. DisplayManager

Handles screen detection and management.

**Key Responsibilities:**
- Retrieve and manage screen information
- Validate screen parameters
- Handle screen coordinate systems
- Validate recording areas against screen bounds

**Key Methods:**
- `getAllScreens()` - Get all available screens
- `getScreen(at:)` - Get specific screen by index
- `validateScreen(_:)` - Validate screen index
- `validateArea(_:for:)` - Validate recording area for screen
- `listScreens(jsonOutput:)` - List screens in human or JSON format

### 2. ApplicationManager

Handles application detection and management.

**Key Responsibilities:**
- Retrieve and manage application information
- Validate application parameters
- Handle application window selection
- Manage application activation

**Key Methods:**
- `getAllApplications()` - Get all running applications
- `getApplication(named:)` - Get specific application by name
- `validateApplicationForRecording(_:)` - Validate application for recording
- `bringApplicationToFront(_:)` - Bring application to front
- `listApplications(jsonOutput:)` - List applications in human or JSON format

### 3. AudioManager

Handles audio device management.

**Key Responsibilities:**
- Manage audio device detection
- Handle microphone availability
- Validate audio settings

**Key Methods:**
- `checkMicrophoneAvailability()` - Check if microphone is available
- `validateAudioDevices()` - Validate audio device configuration

### 4. OutputManager

Handles file output and AVAssetWriter management.

**Key Responsibilities:**
- Manage file output operations
- Handle AVAssetWriter configuration
- Manage file conflict resolution
- Handle file finalization

**Key Methods:**
- `generateOutputURL(...)` - Generate output URL with conflict resolution
- `setupRecording(for:)` - Setup complete recording environment
- `finalizeRecording(...)` - Finalize recording and write file
- `validateOutputPath(_:)` - Validate output path and permissions

## Data Models

### 1. RecordingConfiguration

Complete configuration for a recording session.

**Key Properties:**
- `duration` - Recording duration in seconds
- `outputURL` - Output file URL
- `outputFormat` - Output format (MOV)
- `recordingArea` - Area to record
- `targetScreen` - Target screen information
- `targetApplication` - Target application information
- `audioSettings` - Audio recording settings
- `videoSettings` - Video recording settings
- `countdown` - Countdown before recording
- `verbose` - Verbose output flag

### 2. RecordingPreset

Serializable preset for recording configurations.

**Key Properties:**
- `name` - Preset name
- `duration` - Recording duration in milliseconds
- `area` - Recording area specification
- `screen` - Screen index
- `app` - Application name
- `enableMicrophone` - Whether microphone is enabled
- `fps` - Frame rate
- `quality` - Video quality
- `format` - Output format
- `showCursor` - Whether to show cursor
- `countdown` - Countdown duration
- `audioQuality` - Audio quality
- `createdAt` - When the preset was created
- `lastUsed` - When the preset was last used

### 3. RecordingArea

Defines the area to be recorded.

**Cases:**
- `fullScreen` - Record the entire screen
- `customRect(CGRect)` - Record a custom rectangular area
- `centered(width:height:)` - Record a centered area

**Key Methods:**
- `toCGRect(for:)` - Convert to CGRect in pixel coordinates
- `toLogicalRect(for:)` - Convert to CGRect in logical coordinates
- `validate(against:)` - Validate against screen bounds
- `parse(from:)` - Parse from CLI string

### 4. VideoSettings

Video recording settings with fps and quality controls.

**Key Properties:**
- `fps` - Frames per second
- `quality` - Video quality preset
- `codec` - Video codec to use
- `showCursor` - Whether to show cursor
- `resolution` - Recording resolution

**Key Methods:**
- `bitRate` - Calculate appropriate bitrate
- `frameInterval` - Calculate frame interval
- `avSettings` - Create AV settings dictionary
- `validateFPS(_:)` - Validate fps value

### 5. AudioSettings

Audio recording settings.

**Key Properties:**
- `includeMicrophone` - Whether to include microphone audio
- `includeSystemAudio` - Whether to include system audio
- `forceSystemAudio` - Whether to force system-wide audio
- `quality` - Audio quality preset
- `sampleRate` - Audio sample rate
- `bitRate` - Audio bitrate
- `channels` - Audio channels

**Key Methods:**
- `hasAudio` - Whether any audio is enabled
- `avSettings` - Create AV settings dictionary

## Utility Components

### 1. ParameterValidator

Validates command-line parameters.

**Key Responsibilities:**
- Validate individual parameters
- Provide detailed error messages
- Check system requirements
- Validate file paths and permissions

### 2. PresetStorage

Manages preset persistence.

**Key Responsibilities:**
- Save presets to user preferences
- Load presets from storage
- Manage preset listing and deletion
- Handle preset name validation

### 3. ProgressIndicator

Shows recording progress to the user.

**Key Responsibilities:**
- Display recording duration
- Show file size information
- Update progress during recording
- Handle progress completion

## Error Handling

### 1. ValidationError

Custom error type for validation failures.

**Key Properties:**
- `message` - Error message
- `suggestion` - Suggested solution

### 2. ComprehensiveError

Custom error type for comprehensive error handling.

**Key Properties:**
- `error` - Underlying error
- `exitCode` - Exit code for CLI
- `userMessage` - User-friendly message

## Key Design Patterns

### 1. Modular Architecture

Each component has a single responsibility and communicates with others through well-defined interfaces.

### 2. Dependency Injection

Components receive their dependencies through initialization rather than creating them internally.

### 3. Error Handling

Comprehensive error handling with user-friendly messages and suggestions.

### 4. Configuration as Data

Recording configurations are represented as immutable data structures that can be easily serialized and deserialized.

### 5. Signal Handling

Graceful shutdown with proper cleanup and file finalization.

This architecture provides a robust, maintainable, and extensible foundation for the SwiftCapture screen recording tool.