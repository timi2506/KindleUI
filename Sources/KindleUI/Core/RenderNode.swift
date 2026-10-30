import Foundation

/// Visual and layout modifiers attached to a `RenderNode`.
public struct ViewStyle: @unchecked Sendable {
    public var font: KindleFont?
    public var foregroundColor: EInkColor?
    public var backgroundColor: EInkColor?
    public var borderColor: EInkColor?
    public var borderWidth: Int = 0
    public var cornerRadius: Int?
    public var unevenCorners: (topLeading: Int, topTrailing: Int, bottomTrailing: Int, bottomLeading: Int)? = nil
    public var isEllipse: Bool = false
    public var shadow: KindleShadow?
    public var contentPadding: EdgeInsets?
    public var padding: EdgeInsets?
    public var width: Int?
    public var height: Int?
    public var expand: Bool = false
    public var fill: Bool = true
    public var expandHorizontally: Bool? = nil
    public var expandVertically: Bool? = nil
    public var fillHorizontally: Bool? = nil
    public var fillVertically: Bool? = nil
    public var homogeneous: Bool = false
    public var isDisabled: Bool = false
    public var isHidden: Bool = false
    public var isModalOverlay: Bool = false
    public var isFullScreenModal: Bool = false
    public var hasModalScrim: Bool = true
    public var opacity: Double = 1.0
    public var buttonStyle: KindleButtonStyle?
    public var controlSize: KindleControlSize?
    public var pickerStyle: KindlePickerStyle?
    public var toggleStyle: KindleToggleStyle?
    public var tabViewStyle: KindleTabViewStyle?
    public var tintColor: EInkColor?
    public var alignment: Alignment?
    public var windowConfig: KindleWindowConfig?
    public var colorScheme: KindleColorScheme?
    public var refreshPolicy: EInkRefreshPolicy?
    public var navigationTitle: String?
    public var toolbarNodes: [RenderNode] = []
    public var pangoMarkup: String?
    public var explicitID: AnyHashable?
    public var onSubmitHandler: (() -> Void)?
    public var onAppear: (() -> Void)?
    public var onDisappear: (() -> Void)?
    public var onTapGesture: (() -> Void)?
    public var onLongPressGesture: (() -> Void)?
    public var longPressDurationMs: Int = 500
    public var onSwipeLeft: (() -> Void)?
    public var onSwipeRight: (() -> Void)?
    public var onSwipeUp: (() -> Void)?
    public var onSwipeDown: (() -> Void)?
    public var swipeThresholdPx: Int = 40
    public var onDragChanged: ((Int, Int, Int, Int) -> Void)?
    public var onDragEnded: ((Int, Int, Int, Int) -> Void)?

    public var hasGestures: Bool {
        onTapGesture != nil || onLongPressGesture != nil ||
        onSwipeLeft != nil || onSwipeRight != nil ||
        onSwipeUp != nil || onSwipeDown != nil ||
        onDragChanged != nil || onDragEnded != nil
    }

    public init() {}

    /// Moves any pending outer `padding` into `contentPadding` (inside the background/border box)
    /// so `.padding(16).background(...).cornerRadius(12).padding(.horizontal, 16)` matches SwiftUI modifier order.
    public mutating func latchPaddingIntoContent() {
        guard let p = padding else { return }
        var inner = contentPadding ?? EdgeInsets()
        inner.top += p.top
        inner.leading += p.leading
        inner.bottom += p.bottom
        inner.trailing += p.trailing
        contentPadding = inner
        padding = nil
    }
}

