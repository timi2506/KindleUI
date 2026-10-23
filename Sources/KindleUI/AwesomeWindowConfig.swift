import Foundation

/// Represents the Awesome Window Manager display layers on the Kindle (`L` key).
public enum KindleLayer: String, Sendable, Codable, CaseIterable {
    /// Application layer (`A`) - standard full-screen Kindle applications.
    case application = "A"
    /// Chrome layer (`C`) - status bars, top bars, and search result overlays.
    case chrome = "C"
    /// Dialog layer (`D`) - modal and dismissible dialogs above the application layer.
    case dialog = "D"
    /// Keyboard layer (`KB`) - on-screen keyboard layer.
    case keyboard = "KB"
    /// Screensaver layer (`SS`) - highest priority layer displayed when asleep.
    case screensaver = "SS"
}

/// Represents the Awesome Window Manager window role/name on the Kindle (`N` key).
public enum KindleWindowRole: String, Sendable, Codable {
    case application = "application"
    case dialog = "dialog"
    case titlebar = "titlebar"
    case searchResult = "searchResult"
    case pillowAlert = "pillowAlert"
    case titleBar = "titleBar"
    case footerBar = "footerBar"
    case topBar = "topBar"
    case mediaBar = "mediaBar"
    case keyboard = "keyboard"
    case keyboardExt = "keyboardExt"
    case activeSS = "activeSS"
    case screenSaver = "screenSaver"
    case searchBar = "searchBar"
}

/// Persistent Chrome flags (`PC` key) controlling which system bars remain visible.
public struct KindleChrome: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Show the Kindle top status bar on modern firmware (`T`).
    public static let topBar    = KindleChrome(rawValue: 1 << 0)
    /// Show the Kindle search/navigation bar (`S`).
    public static let searchBar = KindleChrome(rawValue: 1 << 1)
    /// Show the legacy bottom bar (`B`).
    public static let bottomBar = KindleChrome(rawValue: 1 << 2)

    /// Show no system bars (`N`), giving the app full screen real estate.
    public static let none: KindleChrome = []
    /// Standard top bar + search bar (`TS`).
    public static let topAndSearch: KindleChrome = [.topBar, .searchBar]

    public var titleValue: String {
        if isEmpty {
            return "N"
        }
        var result = ""
        if contains(.topBar) { result += "T" }
        if contains(.searchBar) { result += "S" }
        if contains(.bottomBar) { result += "B" }
        return result
    }
}

/// Bar positioning type (`BARTYPE` key) when using the `.topBar` role.
public enum KindleBarType: String, Sendable, Codable {
    case top = "T"
    case search = "S"
    case bottom = "B"
    case application = "A"
}

/// Supported device orientations (`O` key).
public struct KindleOrientation: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let up    = KindleOrientation(rawValue: 1 << 0)
    public static let down  = KindleOrientation(rawValue: 1 << 1)
    public static let left  = KindleOrientation(rawValue: 1 << 2)
    public static let right = KindleOrientation(rawValue: 1 << 3)

    public static let portrait: KindleOrientation = [.up, .down]
    public static let landscape: KindleOrientation = [.left, .right]
    public static let all: KindleOrientation = [.up, .down, .left, .right]

    public var titleValue: String? {
        if isEmpty { return nil }
        var s = ""
        if contains(.up) { s += "U" }
        if contains(.down) { s += "D" }
        if contains(.left) { s += "L" }
        if contains(.right) { s += "R" }
        return s
    }
}

/// Window visibility flag (`HIDE` key).
public enum KindleHideMode: Sendable, Equatable {
    case visible
    case hidden
    case background
}

/// Rounded corners configuration (`RC` key) for Kindle dialogs.
public enum KindleRoundedCorners: Sendable, Equatable {
    case none
    case standard
    case pixels(Int)
    case custom(topLeft: Bool, topRight: Bool, bottomLeft: Bool, bottomRight: Bool)
}

/// Dialog modality configuration (`M` and `PALMR` keys).
public enum KindleModality: Sendable, Equatable {
    case none
    case modal
    case dismissible(palmRejection: Bool = false)
}

