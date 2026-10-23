import Foundation

/// A view created by applying a style/layout transformation to an upstream view.
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

    /// Sets the E-Ink grayscale foreground shade of this view (`gtk_widget_modify_fg`).
    public func foregroundColor(_ color: EInkColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.foregroundColor = color
        }
    }

    /// Sets the E-Ink grayscale background shade of this view (`gtk_widget_modify_bg`).
    public func background(_ color: EInkColor) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.backgroundColor = color
        }
    }

    /// Draws an E-Ink frame border around this view (`gtk_frame_new`).
    public func border(_ color: EInkColor = .black, width: Int = 1) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.borderColor = color
            style.borderWidth = max(1, width)
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

    /// Adds an action to perform when this view appears.
    public func onAppear(perform action: @escaping () -> Void) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            style.onAppear = action
        }
    }
}
