# SwiftCapture Recording Process Flow

```mermaid
flowchart TD
    A[User Command<br/>scap --options] --> B[SwiftCaptureCommand<br/>Parse Args]
    B --> C{Validate<br/>Parameters}
    C -->|Valid| D[ConfigurationManager<br/>Create Config]
    C -->|Invalid| E[Show Error<br/>Exit]
    
    D --> F{Preset<br/>Specified?}
    F -->|Yes| G[Load Preset<br/>Apply Settings]
    F -->|No| H[Use CLI<br/>Parameters]
    
    G --> I[Resolve Configuration<br/>Screen/App Details]
    H --> I
    
    I --> J[OutputManager<br/>Setup Writer]
    J --> K[Validate Output<br/>Path/Permissions]
    K --> L[Create AVAssetWriter<br/>Inputs/Adaptor]
    
    L --> M[CaptureController<br/>Setup Stream]
    M --> N[Get Shareable<br/>Content]
    N --> O[Create Stream<br/>Configuration]
    O --> P[Create Content<br/>Filter]
    P --> Q[Initialize<br/>Stream]
    
    Q --> R{Recording<br/>Mode}
    R -->|Screen| S[Screen<br/>Recording]
    R -->|Application| T[Application<br/>Recording]
    
    S --> U[Add Stream<br/>Outputs]
    T --> U
    
    U --> V[Start<br/>Capture]
    V --> W[Show<br/>Countdown]
    
    W --> X{Duration<br/>Specified?}
    X -->|Yes - Timed| Y[Wait for<br/>Duration]
    X -->|No - Continuous| Z[Wait for<br/>Signal]
    
    Y --> AA[SignalHandler<br/>Setup]
    AA --> AB[Wait for<br/>Completion]
    AB -->|Duration Elapsed| AC[Stop Capture]
    AB -->|Ctrl+C| AD[Confirm<br/>Termination]
    AD -->|Yes| AC
    AD -->|No| AB
    
    Z --> AE[SignalHandler<br/>Setup]
    AE --> AF[Wait for<br/>Signal]
    AF -->|Ctrl+C| AC
    
    AC --> AG[Mark Inputs<br/>Finished]
    AG --> AH[OutputManager<br/>Finalize]
    AH --> AI[File Written<br/>Success]
    
    AJ[Progress<br/>Indicator] --> AK[Update<br/>Progress]
    AK --> AL[Show<br/>Status]
    
    subgraph "Setup Phase"
        B
        C
        D
        F
        G
        H
        I
        J
        K
        L
        M
        N
        O
        P
        Q
        R
        S
        T
        U
        V
        W
    end
    
    subgraph "Recording Phase"
        X
        Y
        Z
        AA
        AB
        AC
        AD
        AE
        AF
    end
    
    subgraph "Finalization Phase"
        AG
        AH
        AI
    end
    
    subgraph "Progress Tracking"
        AJ
        AK
        AL
    end
    
    style A fill:#e1f5fe
    style I fill:#f3e5f5
    style V fill:#e8f5e8
    style AC fill:#fff3e0
    style AI fill:#c8e6c9
    style E fill:#ffcdd2
```

## Detailed Process Explanation

### 1. Command Parsing and Validation
- The user executes a command with various options
- `SwiftCaptureCommand` parses all arguments using Swift ArgumentParser
- `ParameterValidator` validates each parameter for correctness

### 2. Configuration Creation
- `ConfigurationManager` creates a `RecordingConfiguration` object
- If a preset is specified, it's loaded and applied to the configuration
- Screen and application details are resolved

### 3. Output Setup
- `OutputManager` prepares the AVAssetWriter for file output
- Output path is validated and conflicts are resolved
- Video and audio inputs are created with appropriate settings

### 4. Capture Initialization
- `CaptureController` retrieves shareable content using ScreenCaptureKit
- Stream configuration is created based on recording settings
- Content filter is set up for screen or application recording

### 5. Recording Execution
- The capture stream is started
- Countdown is displayed if specified
- Recording proceeds in either timed or continuous mode

### 6. Signal Handling
- `SignalHandler` manages Ctrl+C interruptions
- For timed recordings, user confirmation is required for early termination
- For continuous recordings, graceful shutdown is initiated immediately

### 7. Finalization
- Capture stream is stopped
- Inputs are marked as finished
- `OutputManager` finalizes the file writing process
- Progress indicator is stopped and final status is displayed

This flow ensures a robust recording process with proper error handling, user feedback, and graceful shutdown capabilities.