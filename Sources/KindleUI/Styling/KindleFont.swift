import Foundation

/// Typography definitions mapped to Kindle Pango/GTK2 fonts (e.g., Bookerly, Amazon Ember, Futura, Caecilia, Sans, Monospace).
public struct KindleFont: Sendable, Equatable {
    public enum Weight: Sendable, Equatable {
        case regular
        case medium
        case semibold
        case bold
        case heavy

        public var isBold: Bool {
            switch self {
            case .regular: return false
            case .medium, .semibold, .bold, .heavy: return true
            }
        }
    }

    public enum Design: Sendable, Equatable {
        case `default`
        case serif
        case rounded
        case monospaced

        public var pangoFamily: String {
            switch self {
            case .default, .rounded: return "Sans"
            case .serif: return "Serif"
            case .monospaced: return "Monospace"
            }
        }
    }

    public var family: String
    public var sizePoints: Int
    public var isBold: Bool
    public var isItalic: Bool

    public init(family: String = "Sans", sizePoints: Int = 13, isBold: Bool = false, isItalic: Bool = false) {
        self.family = family
        self.sizePoints = sizePoints
        self.isBold = isBold
        self.isItalic = isItalic
    }

    public static let largeTitle  = KindleFont(family: "Serif", sizePoints: 26, isBold: true)
    public static let title       = KindleFont(family: "Serif", sizePoints: 20, isBold: true)
    public static let title2      = KindleFont(family: "Sans", sizePoints: 17, isBold: true)
    public static let title3      = KindleFont(family: "Sans", sizePoints: 15, isBold: true)
    public static let headline    = KindleFont(family: "Sans", sizePoints: 14, isBold: true)
    public static let subheadline = KindleFont(family: "Sans", sizePoints: 12, isBold: false, isItalic: true)
    public static let body        = KindleFont(family: "Sans", sizePoints: 13, isBold: false)
    public static let callout     = KindleFont(family: "Sans", sizePoints: 12, isBold: false)
    public static let footnote    = KindleFont(family: "Sans", sizePoints: 11, isBold: false)
    public static let caption     = KindleFont(family: "Sans", sizePoints: 10, isBold: false)
    public static let monospaced  = KindleFont(family: "Monospace", sizePoints: 12, isBold: true)

    public static func system(
        size: Int,
        weight: Weight = .regular,
        design: Design = .default
    ) -> KindleFont {
        KindleFont(family: design.pangoFamily, sizePoints: size, isBold: weight.isBold, isItalic: false)
    }

    public static func bookerly(size: Int = 14, bold: Bool = false, italic: Bool = false) -> KindleFont {
        KindleFont(family: "Bookerly, Serif", sizePoints: size, isBold: bold, isItalic: italic)
    }

    public static func custom(_ family: String, size: Int, bold: Bool = false, italic: Bool = false) -> KindleFont {
        KindleFont(family: family, sizePoints: size, isBold: bold, isItalic: italic)
    }

    public func bold(_ active: Bool = true) -> KindleFont {
        var copy = self
        copy.isBold = active
        return copy
    }

    public func italic(_ active: Bool = true) -> KindleFont {
        var copy = self
        copy.isItalic = active
        return copy
    }

    public func weight(_ weight: Weight) -> KindleFont {
        var copy = self
        copy.isBold = weight.isBold
        return copy
    }

    public func monospacedDigit() -> KindleFont {
        var copy = self
        copy.family = "Monospace"
        return copy
    }

    /// Pango font description string used by GTK+-2.0 (e.g. `"Serif Bold 18"`).
    public var pangoDescription: String {
        var parts = [family]
        if isBold { parts.append("Bold") }
        if isItalic { parts.append("Italic") }
        parts.append("\(sizePoints)")
        return parts.joined(separator: " ")
    }
}
