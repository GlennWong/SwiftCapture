import Foundation
import CoreGraphics

// MARK: - JSON Output Models

/// JSON representation of screen information
struct ScreenInfoJSON: Codable {
    let index: Int
    let displayID: UInt32
    let name: String
    let isPrimary: Bool
    let scaleFactor: Double
    let frame: FrameJSON
    let resolution: ResolutionJSON
    
    init(from screenInfo: ScreenInfo) {
        self.index = screenInfo.index
        self.displayID = screenInfo.displayID
        self.name = screenInfo.name
        self.isPrimary = screenInfo.isPrimary
        self.scaleFactor = Double(screenInfo.scaleFactor)
        self.frame = FrameJSON(from: screenInfo.frame)
        
        // Calculate pixel resolution
        let pixelWidth = Int(screenInfo.frame.width * screenInfo.scaleFactor)
        let pixelHeight = Int(screenInfo.frame.height * screenInfo.scaleFactor)
        self.resolution = ResolutionJSON(
            width: pixelWidth,
            height: pixelHeight,
            pointWidth: Int(screenInfo.frame.width),
            pointHeight: Int(screenInfo.frame.height)
        )
    }
}

/// JSON representation of frame/rectangle
struct FrameJSON: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    init(from rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.width)
        self.height = Double(rect.height)
    }
}

/// JSON representation of resolution
struct ResolutionJSON: Codable {
    let width: Int
    let height: Int
    let pointWidth: Int
    let pointHeight: Int
}

/// JSON representation of window information
struct WindowInfoJSON: Codable {
    let windowID: UInt32
    let title: String
    let frame: FrameJSON
    let isOnScreen: Bool
    let size: ResolutionJSON
    
    init(from windowInfo: WindowInfo) {
        self.windowID = windowInfo.windowID
        self.title = windowInfo.title
        self.frame = FrameJSON(from: windowInfo.frame)
        self.isOnScreen = windowInfo.isOnScreen
        self.size = ResolutionJSON(
            width: Int(windowInfo.frame.width),
            height: Int(windowInfo.frame.height),
            pointWidth: Int(windowInfo.frame.width),
            pointHeight: Int(windowInfo.frame.height)
        )
    }
}

/// JSON representation of application information
struct ApplicationInfoJSON: Codable {
    let name: String
    let bundleIdentifier: String
    let processID: Int32
    let isRunning: Bool
    let windowCount: Int
    let windows: [WindowInfoJSON]
    
    init(from appInfo: ApplicationInfo) {
        self.name = appInfo.name
        self.bundleIdentifier = appInfo.bundleIdentifier
        self.processID = appInfo.processID
        self.isRunning = appInfo.isRunning
        self.windowCount = appInfo.windows.count
        self.windows = appInfo.windows.map { WindowInfoJSON(from: $0) }
    }
}

/// JSON representation of recording preset
struct RecordingPresetJSON: Codable {
    let name: String
    let duration: Int
    let area: String?
    let screen: Int
    let app: String?
    let enableMicrophone: Bool
    let fps: Int
    let quality: String
    let format: String
    let showCursor: Bool
    let countdown: Int
    let audioQuality: String
    let createdAt: String
    let lastUsed: String?
    
    init(from preset: RecordingPreset) {
        self.name = preset.name
        self.duration = preset.duration
        self.area = preset.area
        self.screen = preset.screen
        self.app = preset.app
        self.enableMicrophone = preset.enableMicrophone
        self.fps = preset.fps
        self.quality = preset.quality
        self.format = preset.format
        self.showCursor = preset.showCursor
        self.countdown = preset.countdown
        self.audioQuality = preset.audioQuality
        
        let formatter = ISO8601DateFormatter()
        self.createdAt = formatter.string(from: preset.createdAt)
        self.lastUsed = preset.lastUsed.map { formatter.string(from: $0) }
    }
}

// MARK: - JSON Output Containers

/// Container for screen list JSON output
struct ScreenListJSON: Codable {
    let screens: [ScreenInfoJSON]
    let count: Int
    
    init(screens: [ScreenInfo]) {
        self.screens = screens.map { ScreenInfoJSON(from: $0) }
        self.count = screens.count
    }
}

/// Container for application list JSON output
struct ApplicationListJSON: Codable {
    let applications: [ApplicationInfoJSON]
    let count: Int
    
    init(applications: [ApplicationInfo]) {
        self.applications = applications.map { ApplicationInfoJSON(from: $0) }
        self.count = applications.count
    }
}

/// Container for preset list JSON output
struct PresetListJSON: Codable {
    let presets: [RecordingPresetJSON]
    let count: Int
    
    init(presets: [RecordingPreset]) {
        self.presets = presets.map { RecordingPresetJSON(from: $0) }
        self.count = presets.count
    }
}

// MARK: - JSON Utility Extension

extension Encodable {
    /// Convert to pretty-printed JSON string
    func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "JSONConversion", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON data to string"])
        }
        return string
    }
}