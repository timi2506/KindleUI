import Foundation

/// A view that arranges its subviews in a vertical line (`gtk_vbox_new`).
public struct VStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let homogeneous: Bool
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 10,
        homogeneous: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.homogeneous = homogeneous
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let children = content.buildRenderTree().flattenedChildren
        var style = ViewStyle()
        style.homogeneous = homogeneous
        return .vstack(alignment: alignment, spacing: spacing, children: children, style: style)
    }
}

/// A view that arranges its subviews in a horizontal line (`gtk_hbox_new`).
public struct HStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: VerticalAlignment
    public let spacing: Int
    public let homogeneous: Bool
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 10,
        homogeneous: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.homogeneous = homogeneous
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let children = content.buildRenderTree().flattenedChildren
        var style = ViewStyle()
        style.homogeneous = homogeneous
        return .hstack(alignment: alignment, spacing: spacing, children: children, style: style)
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



/// A crisp Cairo-rendered separator line.
public struct Divider: View, _PrimitiveView {
    public typealias Body = Never
    public let vertical: Bool
    public let thickness: Int
    public let color: EInkColor?

    public init(vertical: Bool = false, thickness: Int = 2, color: EInkColor? = nil) {
        self.vertical = vertical
        self.thickness = max(1, thickness)
        self.color = color
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.foregroundColor = color
        if vertical {
            style.width = thickness
        } else {
            style.height = thickness
        }
        return .divider(vertical: vertical, style: style)
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



// MARK: - 4. LazyVStack, LazyHStack, LazyHGrid & PinnedScrollableViews

/// A set of view types that may be pinned to the bounds of a scroll view.
public struct PinnedScrollableViews: OptionSet, Sendable, Equatable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}

/// A view that arranges its children in a line that grows vertically, creating items only as needed.
public struct LazyVStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let pinnedViews: PinnedScrollableViews
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Int = 8,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .buildRenderTree()
    }
}

/// A view that arranges its children in a line that grows horizontally, creating items only as needed.
public struct LazyHStack<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: VerticalAlignment
    public let spacing: Int
    public let pinnedViews: PinnedScrollableViews
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 8,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
        .buildRenderTree()
    }
}
