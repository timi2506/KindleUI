import Foundation

/// Built-in monochrome vector icons drawn via Cairo paths on E-Ink displays.
public enum KindleIconName: Int32, CaseIterable, Sendable, Equatable {
    case wifi = 0
    case battery = 1
    case sun = 2
    case moon = 3
    case refresh = 4
    case chevronLeft = 5
    case chevronRight = 6
    case chevronDown = 7
    case chevronUp = 8
    case search = 9
    case bookmark = 10
    case check = 11
    case warning = 12
    case info = 13
    case book = 14
    case globe = 15
    case cloud = 16
    case gear = 17
    case sliders = 18
    case plus = 19
    case minus = 20
    case close = 21
    case star = 22
    case bolt = 23
    case pencil = 24
    case share = 25
    case folder = 26
    case document = 27
    case calendar = 28
    case bookmarkFill = 29
    case user = 30
    case trash = 31
    case server = 32
    case link = 33
    case download = 34
    case upload = 35
    case lock = 36
    case clock = 37
    case bug = 38

    public init(systemName: String) {
        switch systemName.lowercased() {
        case "wifi", "antenna.radiowaves.left.and.right": self = .wifi
        case "battery", "battery.100", "battery.75": self = .battery
        case "sun", "sun.max", "sun.max.fill": self = .sun
        case "moon", "moon.fill", "moon.stars": self = .moon
        case "refresh", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "clock.arrow.circlepath", "arrow.uturn.backward", "arrow.uturn.backward.circle.fill": self = .refresh
        case "chevron.left", "arrow.left", "back": self = .chevronLeft
        case "chevron.right", "arrow.right", "forward": self = .chevronRight
        case "chevron.down": self = .chevronDown
        case "chevron.up": self = .chevronUp
        case "search", "magnifyingglass": self = .search
        case "bookmark": self = .bookmark
        case "bookmark.fill": self = .bookmarkFill
        case "check", "checkmark", "checkmark.circle", "checkmark.circle.fill", "checkmark.seal.fill": self = .check
        case "warning", "exclamationmark.triangle", "exclamationmark.triangle.fill": self = .warning
        case "info", "info.circle", "info.circle.fill": self = .info
        case "book", "book.fill", "text.book.closed": self = .book
        case "globe", "network", "safari", "safari.fill": self = .globe
        case "cloud", "cloud.sun", "cloud.fill": self = .cloud
        case "gear", "gearshape", "gearshape.fill", "settings": self = .gear
        case "sliders", "slider.horizontal.3", "paintpalette.fill": self = .sliders
        case "plus", "plus.circle", "doc.badge.plus", "folder.badge.plus": self = .plus
        case "minus", "minus.circle": self = .minus
        case "close", "xmark", "xmark.circle", "xmark.circle.fill": self = .close
        case "trash", "trash.fill", "trash.slash.fill", "delete", "delete.left": self = .trash
        case "star", "star.fill", "star.slash", "sparkles", "sparkles.rectangle.stack.fill", "wand.and.stars": self = .star
        case "bolt", "bolt.fill", "power": self = .bolt
        case "pencil", "pencil.line", "pencil.tip", "paintbrush", "paintbrush.pointed", "scribble", "square.and.pencil": self = .pencil
        case "share", "square.and.arrow.up", "rectangle.portrait.and.arrow.right": self = .share
        case "folder", "folder.fill": self = .folder
        case "doc", "doc.fill", "doc.text", "document", "doc.on.doc": self = .document
        case "calendar": self = .calendar
        case "clock", "clock.fill", "timer": self = .clock
        case "person", "person.fill", "person.circle", "person.circle.fill", "person.crop.circle", "person.crop.circle.fill", "person.2", "person.2.fill", "person.2.slash", "person.3", "person.3.fill", "person.badge.key.fill": self = .user
        case "server", "server.rack", "externaldrive", "externaldrive.fill", "building.2.fill", "scalemass.fill": self = .server
        case "link", "link.badge.plus": self = .link
        case "arrow.down", "arrow.down.circle", "arrow.down.circle.fill", "tray.and.arrow.down", "download": self = .download
        case "arrow.up", "arrow.up.circle", "arrow.up.circle.fill", "arrow.up.forward", "upload": self = .upload
        case "lock", "lock.fill", "lock.open", "lock.open.fill", "key", "key.fill": self = .lock
        case "ant", "ant.fill", "ladybug", "ladybug.fill", "bug": self = .bug
        default: self = .info
        }
    }

    public var title: String {
        switch self {
        case .wifi: return "wifi"
        case .battery: return "battery"
        case .sun: return "sun"
        case .moon: return "moon"
        case .refresh: return "refresh"
        case .chevronLeft: return "chevronLeft"
        case .chevronRight: return "chevronRight"
        case .chevronDown: return "chevronDown"
        case .chevronUp: return "chevronUp"
        case .search: return "search"
        case .bookmark: return "bookmark"
        case .check: return "check"
        case .warning: return "warning"
        case .info: return "info"
        case .book: return "book"
        case .globe: return "globe"
        case .cloud: return "cloud"
        case .gear: return "gear"
        case .sliders: return "sliders"
        case .plus: return "plus"
        case .minus: return "minus"
        case .close: return "close"
        case .star: return "star"
        case .bolt: return "bolt"
        case .pencil: return "pencil"
        case .share: return "share"
        case .folder: return "folder"
        case .document: return "document"
        case .calendar: return "calendar"
        case .bookmarkFill: return "bookmarkFill"
        case .user: return "user"
        case .trash: return "trash"
        case .server: return "server"
        case .link: return "link"
        case .download: return "download"
        case .upload: return "upload"
        case .lock: return "lock"
        case .clock: return "clock"
        case .bug: return "bug"
        }
    }

    public var asciiGlyph: String {
        switch self {
        case .wifi: return "((o))"
        case .battery: return "[###]"
        case .sun: return "(*)"
        case .moon: return "(C)"
        case .refresh: return "[R]"
        case .chevronLeft: return "<"
        case .chevronRight: return ">"
        case .chevronDown: return "v"
        case .chevronUp: return "^"
        case .search: return "[?]"
        case .bookmark: return "[B]"
        case .bookmarkFill: return "[*B]"
        case .check: return "[v]"
        case .warning: return "[!]"
        case .info: return "(i)"
        case .book: return "[=]"
        case .globe: return "(O)"
        case .cloud: return "(~)"
        case .gear: return "[*]"
        case .sliders: return "=-="
        case .plus: return "+"
        case .minus: return "-"
        case .close: return "x"
        case .star: return "*"
        case .bolt: return "/"
        case .pencil: return "[/]"
        case .share: return "[^]"
        case .folder: return "[D]"
        case .document: return "[F]"
        case .calendar: return "[#]"
        case .user: return "[U]"
        case .trash: return "[T]"
        case .server: return "[S]"
        case .link: return "[L]"
        case .download: return "[v]"
        case .upload: return "[^]"
        case .lock: return "[K]"
        case .clock: return "(t)"
        case .bug: return "[B]"
        }
    }
}