/// Intermediate node representation of a KindleUI view hierarchy.
public indirect enum RenderNode: @unchecked Sendable {
    case empty
    case group([RenderNode])
    case vstack(alignment: HorizontalAlignment, spacing: Int, children: [RenderNode], style: ViewStyle)
    case hstack(alignment: VerticalAlignment, spacing: Int, children: [RenderNode], style: ViewStyle)
    case zstack(alignment: Alignment, children: [RenderNode], style: ViewStyle)
    case scrollView(showsIndicators: Bool, child: RenderNode, style: ViewStyle)
    case card(title: String?, child: RenderNode, style: ViewStyle)
    case text(content: String, wrap: Bool, alignment: HorizontalAlignment, style: ViewStyle)
    case button(label: String, customChild: RenderNode?, action: () -> Void, style: ViewStyle)
    case toggle(label: String, isOn: Bool, onToggle: (Bool) -> Void, style: ViewStyle)
    case textField(placeholder: String, text: String, onTextChange: (String) -> Void, style: ViewStyle)
    case textEditor(text: String, minHeight: Int, onTextChange: (String) -> Void, style: ViewStyle)
    case slider(value: Double, range: ClosedRange<Double>, step: Double, onValueChange: (Double) -> Void, style: ViewStyle)
    case progressBar(fraction: Double, text: String?, style: ViewStyle)
    case divider(vertical: Bool, style: ViewStyle)
    case spacer(minLength: Int?, style: ViewStyle)
    case image(path: String, altText: String, style: ViewStyle)
    case icon(icon: KindleIconName, size: Int, style: ViewStyle)
    case canvas(
        buffer: KindleCanvasBuffer,
        label: String,
        onPrepare: ((Int, Int) -> Void)?,
        onPointer: ((Int, Int, Int) -> KindleRect?)?,
        style: ViewStyle
    )
    case webView(
        id: String,
        url: String,
        html: String?,
        baseURL: String?,
        zoomLevel: Double,
        minHeight: Int,
        onLoadFinished: (() -> Void)?,
        style: ViewStyle
    )

    /// Returns a copy of this node with a modified `ViewStyle`.
    public func modifyingStyle(_ transform: (inout ViewStyle) -> Void) -> RenderNode {
        switch self {
        case .empty:
            return .empty
        case .group(let nodes):
            return .group(nodes.map { $0.modifyingStyle(transform) })
        case .vstack(let align, let spacing, let children, var style):
            transform(&style)
            return .vstack(alignment: align, spacing: spacing, children: children, style: style)
        case .hstack(let align, let spacing, let children, var style):
            transform(&style)
            return .hstack(alignment: align, spacing: spacing, children: children, style: style)
        case .zstack(let align, let children, var style):
            transform(&style)
            return .zstack(alignment: align, children: children, style: style)
        case .scrollView(let ind, let child, var style):
            transform(&style)
            return .scrollView(showsIndicators: ind, child: child, style: style)
        case .card(let title, let child, var style):
            transform(&style)
            return .card(title: title, child: child, style: style)
        case .text(let content, let wrap, let align, var style):
            transform(&style)
            return .text(content: content, wrap: wrap, alignment: align, style: style)
        case .button(let label, let customChild, let action, var style):
            transform(&style)
            return .button(label: label, customChild: customChild, action: action, style: style)
        case .toggle(let label, let isOn, let onToggle, var style):
            transform(&style)
            return .toggle(label: label, isOn: isOn, onToggle: onToggle, style: style)
        case .textField(let ph, let txt, let onChange, var style):
            transform(&style)
            return .textField(placeholder: ph, text: txt, onTextChange: onChange, style: style)
        case .textEditor(let txt, let minH, let onChange, var style):
            transform(&style)
            return .textEditor(text: txt, minHeight: minH, onTextChange: onChange, style: style)
        case .slider(let val, let range, let step, let onChange, var style):
            transform(&style)
            return .slider(value: val, range: range, step: step, onValueChange: onChange, style: style)
        case .progressBar(let frac, let txt, var style):
            transform(&style)
            return .progressBar(fraction: frac, text: txt, style: style)
        case .divider(let vert, var style):
            transform(&style)
            return .divider(vertical: vert, style: style)
        case .spacer(let minLen, var style):
            transform(&style)
            return .spacer(minLength: minLen, style: style)
        case .image(let path, let alt, var style):
            transform(&style)
            return .image(path: path, altText: alt, style: style)
        case .icon(let ic, let sz, var style):
            transform(&style)
            return .icon(icon: ic, size: sz, style: style)
        case .canvas(let buf, let label, let onPrepare, let onPointer, var style):
            transform(&style)
            return .canvas(buffer: buf, label: label, onPrepare: onPrepare, onPointer: onPointer, style: style)
        case .webView(let id, let url, let html, let baseURL, let zoom, let minH, let onLoad, var style):
            transform(&style)
            return .webView(id: id, url: url, html: html, baseURL: baseURL, zoomLevel: zoom, minHeight: minH, onLoadFinished: onLoad, style: style)
        }
    }

    /// Returns the attached `ViewStyle` for this node, if any.
    public var styleSnapshot: ViewStyle? {
        switch self {
        case .vstack(_, _, _, let s),
             .hstack(_, _, _, let s),
             .zstack(_, _, let s),
             .scrollView(_, _, let s),
             .card(_, _, let s),
             .text(_, _, _, let s),
             .button(_, _, _, let s),
             .toggle(_, _, _, let s),
             .textField(_, _, _, let s),
             .textEditor(_, _, _, let s),
             .slider(_, _, _, _, let s),
             .progressBar(_, _, let s),
             .divider(_, let s),
             .spacer(_, let s),
             .image(_, _, let s),
             .icon(_, _, let s),
             .canvas(_, _, _, _, let s),
             .webView(_, _, _, _, _, _, _, let s):
            return s
        case .empty, .group:
            return nil
        }
    }

    /// Flattens `.group` and `.empty` nodes into a clean child array.
    public var flattenedChildren: [RenderNode] {
        switch self {
        case .empty:
            return []
        case .group(let items):
            return items.flatMap { $0.flattenedChildren }
        default:
            return [self]
        }
    }

    /// Extracts any `KindleWindowConfig` attached via `.kindleWindow(...)` in the tree.
    public var extractedWindowConfig: KindleWindowConfig? {
        switch self {
        case .empty:
            return nil
        case .group(let children):
            for c in children {
                if let cfg = c.extractedWindowConfig { return cfg }
            }
            return nil
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if let cfg = style.windowConfig { return cfg }
            for c in children {
                if let cfg = c.extractedWindowConfig { return cfg }
            }
            return nil
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.windowConfig ?? child.extractedWindowConfig
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return style.windowConfig
        }
    }

    /// Extracts any `KindleColorScheme` attached via `.preferredColorScheme(...)` in the tree.
    public var extractedColorScheme: KindleColorScheme? {
        switch self {
        case .empty:
            return nil
        case .group(let children):
            for c in children {
                if let s = c.extractedColorScheme { return s }
            }
            return nil
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if let s = style.colorScheme { return s }
            for c in children {
                if let s = c.extractedColorScheme { return s }
            }
            return nil
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.colorScheme ?? child.extractedColorScheme
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return style.colorScheme
        }
    }

    /// Extracts any `EInkRefreshPolicy` attached via `.einkRefreshPolicy(...)` in the tree.
    public var extractedRefreshPolicy: EInkRefreshPolicy? {
        switch self {
        case .empty:
            return nil
        case .group(let children):
            for c in children {
                if let p = c.extractedRefreshPolicy { return p }
            }
            return nil
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if let p = style.refreshPolicy { return p }
            for c in children {
                if let p = c.extractedRefreshPolicy { return p }
            }
            return nil
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.refreshPolicy ?? child.extractedRefreshPolicy
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return style.refreshPolicy
        }
    }

    /// Extracts any navigation title attached via `.navigationTitle(...)` in the tree.
    public var extractedNavigationTitle: String? {
        switch self {
        case .empty:
            return nil
        case .group(let children):
            for c in children {
                if let t = c.extractedNavigationTitle { return t }
            }
            return nil
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if let t = style.navigationTitle { return t }
            for c in children {
                if let t = c.extractedNavigationTitle { return t }
            }
            return nil
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.navigationTitle ?? child.extractedNavigationTitle
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return style.navigationTitle
        }
    }

    /// Extracts any toolbar items attached via `.toolbar { ... }` in the tree.
    public var extractedToolbarNodes: [RenderNode] {
        switch self {
        case .empty:
            return []
        case .group(let children):
            return children.flatMap { $0.extractedToolbarNodes }
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if !style.toolbarNodes.isEmpty { return style.toolbarNodes }
            for c in children {
                let nodes = c.extractedToolbarNodes
                if !nodes.isEmpty { return nodes }
            }
            return []
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return !style.toolbarNodes.isEmpty ? style.toolbarNodes : child.extractedToolbarNodes
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return style.toolbarNodes
        }
    }
}
