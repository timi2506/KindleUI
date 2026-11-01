import Foundation

/// 16-shade hardware E-Ink grayscale color enumeration (`Y0`..`Y15`) plus Kaleido 3 Colorsoft
/// semantic palette tokens tailored for Kindle monochrome and Colorsoft displays.
///
/// - The 16 monochrome shades (`shade0`..`shade15`) have `rawValue = 0x00, 0x11, ..., 0xFF`
///   (where high nibble == low nibble).
/// - Semantic Colorsoft palette tokens encode their exact 4-bit monochrome fallback shade index
///   in the high nibble (`rawValue >> 4`) and their Kaleido 3 CFA palette index in the low nibble.
///   On Colorsoft displays (`KindleDevice.shared.isColorDisplay == true`), `CKindleGTK` and
///   `KindlePreviewServer` render the full RGB color; on monochrome Kindles, they automatically
///   render the exact 4-bit monochrome fallback shade with zero dithering.
public enum EInkColor: UInt8, CaseIterable, Sendable, Equatable {
    case shade0  = 0x00 // Y0  — Pure Black Ink
    case shade1  = 0x11 // Y1
    case shade2  = 0x22 // Y2  — Charcoal
    case shade3  = 0x33 // Y3
    case shade4  = 0x44 // Y4  — Dark Gray
    case shade5  = 0x55 // Y5  — Dim Gray
    case shade6  = 0x66 // Y6
    case shade7  = 0x77 // Y7  — Mid Gray
    case shade8  = 0x88 // Y8
    case shade9  = 0x99 // Y9  — Medium Gray
    case shade10 = 0xAA // Y10
    case shade11 = 0xBB // Y11
    case shade12 = 0xCC // Y12 — Silver
    case shade13 = 0xDD // Y13
    case shade14 = 0xEE // Y14 — Light Gray Panel
    case shade15 = 0xFF // Y15 — Paper White

    // MARK: - Kaleido 3 Colorsoft Semantic Palette Tokens (High nibble = 4-bit monochrome fallback shade)

    case navyAccent    = 0x21 // #1B3B6F — Deep Editorial Navy (mono fallback: shade2)
    case royalBlue     = 0x32 // #1D4ED8 — Wikipedia Link / Active Accent Blue (mono fallback: shade3)
    case tealAccent    = 0x43 // #0F6272 — Wiktionary / Linguistic Teal (mono fallback: shade4)
    case forestGreen   = 0x34 // #1E6B45 — Offline / Saved / Verified Green (mono fallback: shade3)
    case crimsonRed    = 0x35 // #A62626 — Destructive / Alert Crimson (mono fallback: shade3)
    case amberGold     = 0x46 // #9A5B13 — Featured / Bookmark Warm Ochre-Gold (mono fallback: shade4)
    case plumPurple    = 0x37 // #5B3278 — Reference / Category Plum (mono fallback: shade3)
    case slateMuted    = 0x58 // #47586E — Editorial Muted Cool Slate (mono fallback: shade5)
    case blueBorder    = 0xB9 // #93B4DC — Subtle Blue Card/Infobox Border (mono fallback: shade11)
    case amberBorder   = 0xBA // #D8B478 — Warm Ochre/Amber Card Border (mono fallback: shade11)
    case softBlueTint  = 0xEB // #E4EEF9 — Soft Ice-Blue Panel / Infobox Fill (mono fallback: shade14)
    case softTealTint  = 0xEC // #E2F2F4 — Soft Aqua/Teal Panel Fill (mono fallback: shade14)
    case softGreenTint = 0xED // #E3F3EA — Soft Mint/Sage Saved Pill Fill (mono fallback: shade14)
    case softAmberTint = 0xDE // #F7ECD5 — Warm Cream / Featured Banner Fill (mono fallback: shade13)
    case softRoseTint  = 0xEF // #F9E6E6 — Soft Rose Warning / Error Fill (mono fallback: shade14)
    case darkNavyCard  = 0x1A // #13233A — Dark Mode Navy Card / Header Fill (mono fallback: shade1)

    /// Encoded byte value passed to `CKindleGTK` (`0x00`..`0xFF` for monochrome shades, or semantic palette code).
    public var grayLevel: UInt8 {
        rawValue
    }

