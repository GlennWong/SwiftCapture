# Implementation Plan

## Important Testing Requirements

**After completing each major feature, you MUST:**

- Build the project using `swift build -c release`
- Run the built executable to generate test recordings
- Use ffmpeg or similar tools to validate the generated video files:
  - Verify resolution, duration, format, and audio tracks match expected parameters
  - Check video quality and technical specifications
  - Ensure all CLI options produce correct output
- Only proceed to the next task after current functionality passes all build and video validation tests

- [x] 1. Set up project structure and dependencies

  - Add Swift ArgumentParser dependency to Package.swift
  - Create modular directory structure for new components
  - Update minimum macOS version requirements if needed
  - _Requirements: 1.1, 1.2, 12.3_

- [x] 2. Implement CLI interface foundation

  - [x] 2.1 Create SwiftCaptureCommand structure with ArgumentParser

    - Define main command structure with all CLI options and flags
    - Implement basic argument parsing for duration, output, area, screen, app, and audio options
    - Add advanced options for fps, quality, format, cursor, and countdown
    - _Requirements: 1.1, 1.2, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1_

  - [x] 2.2 Implement help system and error handling
    - Create comprehensive help text with examples and usage information
    - Implement proper error messages for invalid arguments
    - Add validation for argument combinations and conflicts
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Create core data models and configuration system

  - [x] 3.1 Define core data structures

    - Create ScreenInfo, ApplicationInfo, WindowInfo structs
    - Implement RecordingArea enum with different area selection modes
    - Define VideoSettings, AudioSettings, and RecordingConfiguration structs
    - _Requirements: 4.1, 5.1, 6.1, 7.1, 8.1_

  - [x] 3.2 Implement configuration management
    - Create ConfigurationManager class for handling settings
    - Implement parameter validation logic for all CLI options
    - Add configuration creation from CLI arguments
    - _Requirements: 9.1, 9.2, 10.4_

- [x] 4. Implement display and screen management

  - [x] 4.1 Create DisplayManager class

    - Implement screen detection and listing functionality
    - Add screen selection by index with validation
    - Create screen information display for --screen-list command
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 4.2 Implement recording area calculation
    - Add support for custom area specification (x:y:width:height format)
    - Implement centered area recording mode
    - Add area validation against screen bounds
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 5. Implement application window recording

  - [x] 5.1 Create ApplicationManager class

    - Implement running application detection and listing
    - Add application selection by name with fuzzy matching
    - Create application information display for --app-list command
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 5.2 Integrate application recording with ScreenCaptureKit
    - Modify existing recording logic to support application-specific capture
    - Handle multiple windows for single application
    - Add error handling for minimized or hidden applications
    - _Requirements: 6.4, 6.5_

- [x] 6. Enhance audio recording capabilities

  - [x] 6.1 Create AudioManager class

    - Implement microphone detection and configuration
    - Add audio quality settings and validation
    - Create audio device availability checking
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 6.2 Integrate enhanced audio with existing recording
    - Modify existing audio recording code to support microphone input
    - Add audio quality configuration options
    - Implement graceful fallback when microphone is unavailable
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 7. Implement advanced recording features

  - [x] 7.1 Add frame rate and quality controls

    - Implement fps option with validation (15, 30, 60)
    - Add quality presets (low, medium, high) with appropriate bitrate settings
    - Integrate quality settings with existing AVAssetWriter configuration
    - _Requirements: 8.1, 8.2_

  - [x] 7.2 Add format and cursor options

    - Implement output format selection (MOV, MP4)
    - Add cursor visibility toggle in recordings
    - Modify existing recording configuration to support these options
    - _Requirements: 8.3, 8.4_

  - [x] 7.3 Implement countdown functionality
    - Add countdown timer before recording starts
    - Display countdown progress to user
    - Allow countdown cancellation with Ctrl+C
    - _Requirements: 8.5_

- [x] 8. Create preset management system

  - [x] 8.1 Implement preset storage and retrieval

    - Create PresetStorage class for saving/loading presets to disk
    - Implement preset serialization using Codable
    - Add preset file management in user's home directory
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 8.2 Integrate preset system with CLI
    - Add --save-preset, --preset, --list-presets, --delete-preset options
    - Implement preset loading and merging with CLI arguments
    - Add preset validation and error handling
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 9. Enhance user experience and feedback

  - [x] 9.1 Implement progress indicators

    - Add real-time recording duration display
    - Show recording status and elapsed time during capture
    - Display file size and location upon completion
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 9.2 Improve error handling and messaging
    - Create comprehensive error types with clear messages
    - Add suggested solutions for common errors
    - Implement graceful shutdown on Ctrl+C with partial recording save
    - _Requirements: 10.4, 10.5_

- [x] 10. Refactor existing recording engine

  - [x] 10.1 Extract recording logic into modular components

    - Create CaptureController class from existing recording code
    - Separate ScreenCaptureKit configuration into reusable methods
    - Refactor AVAssetWriter setup into OutputManager class
    - _Requirements: 2.1, 3.1, 7.1_

  - [x] 10.2 Integrate new features with refactored engine
    - Connect new CLI options with refactored recording components
    - Ensure all new features work with existing recording quality
    - Test integration between all components
    - _Requirements: 2.1, 4.1, 5.1, 6.1, 7.1, 8.1_

- [x] 11. Implement output file management

  - [x] 11.1 Create intelligent file naming system

    - Implement default timestamp-based naming (YYYY-MM-DD_HH-MM-SS.mov)
    - Add custom output path support with directory creation
    - Handle file conflicts with user confirmation or auto-numbering
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 11.2 Add output format support
    - Implement MOV and MP4 output format options
    - Configure appropriate codec settings for each format
    - Validate format compatibility with recording settings
    - _Requirements: 8.3_

- [ ] 12. Create comprehensive testing suite

  - [x] 12.1 Implement unit tests for core components

    - Write tests for parameter validation logic
    - Test configuration creation and preset management
    - Create mock tests for display and application detection
    - _Requirements: 1.1, 1.2, 1.4, 9.1, 9.2_

  - [x] 12.2 Add integration tests for recording functionality

    - Test basic screen recording with new CLI interface
    - Test multi-screen and application recording modes
    - Verify audio recording with microphone integration
    - _Requirements: 2.1, 4.1, 5.1, 6.1, 7.1_

  - [x] 12.3 Implement build and video validation testing
    - Build and run the tool after each major feature completion
    - Use ffmpeg or similar tools to validate generated video files (resolution, duration, format, audio tracks)
    - Create automated scripts to verify video quality and technical specifications
    - Test actual recording output against expected parameters for each feature
    - _Requirements: 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1_

- [-] 13. Create bilingual documentation system

  - [x] 13.1 Implement English documentation

    - Create comprehensive README.md with installation and usage instructions
    - Add detailed examples for all CLI options and use cases
    - Include troubleshooting section and system requirements
    - _Requirements: 11.1, 11.3_

  - [x] 13.2 Create Chinese documentation
    - Translate README.md to Chinese (README_zh.md)
    - Ensure technical accuracy and cultural appropriateness
    - Synchronize content between English and Chinese versions
    - _Requirements: 11.2, 11.4_

- [-] 14. Prepare for Homebrew distribution

  - [x] 14.1 Create Homebrew formula and build configuration

    - Write Homebrew formula with proper dependencies and installation steps
    - Configure build settings for release distribution
    - Test installation process on clean macOS systems
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

  - [x] 14.2 Finalize release preparation
    - Create version tagging and release notes
    - Optimize binary size and performance
    - Conduct final testing across different macOS versions and hardware
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
