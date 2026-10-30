import Foundation
import CKindleGTK

extension View {
    // MARK: - Flexible Frame (.frame(maxWidth: .infinity, ...))

    /// Positions this view within an invisible frame having the specified size constraints.
    /// Pass `.infinity` for `maxWidth` or `maxHeight` to expand across the parent container.
    @_disfavoredOverload
    public func frame(
        minWidth: Double? = nil,
        idealWidth: Double? = nil,
        maxWidth: Double? = nil,
        minHeight: Double? = nil,
        idealHeight: Double? = nil,
        maxHeight: Double? = nil,
        alignment: Alignment? = nil
    ) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            if let maxWidth = maxWidth {
                if maxWidth.isInfinite {
                    style.expandHorizontally = true
                    style.fillHorizontally = true
                    style.expand = true
                    style.fill = true
                } else {
                    style.width = Int(maxWidth)
                }
            } else if let idealWidth = idealWidth {
                style.width = Int(idealWidth)
            } else if let minWidth = minWidth {
                style.width = Int(minWidth)
            }

            if let maxHeight = maxHeight {
                if maxHeight.isInfinite {
                    style.expandVertically = true
                    style.fillVertically = true
                    style.expand = true
                    style.fill = true
                } else {
                    style.height = Int(maxHeight)
                }
            } else if let idealHeight = idealHeight {
                style.height = Int(idealHeight)
            } else if let minHeight = minHeight {
                style.height = Int(minHeight)
            }

            if let alignment = alignment {
                style.alignment = alignment
            }
        }
    }


    // MARK: - .safeAreaInset & .toolbar

    /// Layers `content` as a persistent top or bottom bar inset alongside this view.
    public func safeAreaInset<InsetContent: View>(
        edge: VerticalEdge = .bottom,
        spacing: Int = 12,
        @ViewBuilder content: @escaping () -> InsetContent
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if edge == .top {
                content()
                self
            } else {
                self
                content()
            }
        }
        .expand(true, fill: true)
    }

    /// Populates the navigation bar toolbar with the specified views.
    public func toolbar<ToolbarContent: View>(
        @ViewBuilder content: @escaping () -> ToolbarContent
    ) -> ModifiedContent<Self> {
        let nodes = content().buildRenderTree().flattenedChildren
        return ModifiedContent(content: self) { style in
            style.toolbarNodes.append(contentsOf: nodes)
        }
    }
}



public enum VerticalEdge: Sendable, Equatable {
    case top
    case bottom
}

/// Placement role for a `ToolbarItem`.
public enum ToolbarItemPlacement: Sendable, Equatable {
    case automatic
    case topBarLeading
    case topBarTrailing
    case bottomBar
}

/// A model that represents an item which can be placed in a `NavigationStack` toolbar.
public struct ToolbarItem<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let placement: ToolbarItemPlacement
    private let content: () -> Content

    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: @escaping () -> Content) {
        self.placement = placement
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        content().buildRenderTree()
    }
}



extension View {
    /// Fixes this view at its ideal size in both dimensions.
    public func fixedSize() -> ModifiedContent<Self> {
        self.expand(false, fill: false)
    }

    /// Fixes this view at its ideal size in the specified dimensions.
    public func fixedSize(horizontal: Bool, vertical: Bool) -> ModifiedContent<Self> {
        self.expand(!(horizontal || vertical), fill: !(horizontal && vertical))
    }

    /// Sets the priority by which a parent layout should apportion space to this child.
    public func layoutPriority(_ value: Double) -> ModifiedContent<Self> {
        self.expand(value > 0, fill: true)
    }

    /// Constrains this view's dimensions to the specified aspect ratio.
    public func aspectRatio(_ ratio: Double? = nil, contentMode: ContentMode) -> ModifiedContent<Self> {
        _ = ratio
        return self.expand(contentMode == .fill, fill: true)
    }

