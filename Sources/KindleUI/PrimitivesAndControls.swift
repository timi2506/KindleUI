import Foundation

/// A view that doesn't contain any content.
public struct EmptyView: View, _PrimitiveView {
    public typealias Body = Never
    public init() {}
    public func _makeNode() -> RenderNode { .empty }
}

extension Optional: View, _PrimitiveView where Wrapped: View {
    public typealias Body = Never
    public func _makeNode() -> RenderNode {
        switch self {
        case .some(let wrapped):
            return wrapped.buildRenderTree()
        case .none:
            return .empty
        }
    }
}

/// A View created from a swift tuple of View values.
public struct TupleView<T>: View, _PrimitiveView {
    public typealias Body = Never
    internal let nodes: [RenderNode]

    public init(_ nodes: [RenderNode]) {
        self.nodes = nodes
    }

    public func _makeNode() -> RenderNode {
        .group(nodes)
    }
}

/// A type-erased view.
public struct AnyView: View, _PrimitiveView {
    public typealias Body = Never
    private let builder: () -> RenderNode

    public init<V: View>(_ view: V) {
        self.builder = { view.buildRenderTree() }
    }

    internal init(node: RenderNode) {
        self.builder = { node }
    }

    public func _makeNode() -> RenderNode {
        builder()
    }
}

/// A type that collects multiple instances of a content type into a single unit.
public struct Group<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        content.buildRenderTree()
    }
}

/// A view that arranges its subviews in a vertical line (`gtk_vbox_new`).
public struct VStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: HorizontalAlignment
    public let spacing: Int
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let children = content.buildRenderTree().flattenedChildren
        return .vstack(alignment: alignment, spacing: spacing, children: children, style: ViewStyle())
    }
}

/// A view that arranges its subviews in a horizontal line (`gtk_hbox_new`).
public struct HStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: VerticalAlignment
    public let spacing: Int
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let children = content.buildRenderTree().flattenedChildren
        return .hstack(alignment: alignment, spacing: spacing, children: children, style: ViewStyle())
    }
}

/// A view that overlays its subviews, aligning them in both axes.
public struct ZStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: Alignment
    private let content: Content

    public init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let children = content.buildRenderTree().flattenedChildren
        return .zstack(alignment: alignment, children: children, style: ViewStyle())
    }
}

/// A view that displays one or more lines of read-only text on the Kindle E-Ink display (`gtk_label_new`).
public struct Text: View, _PrimitiveView {
    public typealias Body = Never
    public let content: String
    private var wrap: Bool = true
    private var textAlignment: HorizontalAlignment = .leading
    private var style: ViewStyle = ViewStyle()

    public init(_ content: String) {
        self.content = content
    }

    public func bold(_ isActive: Bool = true) -> Text {
        var copy = self
        var f = copy.style.font ?? .body
        f.isBold = isActive
        copy.style.font = f
        return copy
    }

    public func italic(_ isActive: Bool = true) -> Text {
        var copy = self
        var f = copy.style.font ?? .body
        f.isItalic = isActive
        copy.style.font = f
        return copy
    }

    public func font(_ font: KindleFont) -> Text {
        var copy = self
        copy.style.font = font
        return copy
    }

    public func multilineTextAlignment(_ alignment: HorizontalAlignment) -> Text {
        var copy = self
        copy.textAlignment = alignment
        return copy
    }

    public func lineWrap(_ enabled: Bool) -> Text {
        var copy = self
        copy.wrap = enabled
        return copy
    }

    public func _makeNode() -> RenderNode {
        .text(content: content, wrap: wrap, alignment: textAlignment, style: style)
    }
}

/// A control that initiates an action on tap (`gtk_button_new_with_label`).
public struct Button<Label: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let titleText: String
    private let customLabel: Label?
    private let action: () -> Void

    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.titleText = ""
        self.customLabel = label()
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        if let customLabel = customLabel {
            let childNode = customLabel.buildRenderTree()
            if case .text(let str, _, _, _) = childNode {
                return .button(label: str, customChild: nil, action: action, style: ViewStyle())
            }
            return .button(label: titleText, customChild: childNode, action: action, style: ViewStyle())
        }
        return .button(label: titleText, customChild: nil, action: action, style: ViewStyle())
    }
}

extension Button where Label == Text {
    public init(_ title: String, action: @escaping () -> Void) {
        self.titleText = title
        self.customLabel = Text(title)
        self.action = action
    }
}

