import Foundation

/// Color scheme for E-Ink displays (`.light` standard paper or `.dark` inverted Night Mode).
public enum KindleColorScheme: String, CaseIterable, Sendable {
    case light
    case dark
}

/// SwiftUI-style button appearance roles for E-Ink displays.
public enum KindleButtonStyle: Sendable, Equatable {
    case automatic
    case bordered
    case unbordered
    case borderless
    case borderedProminent
    case capsule
    case card
    case plain
}

/// SwiftUI-style control sizing tiers.
public enum KindleControlSize: Sendable, Equatable {
    case mini
    case small
    case regular
    case large
    case extraLarge

    public var defaultPadding: EdgeInsets {
        switch self {
        case .mini:       return EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        case .small:      return EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        case .regular:    return EdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
        case .large:      return EdgeInsets(top: 16, leading: 30, bottom: 16, trailing: 30)
        case .extraLarge: return EdgeInsets(top: 20, leading: 38, bottom: 20, trailing: 38)
        }
    }

    public var defaultFontSize: Int {
        switch self {
        case .mini:       return 11
        case .small:      return 12
        case .regular:    return 13
        case .large:      return 15
        case .extraLarge: return 17
        }
    }
}

/// SwiftUI-style segmented picker presentation styles.
public enum KindlePickerStyle: Sendable, Equatable {
    case segmented
    case pills
    case cards
}

/// SwiftUI-style toggle appearance roles.
public enum KindleToggleStyle: Sendable, Equatable {
    case `switch`
    case checkbox
    case button
}

/// SwiftUI-style tab bar presentation styles.
public enum KindleTabViewStyle: Sendable, Equatable {
    case bottomBar
    case segmented
}

/// Crisp E-Ink offset shadow definition.
public struct KindleShadow: Sendable, Equatable {
    public var color: EInkColor
    public var radius: Int
    public var x: Int
    public var y: Int

    public init(color: EInkColor = .black, radius: Int = 0, x: Int = 3, y: Int = 3) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}



// MARK: - 16. Custom Style Protocols, GroupBox, Link, PasteButton & RenameButton

/// The properties of a button instance passed to `CustomButtonStyle.makeBody(configuration:)`.
public struct ButtonStyleConfiguration {
    public let label: AnyView
    public let isPressed: Bool

    public init(label: AnyView, isPressed: Bool = false) {
        self.label = label
        self.isPressed = isPressed
    }
}

/// A type that applies custom interaction behavior and a custom appearance to all buttons within a view hierarchy.
public protocol CustomButtonStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: ButtonStyleConfiguration) -> Self.Body
}

/// The properties of a toggle instance passed to `CustomToggleStyle.makeBody(configuration:)`.
public struct ToggleStyleConfiguration {
    public let label: AnyView
    public let isOn: Binding<Bool>

    public init(label: AnyView, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }
}

/// A type that applies standard interaction behavior and a custom appearance to all toggles within a view hierarchy.
public protocol CustomToggleStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: ToggleStyleConfiguration) -> Self.Body
}

extension View {
    /// Sets a custom `CustomButtonStyle` on this view.
    public func buttonStyle<S: CustomButtonStyle>(_ style: S) -> some View {
        style.makeBody(configuration: ButtonStyleConfiguration(label: AnyView(self)))
    }

    /// Sets a custom `CustomToggleStyle` on this view.
    public func toggleStyle<S: CustomToggleStyle>(_ style: S, isOn: Binding<Bool>) -> some View {
        style.makeBody(configuration: ToggleStyleConfiguration(label: AnyView(self), isOn: isOn))
    }
}