/// Complete configuration for a Kindle Awesome Window Manager window title.
///
/// The Kindle's window manager parses the X11/GTK window title as an `_`-separated
/// key-value store (for example: `L:A_N:application_PC:T_ID:org.kindlemodding.myapp`).
public struct KindleWindowConfig: Sendable, Equatable {
    public var layer: KindleLayer
    public var role: KindleWindowRole
    public var persistentChrome: KindleChrome
    public var applicationID: String
    public var barType: KindleBarType?
    public var orientations: KindleOrientation
    public var hideMode: KindleHideMode
    public var roundedCorners: KindleRoundedCorners
    public var modality: KindleModality
    public var requireKeyboard: Int?
    public var width: Int
    public var height: Int

    public init(
        applicationID: String = "org.kindlemodding.swiftapp",
        layer: KindleLayer = .application,
        role: KindleWindowRole = .application,
        persistentChrome: KindleChrome = .topBar,
        barType: KindleBarType? = nil,
        orientations: KindleOrientation = [],
        hideMode: KindleHideMode = .visible,
        roundedCorners: KindleRoundedCorners = .none,
        modality: KindleModality = .none,
        requireKeyboard: Int? = nil,
        width: Int = 600,
        height: Int = 800
    ) {
        // Sanitize underscores since AwesomeWM uses '_' as the key-value delimiter
        let sanitizedID = applicationID.replacingOccurrences(of: "_", with: "-")
        self.applicationID = sanitizedID == "blankBackground" ? "org.kindlemodding.app" : sanitizedID
        self.layer = layer
        self.role = role
        self.persistentChrome = persistentChrome
        self.barType = barType
        self.orientations = orientations
        self.hideMode = hideMode
        self.roundedCorners = roundedCorners
        self.modality = modality
        self.requireKeyboard = requireKeyboard
        self.width = width
        self.height = height
    }

    /// Preset for a standard Kindle application with the top status bar visible.
    public static func app(
        id: String,
        chrome: KindleChrome = .topBar,
        orientations: KindleOrientation = []
    ) -> KindleWindowConfig {
        KindleWindowConfig(
            applicationID: id,
            layer: .application,
            role: .application,
            persistentChrome: chrome,
            orientations: orientations
        )
    }

    /// Preset for a full-screen Kindle application with all system chrome hidden.
    public static func fullScreenApp(
        id: String,
        orientations: KindleOrientation = []
    ) -> KindleWindowConfig {
        KindleWindowConfig(
            applicationID: id,
            layer: .application,
            role: .application,
            persistentChrome: .none,
            orientations: orientations
        )
    }

    /// Preset for a modal or dismissible Kindle dialog with rounded corners.
    public static func dialog(
        id: String,
        dismissible: Bool = true,
        cornerRadius: Int = 12,
        requiresKeyboard: Bool = false,
        width: Int = 480,
        height: Int = 360
    ) -> KindleWindowConfig {
        KindleWindowConfig(
            applicationID: id,
            layer: .dialog,
            role: .dialog,
            persistentChrome: .none,
            roundedCorners: .pixels(cornerRadius),
            modality: dismissible ? .dismissible(palmRejection: true) : .modal,
            requireKeyboard: requiresKeyboard ? 1 : nil,
            width: width,
            height: height
        )
    }

    /// Formats the configuration into the exact Awesome Window Manager title string expected by Kindle OS.
    public var awesomeWindowTitle: String {
        var parts: [String] = []
        parts.append("L:\(layer.rawValue)")
        parts.append("N:\(role.rawValue)")

        if layer == .application {
            parts.append("PC:\(persistentChrome.titleValue)")
        }

        if let barType = barType, role == .topBar {
            parts.append("BARTYPE:\(barType.rawValue)")
        }

        if let orient = orientations.titleValue {
            parts.append("O:\(orient)")
        }

        switch hideMode {
        case .visible:
            break
        case .hidden:
            parts.append("HIDE")
        case .background:
            parts.append("HIDE:background")
        }

        switch roundedCorners {
        case .none:
            break
        case .standard:
            parts.append("RC")
        case .pixels(let radius):
            parts.append("RC:\(radius)")
        case .custom(let tl, let tr, let bl, let br):
            parts.append("RC:custom")
            if tl { parts.append("RCTL") }
            if tr { parts.append("RCTR") }
            if bl { parts.append("RCBL") }
            if br { parts.append("RCBR") }
        }

        switch modality {
        case .none:
            break
        case .modal:
            parts.append("M")
        case .dismissible(let palmRejection):
            parts.append("M:dismissable")
            if palmRejection {
                parts.append("PALMR")
            }
        }

        if let rkb = requireKeyboard {
            parts.append("RKB:\(rkb)")
        }

        parts.append("ID:\(applicationID)")
        return parts.joined(separator: "_")
    }
}
