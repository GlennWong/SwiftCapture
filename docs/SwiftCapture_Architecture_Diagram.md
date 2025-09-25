# SwiftCapture Architecture Diagram

```mermaid
graph TB
    A[SwiftCaptureCommand<br/>CLI Entry Point] --> B[ConfigurationManager]
    A --> C[ParameterValidator]
    
    B --> D[RecordingConfiguration]
    B --> E[PresetStorage]
    
    D --> F[ScreenRecorder]
    
    F --> G[CaptureController]
    F --> H[DisplayManager]
    F --> I[ApplicationManager]
    F --> J[OutputManager]
    F --> K[SignalHandler]
    F --> L[ProgressIndicator]
    
    G --> M[ScreenCaptureKit<br/>Native API]
    
    J --> N[AVFoundation<br/>File Writing]
    
    E --> O[Preset Files<br/>JSON Storage]
    
    H --> P[Screen Info]
    I --> Q[Application Info]
    
    K --> R[Graceful Shutdown<br/>Ctrl+C Handling]
    
    subgraph "Core Components"
        F
        G
        H
        I
        J
        K
        L
    end
    
    subgraph "Data Models"
        D
        P
        Q
    end
    
    subgraph "Storage"
        E
        O
    end
    
    subgraph "External Frameworks"
        M
        N
    end
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style F fill:#e8f5e8
    style G fill:#fff3e0
    style J fill:#fce4ec
    style K fill:#f1f8e9
    style D fill:#e0f2f1
```

This diagram illustrates the main components of SwiftCapture and their relationships:

1. **CLI Layer**: `SwiftCaptureCommand` serves as the entry point, handling all command-line arguments
2. **Configuration Layer**: `ConfigurationManager` and `ParameterValidator` work together to process and validate user input
3. **Core Layer**: `ScreenRecorder` coordinates the recording process, delegating to specialized components
4. **Specialized Managers**: Handle specific aspects like display, applications, audio, and output
5. **Native Integration**: Direct integration with ScreenCaptureKit and AVFoundation
6. **Data Models**: Structured data representations used throughout the application
7. **Storage**: Preset persistence using JSON files