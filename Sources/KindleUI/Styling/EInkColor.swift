import Foundation

/// 16-shade hardware E-Ink grayscale color enumeration (`Y0`..`Y15`) tailored for Kindle displays.
///
/// Because `EInkColor` is a finite 16-case enum corresponding to the 16 native 4-bit E-Ink / Cairo X11
/// grayscale levels (`0x00, 0x11, 0x22, ..., 0xEE, 0xFF`), it is impossible to construct an invalid
/// intermediate gray value that would dither or split across 4-bit nibble boundaries.
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

    /// 8-bit grayscale value (`0x00` = pure black ink, `0xFF` = paper white), guaranteed to be `0x11 * shadeIndex`.
    public var grayLevel: UInt8 {
        rawValue
    }

    /// 4-bit E-Ink shade index (`0...15`).
    public var shadeIndex: Int {
        Int(rawValue / 17)
    }

    /// Quantizes any 8-bit gray value into the nearest valid 16-level hardware `EInkColor`.
    public init(grayLevel: UInt8) {
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
        String(format: "#%02X%02X%02X", grayLevel, grayLevel, grayLevel)
    }
}



extension EInkColor {
    public static let white: EInkColor = .paperWhite
    public static func gray4Bit(_ shade: Int) -> EInkColor {
        .eInkShade(shade)
    }
}