    /// Scales this view to fit its parent.
    public func scaledToFit() -> ModifiedContent<Self> {
        self.aspectRatio(nil, contentMode: .fit)
    }

    /// Scales this view to fill its parent.
    public func scaledToFill() -> ModifiedContent<Self> {
        self.aspectRatio(nil, contentMode: .fill)
    }

    /// Offsets this view by the specified horizontal and vertical distances.
    public func offset(x: Int = 0, y: Int = 0) -> ModifiedContent<Self> {
        let top = max(0, y)
        let leading = max(0, x)
        let bottom = max(0, -y)
        let trailing = max(0, -x)
        return self.padding(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }

    /// Positions the center of this view at the specified coordinates in its parent's coordinate space.
    public func position(x: Int, y: Int) -> ModifiedContent<Self> {
        self.offset(x: max(0, x - 20), y: max(0, y - 20))
    }

    /// Controls the display order of overlapping views.
    public func zIndex(_ value: Double) -> Self {
        _ = value
        return self
    }

    /// Rotates this view's rendered output around the specified point.
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> Self {
        _ = angle
        _ = anchor
        return self
    }

    /// Scales this view's rendered output by the given scale factor.
    public func scaleEffect(_ s: Double, anchor: UnitPoint = .center) -> Self {
        _ = s
        _ = anchor
        return self
    }

    /// Sets the view's horizontal alignment guide.
    public func alignmentGuide(
        _ g: HorizontalAlignment,
        computeValue: @escaping (ViewDimensions) -> Int
    ) -> ModifiedContent<Self> {
        _ = computeValue(ViewDimensions())
        return ModifiedContent(content: self) { style in
            style.alignment = Alignment(horizontal: g, vertical: style.alignment?.vertical ?? .center)
        }
    }

    /// Sets the view's vertical alignment guide.
    public func alignmentGuide(
        _ g: VerticalAlignment,
        computeValue: @escaping (ViewDimensions) -> Int
    ) -> ModifiedContent<Self> {
        _ = computeValue(ViewDimensions())
        return ModifiedContent(content: self) { style in
            style.alignment = Alignment(horizontal: style.alignment?.horizontal ?? .center, vertical: g)
        }
    }

    /// Positions this view within an invisible frame with a size relative to the nearest container.
    public func containerRelativeFrame(
        _ axes: Axis.Set,
        count: Int = 1,
        span: Int = 1,
        spacing: Int = 0,
        alignment: Alignment = .center
    ) -> ModifiedContent<Self> {
        var screenW: Int32 = 1200
        var screenH: Int32 = 1600
        kgtk_get_screen_size(&screenW, &screenH)
        let scale = max(0.3, kgtk_get_ui_scale())
        let logicalW = Int(Double(screenW) / scale) - 96
        let logicalH = Int(Double(screenH) / scale) - 200
        let w: Int? = axes.contains(.horizontal) ? max(40, (logicalW * max(1, span)) / max(1, count) - spacing) : nil
        let h: Int? = axes.contains(.vertical) ? max(40, (logicalH * max(1, span)) / max(1, count) - spacing) : nil
        return self.frame(width: w, height: h, alignment: alignment)
    }

    /// Adds an action to be performed when a value, created from a `GeometryProxy`, changes.
    public func onGeometryChange<T: Equatable>(
        for type: T.Type = T.self,
        of transform: @escaping (GeometryProxy) -> T,
        action: @escaping (T) -> Void
    ) -> some View {
        var screenW: Int32 = 1200
        var screenH: Int32 = 1600
        kgtk_get_screen_size(&screenW, &screenH)
        let scale = max(0.3, kgtk_get_ui_scale())
        let proxy = GeometryProxy(
            size: GeometrySize(
                width: Double(screenW) / scale,
                height: Double(screenH) / scale
            )
        )
        let value = transform(proxy)
        return self.onChange(of: value, perform: action)
    }
}
