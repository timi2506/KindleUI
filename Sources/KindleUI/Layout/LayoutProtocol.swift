import Foundation

// MARK: - Layout Protocol, FlowLayout, HStackLayout, VStackLayout & AnyLayout

/// A type that defines the geometry and arrangement of a collection of subviews.
public protocol KindleLayout: Sendable {
    func arrange(_ children: [RenderNode]) -> RenderNode
}

/// A layout that arranges subviews in a horizontal line.
public struct HStackLayout: KindleLayout {
    public let alignment: VerticalAlignment
    public let spacing: Int

    public init(alignment: VerticalAlignment = .center, spacing: Int = 12) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public func arrange(_ children: [RenderNode]) -> RenderNode {
        .hstack(alignment: alignment, spacing: spacing, children: children, style: ViewStyle())
    }
}

/// A layout that arranges subviews in a vertical line.
public struct VStackLayout: KindleLayout {
    public let alignment: HorizontalAlignment
    public let spacing: Int

    public init(alignment: HorizontalAlignment = .leading, spacing: Int = 12) {
        self.alignment = alignment
        self.spacing = spacing
    }

    public func arrange(_ children: [RenderNode]) -> RenderNode {
        .vstack(alignment: alignment, spacing: spacing, children: children, style: ViewStyle())
    }
}

/// A wrapping flow layout that arranges tags, chips, or controls horizontally and wraps onto new lines when exceeding `maxRowWidth`.
public struct FlowLayout<Content: View>: KindleLayout, View, _PrimitiveView, @unchecked Sendable {
    public typealias Body = Never
    public let alignment: HorizontalAlignment
    public let spacing: Int
    public let lineSpacing: Int
    public let maxRowWidth: Int
    private let content: (() -> Content)?

    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 14,
        lineSpacing: Int = 14,
        maxRowWidth: Int = 1520,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.maxRowWidth = max(200, maxRowWidth)
        self.content = content
    }

    public init(
        alignment: HorizontalAlignment = .leading,
        spacing: Int = 14,
        lineSpacing: Int = 14,
        maxRowWidth: Int = 1520
    ) where Content == EmptyView {
        self.alignment = alignment
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.maxRowWidth = max(200, maxRowWidth)
        self.content = nil
    }

    public func arrange(_ children: [RenderNode]) -> RenderNode {
        guard !children.isEmpty else { return .empty }
        var rows: [[RenderNode]] = []
        var currentRow: [RenderNode] = []
        var currentWidth: Int = 0

        for child in children {
            let itemW = Self.estimatedWidth(of: child)
            let needed = currentRow.isEmpty ? itemW : (currentWidth + spacing + itemW)
            if !currentRow.isEmpty && needed > maxRowWidth {
                rows.append(currentRow)
                currentRow = [child]
                currentWidth = itemW
            } else {
                currentRow.append(child)
                currentWidth = needed
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        let rowNodes: [RenderNode] = rows.map { rowItems in
            var rowStyle = ViewStyle()
            rowStyle.expand = false
            rowStyle.fill = false
            return .hstack(alignment: .center, spacing: spacing, children: rowItems, style: rowStyle)
        }

        var vStyle = ViewStyle()
        vStyle.expand = false
        vStyle.fill = true
        return .vstack(alignment: alignment, spacing: lineSpacing, children: rowNodes, style: vStyle)
    }

    public func _makeNode() -> RenderNode {
        guard let content = content else { return .empty }
        let children = content().buildRenderTree().flattenedChildren
        return arrange(children)
    }

    private static func estimatedWidth(of node: RenderNode) -> Int {
        switch node {
        case .text(let content, _, _, let style):
            if let w = style.width { return w }
            let pad = (style.padding?.leading ?? 0) + (style.padding?.trailing ?? 0)
                + (style.contentPadding?.leading ?? 0) + (style.contentPadding?.trailing ?? 0)
            return max(80, content.count * 22 + pad + 24)
        case .button(let label, let customChild, _, let style):
            if let w = style.width { return w }
            if let custom = customChild {
                return estimatedWidth(of: custom) + 64
            }
            return max(110, label.count * 22 + 72)
        case .hstack(_, let spacing, let children, let style):
            if let w = style.width { return w }
            let sum = children.reduce(0) { $0 + estimatedWidth(of: $1) }
            return sum + max(0, children.count - 1) * spacing + 28
        default:
            return 220
        }
    }
}

/// A type-erased instance of the `KindleLayout` protocol that dynamically switches layouts (`HStackLayout`, `VStackLayout`, `FlowLayout`).
public struct AnyLayout: KindleLayout {
    private let baseArrange: @Sendable ([RenderNode]) -> RenderNode

    public init<L: KindleLayout>(_ layout: L) {
        self.baseArrange = { children in layout.arrange(children) }
    }

    public func arrange(_ children: [RenderNode]) -> RenderNode {
        baseArrange(children)
    }

    public func callAsFunction<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        _AnyLayoutContainerView(layout: self, content: content)
    }
}

private struct _AnyLayoutContainerView<Content: View>: View, _PrimitiveView {
    typealias Body = Never
    let layout: AnyLayout
    let content: () -> Content

    func _makeNode() -> RenderNode {
        let children = content().buildRenderTree().flattenedChildren
        return layout.arrange(children)
    }
}
