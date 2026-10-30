import Foundation

/// A view that displays an image from a file path on the Kindle (`gtk_image_new_from_file`).
public struct Image: View, _PrimitiveView {
    public typealias Body = Never
    public let path: String
    public let altText: String

    public init(_ path: String, altText: String = "Image") {
        self.path = path
        self.altText = altText
    }

    public func _makeNode() -> RenderNode {
        .image(path: path, altText: altText, style: ViewStyle())
    }
}



// MARK: - Vector Icon & Label

/// Renders a crisp monochrome vector icon drawn via Cairo paths on E-Ink displays.
public struct Icon: View, _PrimitiveView {
    public typealias Body = Never
    public let icon: KindleIconName
    public let size: Int

    public init(_ icon: KindleIconName, size: Int = 40) {
        self.icon = icon
        self.size = max(16, size)
    }

    public init(systemName: String, size: Int = 40) {
        self.icon = KindleIconName(systemName: systemName)
        self.size = max(16, size)
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = false
        style.fill = false
        return .icon(icon: icon, size: size, style: style)
    }
}

/// Visual presentation styles for a `Label` view.
public enum KindleLabelStyle: String, CaseIterable, Sendable, Equatable {
    case automatic
    case titleAndIcon
    case titleOnly
    case iconOnly
}

/// A standard label pairing a vector `Icon` with `Text` in a horizontal stack.
public struct Label: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let icon: KindleIconName
    public let iconSize: Int
    public let spacing: Int
    public var styleVariant: KindleLabelStyle = .automatic

    public init(_ title: String, icon: KindleIconName, iconSize: Int = 38, spacing: Int = 16) {
        self.title = title
        self.icon = icon
        self.iconSize = iconSize
        self.spacing = spacing
    }

    public init(_ title: String, systemImage: String, iconSize: Int = 38, spacing: Int = 16) {
        self.title = title
        self.icon = KindleIconName(systemName: systemImage)
        self.iconSize = iconSize
        self.spacing = spacing
    }

    /// Sets the style for this `Label` (`.titleAndIcon`, `.titleOnly`, or `.iconOnly`).
    public func labelStyle(_ style: KindleLabelStyle) -> Label {
        var copy = self
        copy.styleVariant = style
        return copy
    }

    public func _makeNode() -> RenderNode {
        switch styleVariant {
        case .titleOnly:
            return Text(title)
                .lineLimit(1)
                .expand(false, fill: false)
                .buildRenderTree()
        case .iconOnly:
            return Icon(icon, size: iconSize)
                .expand(false, fill: false)
                .buildRenderTree()
        case .automatic, .titleAndIcon:
            return HStack(alignment: .center, spacing: spacing) {
                Icon(icon, size: iconSize)
                Text(title).lineLimit(1)
            }
            .expand(false, fill: false)
            .buildRenderTree()
        }
    }
}



// MARK: - LabeledContent & Badge

/// A view that pairs a leading label with a trailing value or custom control view,
/// ideal for Kindle settings rows and telemetry tables.
public struct LabeledContent<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    private let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let contentNode = content.buildRenderTree()
        if case .textField = contentNode {
            return HStack(alignment: .center, spacing: 20) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(theme.foreground)
                    .frame(width: 220)
                AnyView(node: contentNode)
            }
            .buildRenderTree()
        }
        return HStack(alignment: .center, spacing: 20) {
            Text(title)
                .font(.body)
                .foregroundColor(theme.mutedForeground)
            Spacer()
            AnyView(node: contentNode)
        }
        .buildRenderTree()
    }
}

extension LabeledContent where Content == Text {
    /// Creates a `LabeledContent` row displaying a string value in bold monospace type.
    public init(_ title: String, value: String) {
        self.title = title
        self.content = Text(value)
            .font(.monospaced)
            .multilineTextAlignment(.trailing)
    }
}

/// A compact pill badge for status labels, counts, and tags.
public struct Badge: View, _PrimitiveView {
    public typealias Body = Never
    public let text: String
    public let prominent: Bool

    public init(_ text: String, prominent: Bool = false) {
        self.text = text
        self.prominent = prominent
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18))
            .background(prominent ? theme.foreground : theme.panelBackground, cornerRadius: 999)
            .foregroundColor(prominent ? theme.background : theme.foreground)
            .border(prominent ? theme.border : theme.subtleBorder, width: 1, cornerRadius: 999)
            .expand(false, fill: false)
            .buildRenderTree()
    }
}
