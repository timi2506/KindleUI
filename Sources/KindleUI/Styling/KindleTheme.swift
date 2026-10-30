import Foundation

// MARK: - E-Ink Adaptive Theme (Light / Dark Night Mode)

/// Provides adaptive 16-level E-Ink grayscale colors for `.light` (standard paper) and `.dark` (Night Mode).
public struct KindleTheme: Sendable, Equatable {
    public let scheme: KindleColorScheme
    public let background: EInkColor
    public let foreground: EInkColor
    public let cardBackground: EInkColor
    public let panelBackground: EInkColor
    public let mutedForeground: EInkColor
    public let border: EInkColor
    public let subtleBorder: EInkColor
    public let shadowColor: EInkColor

    public static let light = KindleTheme(
        scheme: .light,
        background: .paperWhite,
        foreground: .black,
        cardBackground: .paperWhite,
        panelBackground: .lightGray,
        mutedForeground: .dimGray,
        border: .black,
        subtleBorder: .silver,
        shadowColor: .black
    )

    public static let dark = KindleTheme(
        scheme: .dark,
        background: .black,
        foreground: .paperWhite,
        cardBackground: .shade1,
        panelBackground: .charcoal,
        mutedForeground: .shade11,
        border: .paperWhite,
        subtleBorder: .darkGray,
        shadowColor: .dimGray
    )

    /// Returns the active theme for the current render pass.
    public static var current: KindleTheme {
        KindleStateRegistry.shared.colorScheme == .dark ? .dark : .light
    }
}



// MARK: - Theme & E-Ink Refresh Modifiers

extension View {
    /// Sets the preferred E-Ink color scheme (`.light` standard paper or `.dark` Night Mode)
    /// and automatically styles the root background and foreground colors.
    public func preferredColorScheme(_ scheme: KindleColorScheme) -> ModifiedContent<Self> {
        let theme = (scheme == .dark) ? KindleTheme.dark : KindleTheme.light
        return ModifiedContent(content: self) { style in
            style.colorScheme = scheme
            if style.backgroundColor == nil {
                style.backgroundColor = theme.background
            }
            if style.foregroundColor == nil {
                style.foregroundColor = theme.foreground
            }
        }
    }

    /// Configures the automatic E-Ink display refresh policy for this view hierarchy.
    public func einkRefreshPolicy(_ policy: EInkRefreshPolicy) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.refreshPolicy = policy
        }
    }
}