/// A control that toggles between on and off states (`gtk_check_button_new_with_label`).
public struct Toggle: View, _PrimitiveView {
    public typealias Body = Never
    public let label: String
    public let isOn: Binding<Bool>

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public func _makeNode() -> RenderNode {
        .toggle(
            label: label,
            isOn: isOn.wrappedValue,
            onToggle: { newValue in
                isOn.wrappedValue = newValue
            },
            style: ViewStyle()
        )
    }
}

/// A control that displays an editable text interface (`gtk_entry_new`).
///
/// Note: On Kindle dialogs, `KindleUI` can automatically set the `RKB` (Require Keyboard)
/// AwesomeWM property so the on-screen keyboard does not obscure the dialog.
public struct TextField: View, _PrimitiveView {
    public typealias Body = Never
    public let placeholder: String
    public let text: Binding<String>

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    public func _makeNode() -> RenderNode {
        .textField(
            placeholder: placeholder,
            text: text.wrappedValue,
            onTextChange: { updated in
                text.wrappedValue = updated
            },
            style: ViewStyle()
        )
    }
}

/// A control for selecting a value from a bounded linear range (`gtk_hscale_new_with_range`).
/// Ideal for Kindle frontlight intensity (`0...24`) or font size adjustments.
public struct Slider: View, _PrimitiveView {
    public typealias Body = Never
    public let value: Binding<Double>
    public let bounds: ClosedRange<Double>
    public let step: Double

    public init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0.0...1.0,
        step: Double = 0.05
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
    }

    public func _makeNode() -> RenderNode {
        .slider(
            value: value.wrappedValue,
            range: bounds,
            step: step,
            onValueChange: { updated in
                value.wrappedValue = updated
            },
            style: ViewStyle()
        )
    }
}

/// A view that shows the progress toward completion of a task (`gtk_progress_bar_new`).
public struct ProgressView: View, _PrimitiveView {
    public typealias Body = Never
    public let fraction: Double
    public let label: String?

    public init(value: Double, total: Double = 1.0, label: String? = nil) {
        let clampedTotal = max(0.0001, total)
        self.fraction = min(1.0, max(0.0, value / clampedTotal))
        self.label = label
    }

    public func _makeNode() -> RenderNode {
        .progressBar(fraction: fraction, text: label, style: ViewStyle())
    }
}

/// A visual element that can be used to separate other content (`gtk_hseparator_new` / `gtk_vseparator_new`).
public struct Divider: View, _PrimitiveView {
    public typealias Body = Never
    public let vertical: Bool

    public init(vertical: Bool = false) {
        self.vertical = vertical
    }

    public func _makeNode() -> RenderNode {
        .divider(vertical: vertical, style: ViewStyle())
    }
}

/// A flexible space that expands along the major axis of its containing stack layout.
public struct Spacer: View, _PrimitiveView {
    public typealias Body = Never
    public let minLength: Int?

    public init(minLength: Int? = nil) {
        self.minLength = minLength
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = true
        return .spacer(minLength: minLength, style: style)
    }
}

/// A scrollable view (`gtk_scrolled_window_new`).
public struct ScrollView<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let showsIndicators: Bool
    private let content: Content

    public init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = true
        return .scrollView(showsIndicators: showsIndicators, child: content.buildRenderTree(), style: style)
    }
}

/// A container that presents rows of data arranged in a single scrollable column with E-Ink dividers.
public struct List<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let rawRows = content.buildRenderTree().flattenedChildren
        var separatedRows: [RenderNode] = []
        for (idx, row) in rawRows.enumerated() {
            let paddedRow = row.modifyingStyle { s in
                if s.padding == nil {
                    s.padding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
                }
            }
            separatedRows.append(paddedRow)
            if idx + 1 < rawRows.count {
                separatedRows.append(.divider(vertical: false, style: ViewStyle()))
            }
        }
        let vbox = RenderNode.vstack(alignment: .leading, spacing: 2, children: separatedRows, style: ViewStyle())
        var scrollStyle = ViewStyle()
        scrollStyle.expand = true
        return .scrollView(showsIndicators: true, child: vbox, style: scrollStyle)
    }
}

/// A structure that computes views on demand from an underlying collection of identified data.
public struct ForEach<Data: RandomAccessCollection, Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let nodes: [RenderNode]

    public init(_ data: Data, @ViewBuilder content: (Data.Element) -> Content) {
        self.nodes = data.map { content($0).buildRenderTree() }
    }

    public func _makeNode() -> RenderNode {
        .group(nodes)
    }
}

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

/// A high-contrast E-Ink framed section or card (`gtk_frame_new`).
public struct KindleCard<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        .card(title: title, child: content.buildRenderTree(), style: ViewStyle())
    }
}
