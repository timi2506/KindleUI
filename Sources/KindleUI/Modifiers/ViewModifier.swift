import Foundation

public struct ModifiedContent<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let upstream: Content
    private let modifier: (inout ViewStyle) -> Void

    public init(content: Content, modifier: @escaping (inout ViewStyle) -> Void) {
        self.upstream = content
        self.modifier = modifier
    }

    public func _makeNode() -> RenderNode {
        upstream.buildRenderTree().modifyingStyle(modifier)
    }
}

extension View {
    /// Adds an equal padding amount to specific edges of this view.
    public func padding(_ edges: Edge = .all, _ length: Int = 12) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            var current = style.padding ?? EdgeInsets()
            if edges.contains(.top) { current.top += length }
            if edges.contains(.bottom) { current.bottom += length }
            if edges.contains(.leading) { current.leading += length }
            if edges.contains(.trailing) { current.trailing += length }
            style.padding = current
        }
    }

    /// Adds uniform padding to all edges of this view.
    public func padding(_ length: Int) -> ModifiedContent<Self> {
        padding(.all, length)
    }

    /// Adds custom edge insets padding to this view.
    public func padding(_ insets: EdgeInsets) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.padding = insets
        }
    }

    /// Positions this view within an invisible frame with the specified size constraints (`gtk_widget_set_size_request`).
    public func frame(
        width: Int? = nil,
        height: Int? = nil,
        alignment: Alignment? = nil
    ) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            if let width = width { style.width = width }
            if let height = height { style.height = height }
            if let alignment = alignment { style.alignment = alignment }
        }
    }

    /// Controls whether this view expands to fill available space in a parent `VStack` or `HStack`.
    public func expand(_ isExpanded: Bool = true, fill: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.expand = isExpanded
            style.fill = fill
        }
    }

    /// Sets the default E-Ink Pango font for text in this view.
    public func font(_ font: KindleFont) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.font = font
        }
    }

    /// Applies bold styling to text within this view.
    public func bold(_ isActive: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            var f = style.font ?? .body
            f.isBold = isActive
            style.font = f
        }
    }

    /// Applies italic styling to text within this view.
    public func italic(_ isActive: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            var f = style.font ?? .body
            f.isItalic = isActive
            style.font = f
        }
    }

    /// Sets the font weight for text within this view.
    public func fontWeight(_ weight: KindleFont.Weight) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            var f = style.font ?? .body
            f.isBold = weight.isBold
            style.font = f
        }
    }

    /// Uses a monospaced font suitable for numeric counters and telemetry.
    public func monospacedDigit() -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            let current = style.font ?? .body
            style.font = KindleFont(
                family: "Monospace",
                sizePoints: current.sizePoints,
                isBold: current.isBold,
                isItalic: current.isItalic
            )
        }
    }

    /// Sets the E-Ink grayscale foreground shade of this view.
    public func foregroundColor(_ color: EInkColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.foregroundColor = color
        }
    }

    /// Sets the E-Ink grayscale foreground style of this view (SwiftUI alias for `foregroundColor`).
    public func foregroundStyle(_ color: EInkColor) -> ModifiedContent<Self> {
        foregroundColor(color)
    }

    /// Sets the accent/tint shade for controls inside this view.
    public func tint(_ color: EInkColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.tintColor = color
        }
    }

    /// Sets the E-Ink grayscale background shade (and optional corner radius) of this view.
    public func background(_ color: EInkColor, cornerRadius: Int? = nil) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.latchPaddingIntoContent()
            style.backgroundColor = color
            if let cornerRadius = cornerRadius {
                style.cornerRadius = max(0, cornerRadius)
            }
        }
    }

    /// Clips and strokes this view with a rounded rectangle of the given corner radius.
    public func cornerRadius(_ radius: Int) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.latchPaddingIntoContent()
            style.cornerRadius = max(0, radius)
        }
    }

    /// Draws a crisp Cairo E-Ink border around this view.
    public func border(_ color: EInkColor = .black, width: Int = 2, cornerRadius: Int? = nil) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.latchPaddingIntoContent()
            style.borderColor = color
            style.borderWidth = max(1, width)
            if let cornerRadius = cornerRadius {
                style.cornerRadius = max(0, cornerRadius)
            }
        }
    }

    /// Draws a rounded border overlay around this view.
    public func overlay(cornerRadius: Int = 12, color: EInkColor = .black, lineWidth: Int = 2) -> ModifiedContent<Self> {
        border(color, width: lineWidth, cornerRadius: cornerRadius)
    }

    /// Adds a crisp E-Ink offset shadow behind this view.
    public func shadow(
        color: EInkColor = .black,
        radius: Int = 0,
        x: Int = 3,
        y: Int = 3
    ) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.latchPaddingIntoContent()
            style.shadow = KindleShadow(color: color, radius: radius, x: x, y: y)
        }
    }

    /// Sets the style for buttons within this view.
    public func buttonStyle(_ buttonStyle: KindleButtonStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.buttonStyle = buttonStyle
        }
    }

    /// Sets the size tier for controls within this view.
    public func controlSize(_ size: KindleControlSize) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.controlSize = size
        }
    }

    /// Sets the style for pickers within this view.
    public func pickerStyle(_ pickerStyle: KindlePickerStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.pickerStyle = pickerStyle
        }
    }

    /// Sets the style for toggles within this view.
    public func toggleStyle(_ toggleStyle: KindleToggleStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.toggleStyle = toggleStyle
        }
    }

    /// Sets the style for tab views within this view.
    public func tabViewStyle(_ tabViewStyle: KindleTabViewStyle) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.tabViewStyle = tabViewStyle
        }
    }

    /// Disables or enables user interaction on controls within this view.
    public func disabled(_ isDisabled: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.isDisabled = isDisabled
        }
    }

    /// Makes an `HStack` or `VStack` distribute equal widths/heights to all children.
    public func homogeneous(_ enabled: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.homogeneous = enabled
        }
    }

    /// Configures the Kindle Awesome Window Manager properties for the enclosing window.
    public func kindleWindow(_ config: KindleWindowConfig) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.windowConfig = config
        }
    }

    /// Configures the Kindle Awesome Window Manager properties for the enclosing window.
    public func kindleWindow(
        id: String,
        layer: KindleLayer = .application,
        role: KindleWindowRole = .application,
        chrome: KindleChrome = .topBar,
        orientations: KindleOrientation = []
    ) -> ModifiedContent<Self> {
        let cfg = KindleWindowConfig(
            applicationID: id,
            layer: layer,
            role: role,
            persistentChrome: chrome,
            orientations: orientations
        )
        return kindleWindow(cfg)
    }

    /// Sets the navigation bar title when this view is displayed inside a `NavigationStack`.
    public func navigationTitle(_ title: String) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.navigationTitle = title
        }
    }

    /// Hides this view conditionally while preserving view hierarchy structure.
    public func hidden(_ isHidden: Bool = true) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.isHidden = isHidden
        }
    }

    /// Adjusts the perceived E-Ink contrast/opacity (`0.0...1.0`) of this view.
    public func opacity(_ value: Double) -> ModifiedContent<Self> {
        let clamped = max(0.0, min(1.0, value))
        return ModifiedContent(content: self) { style in
            style.opacity = clamped
            if clamped <= 0.01 {
                style.isHidden = true
            }
        }
    }

    /// Adds an action to perform once when this view enters the rendered view tree.
    public func onAppear(
        id: String = #fileID + ":\(#line)",
        perform action: @escaping () -> Void
    ) -> ModifiedContent<Self> {
        KindleStateRegistry.shared.registerLifecycle(
            id: id,
            onAppear: action,
            onDisappear: nil,
            taskID: nil,
            taskAction: nil
        )
        return ModifiedContent(content: self) { style in
            style.onAppear = action
        }
    }

    /// Adds an action to perform when this view leaves the rendered view tree.
    public func onDisappear(
        id: String = #fileID + ":\(#line)",
        perform action: @escaping () -> Void
    ) -> ModifiedContent<Self> {
        KindleStateRegistry.shared.registerLifecycle(
            id: id,
            onAppear: nil,
            onDisappear: action,
            taskID: nil,
            taskAction: nil
        )
        return ModifiedContent(content: self) { style in
            style.onDisappear = action
        }
    }

    /// Runs a background/async action when this view appears or when `id` changes.
    public func task<T: Hashable>(
        id: T,
        key: String = #fileID + ":\(#line)",
        _ action: @escaping () -> Void
    ) -> ModifiedContent<Self> {
        KindleStateRegistry.shared.registerLifecycle(
            id: "task:\(key)",
            onAppear: nil,
            onDisappear: nil,
            taskID: AnyHashable(id),
            taskAction: action
        )
        return ModifiedContent(content: self) { _ in }
    }

    /// Runs a background/async action once when this view appears.
    public func task(
        key: String = #fileID + ":\(#line)",
        _ action: @escaping () -> Void
    ) -> ModifiedContent<Self> {
        task(id: key, key: key, action)
    }

    /// Adds an action to perform when the specified `Equatable` value changes across render passes.
    public func onChange<V: Equatable>(
        of value: V,
        key: String = #fileID + ":\(#line)",
        perform action: @escaping (V) -> Void
    ) -> ModifiedContent<Self> {
        KindleStateRegistry.shared.checkOnChange(key: key, value: value, action: action)
        return ModifiedContent(content: self) { _ in }
    }

    /// Attaches a tap gesture handler to any view.
    public func onTapGesture(perform action: @escaping () -> Void) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.onTapGesture = action
        }
    }

    /// Attaches a long-press gesture handler to any view.
    public func onLongPressGesture(
        minimumDuration: Double = 0.5,
        perform action: @escaping () -> Void
    ) -> ModifiedContent<Self> {
        let ms = max(150, Int(minimumDuration * 1000.0))
        return ModifiedContent(content: self) { style in
            style.longPressDurationMs = ms
            style.onLongPressGesture = action
        }
    }

    /// Attaches 4-way E-Ink swipe gesture handlers (e.g., for left/right page turning) to any view.
    public func onSwipeGesture(
        threshold: Int = 40,
        onLeft: (() -> Void)? = nil,
        onRight: (() -> Void)? = nil,
        onUp: (() -> Void)? = nil,
        onDown: (() -> Void)? = nil
    ) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.swipeThresholdPx = max(12, threshold)
            if let onLeft = onLeft { style.onSwipeLeft = onLeft }
            if let onRight = onRight { style.onSwipeRight = onRight }
            if let onUp = onUp { style.onSwipeUp = onUp }
            if let onDown = onDown { style.onSwipeDown = onDown }
        }
    }


}

