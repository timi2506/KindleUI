import Foundation

/// A control that initiates an action on tap, rendered with crisp Cairo E-Ink styling.
public struct Button<Label: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let titleText: String
    private let customLabel: Label?
    private let role: KindleButtonStyle?
    private let action: () -> Void

    public init(role: KindleButtonStyle? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.titleText = ""
        self.customLabel = label()
        self.role = role
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        if let customLabel = customLabel {
            let childNode = customLabel.buildRenderTree()
            if case .text(let str, _, _, var textStyle) = childNode {
                if let role = role, textStyle.buttonStyle == nil {
                    textStyle.buttonStyle = role
                }
                return .button(label: str, customChild: nil, action: action, style: textStyle)
            }
            var style = ViewStyle()
            style.buttonStyle = role
            if let childStyle = childNode.styleSnapshot {
                if let expH = childStyle.expandHorizontally { style.expandHorizontally = expH }
                if let fillH = childStyle.fillHorizontally { style.fillHorizontally = fillH; style.fill = fillH }
                if let expV = childStyle.expandVertically { style.expandVertically = expV }
                if let fillV = childStyle.fillVertically { style.fillVertically = fillV }
                if childStyle.expand { style.expand = true; style.fill = true }
                if let w = childStyle.width { style.width = w }
                if let h = childStyle.height { style.height = h }
                if let align = childStyle.alignment { style.alignment = align }
            }
            return .button(label: titleText, customChild: childNode, action: action, style: style)
        }
        var style = ViewStyle()
        style.buttonStyle = role
        return .button(label: titleText, customChild: nil, action: action, style: style)
    }
}

extension Button where Label == Text {
    public init(_ title: String, role: KindleButtonStyle? = nil, action: @escaping () -> Void) {
        self.titleText = title
        self.customLabel = Text(title)
        self.role = role
        self.action = action
    }
}



// MARK: - EInkButton

/// A pre-styled, high-contrast E-Ink button that automatically adapts to `KindleTheme.current`.
public struct EInkButton: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let isSelected: Bool
    public let isEnabled: Bool
    public let width: Int?
    public let height: Int?
    public let fontSize: Int
    public let expandHorizontally: Bool
    public let styleRole: KindleButtonStyle
    private let action: () -> Void

    public init(
        _ title: String,
        role: KindleButtonStyle = .automatic,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        width: Int? = nil,
        height: Int? = nil,
        fontSize: Int = 18,
        expand: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.styleRole = role
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.expandHorizontally = expand
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        let effectiveRole: KindleButtonStyle = isSelected ? .borderedProminent : styleRole
        var node = Button(title, action: action)
            .font(.system(size: fontSize, weight: .bold))
            .buttonStyle(effectiveRole)
            .disabled(!isEnabled)
            .frame(width: width, height: height)
            .buildRenderTree()
        if expandHorizontally {
            node = node.modifyingStyle { style in
                style.expand = true
                style.fill = true
            }
        }
        return node
    }
}



/// A control for navigating to a URL.
public struct Link<LabelView: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let destination: URL
    private let titleText: String
    private let labelView: LabelView?

    public init(_ titleKey: String, destination: URL) where LabelView == EmptyView {
        self.titleText = titleKey
        self.destination = destination
        self.labelView = nil
    }

    public init(destination: URL, @ViewBuilder label: () -> LabelView) {
        self.titleText = destination.absoluteString
        self.destination = destination
        self.labelView = label()
    }

    public func _makeNode() -> RenderNode {
        let targetURL = destination
        let envOpenURL = KindleStateRegistry.shared.currentEnvironment.openURL

        return Button {
            envOpenURL(targetURL)
        } label: {
            if let labelView = labelView {
                labelView
            } else {
                Text(titleText)
                    .underline()
                    .font(.headline)
            }
        }
        .buttonStyle(.plain)
        .buildRenderTree()
    }
}