    /// 4-bit E-Ink monochrome fallback shade index (`0...15`).
    public var shadeIndex: Int {
        Int(rawValue >> 4)
    }

    /// 8-bit monochrome fallback gray level (`0x00, 0x11, ..., 0xFF`).
    public var monochromeGrayLevel: UInt8 {
        UInt8(shadeIndex * 17)
    }

    /// Returns `true` if this color is a Kaleido 3 Colorsoft semantic palette token.
    public var isColorToken: Bool {
        (rawValue >> 4) != (rawValue & 0x0F)
    }

    /// Returns the Kaleido 3 Colorsoft RGB components for this color.
    public var colorRGB: (r: UInt8, g: UInt8, b: UInt8) {
        switch self {
        case .navyAccent:    return (0x1B, 0x3B, 0x6F)
        case .royalBlue:     return (0x1D, 0x4E, 0xD8)
        case .tealAccent:    return (0x0F, 0x62, 0x72)
        case .forestGreen:   return (0x1E, 0x6B, 0x45)
        case .crimsonRed:    return (0xA6, 0x26, 0x26)
        case .amberGold:     return (0x9A, 0x5B, 0x13)
        case .plumPurple:    return (0x5B, 0x32, 0x78)
        case .slateMuted:    return (0x47, 0x58, 0x6E)
        case .blueBorder:    return (0x93, 0xB4, 0xDC)
        case .amberBorder:   return (0xD8, 0xB4, 0x78)
        case .softBlueTint:  return (0xE4, 0xEE, 0xF9)
        case .softTealTint:  return (0xE2, 0xF2, 0xF4)
        case .softGreenTint: return (0xE3, 0xF3, 0xEA)
        case .softAmberTint: return (0xF7, 0xEC, 0xD5)
        case .softRoseTint:  return (0xF9, 0xE6, 0xE6)
        case .darkNavyCard:  return (0x13, 0x23, 0x3A)
        default:
            let g = monochromeGrayLevel
            return (g, g, g)
        }
    }

    /// Returns the active display RGB tuple (full RGB on Colorsoft, or 4-bit quantized gray on monochrome E-Ink).
    public var rgb: (r: UInt8, g: UInt8, b: UInt8) {
        if isColorToken && KindleDevice.shared.isColorDisplay {
            return colorRGB
        }
        let g = monochromeGrayLevel
        return (g, g, g)
    }

    /// Quantizes any 8-bit gray value into the nearest valid 16-level hardware `EInkColor`.
    public init(grayLevel: UInt8) {
        if let exact = EInkColor(rawValue: grayLevel), exact.isColorToken {
            self = exact
            return
        }
        if grayLevel >= 240 && grayLevel < 252 {
            self = .shade14
        } else if grayLevel > 3 && grayLevel <= 15 {
            self = .shade1
        } else {
            let idx = max(0, min(15, (Int(grayLevel) + 8) / 17))
            self = EInkColor(rawValue: UInt8(idx * 17)) ?? .shade15
        }
    }

    /// Returns one of the 16 native Kindle E-Ink grayscale levels (`0...15`).
    public static func eInkShade(_ shade: Int) -> EInkColor {
        let clamped = max(0, min(15, shade))
        return EInkColor(rawValue: UInt8(clamped * 17)) ?? .shade15
    }

    public static let black       = EInkColor.shade0
    public static let charcoal    = EInkColor.shade2
    public static let darkGray    = EInkColor.shade4
    public static let dimGray     = EInkColor.shade5
    public static let gray        = EInkColor.shade7
    public static let mediumGray  = EInkColor.shade9
    public static let silver      = EInkColor.shade12
    public static let lightGray   = EInkColor.shade14
    public static let paperWhite  = EInkColor.shade15

    public var hexString: String {
        let c = rgb
        return String(format: "#%02X%02X%02X", c.r, c.g, c.b)
    }

    public var colorHexString: String {
        let c = colorRGB
        return String(format: "#%02X%02X%02X", c.r, c.g, c.b)
    }
}



extension EInkColor {
    public static let white: EInkColor = .paperWhite
    public static func gray4Bit(_ shade: Int) -> EInkColor {
        .eInkShade(shade)
    }
}