extension View {
    // MARK: - Async .task(id:)

    /// Runs an asynchronous, automatically cancelled task when this view appears or when `id` changes.
    @_disfavoredOverload
    public func task<T: Hashable>(
        id: T,
        key: String = #fileID + ":\(#line)",
        _ action: @escaping @Sendable () async -> Void
    ) -> ModifiedContent<Self> {
        KindleStateRegistry.shared.registerAsyncTask(
            id: "asynctask:\(key)",
            token: AnyHashable(id),
            action: action
        )
        return ModifiedContent(content: self) { _ in }
    }

    /// Runs an asynchronous, automatically cancelled task once when this view appears.
    @_disfavoredOverload
    public func task(
        key: String = #fileID + ":\(#line)",
        _ action: @escaping @Sendable () async -> Void
    ) -> ModifiedContent<Self> {
        task(id: key, key: key, action)
    }

}

// MARK: - ViewModifier Protocol & Supporting Types

/// A modifier that you apply to a view or another view modifier, producing a different version of the original value.
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifierContent<Self>
    @ViewBuilder func body(content: Self.Content) -> Self.Body
}

/// Proxy view representing the upstream content inside a `ViewModifier.body(content:)`.
public struct _ViewModifierContent<Modifier: ViewModifier>: View, _PrimitiveView {
    public typealias Body = Never
    private let makeNode: () -> RenderNode

    internal init(_ makeNode: @escaping () -> RenderNode) {
        self.makeNode = makeNode
    }

    public func _makeNode() -> RenderNode {
        makeNode()
    }
}

extension View {
    /// Applies a custom `ViewModifier` to this view.
    public func modifier<T: ViewModifier>(_ modifier: T) -> some View {
        modifier.body(content: _ViewModifierContent { self.buildRenderTree() })
    }
}

/// Vertical edge for `.safeAreaInset(edge:content:)`.
