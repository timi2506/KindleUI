import Foundation

// MARK: - Grid, GridRow & LazyVGrid

/// A single row inside a `Grid` layout.
public struct GridRow<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: VerticalAlignment
    public let spacing: Int
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Int = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        HStack(alignment: alignment, spacing: spacing, homogeneous: true) {
            content
        }
        .expand(false, fill: true)
        .buildRenderTree()
    }
}

extension View {
    /// Tells a view that acts as a cell in a grid to span the specified number of columns.
    public func gridCellColumns(_ count: Int) -> ModifiedContent<Self> {
        self.expand(count > 1, fill: true)
    }
}

/// A 2D container view that arranges `GridRow` views in aligned rows and columns.
public struct Grid<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let alignment: HorizontalAlignment
    public let horizontalSpacing: Int
    public let verticalSpacing: Int
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .leading,
        horizontalSpacing: Int = 18,
        verticalSpacing: Int = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        VStack(alignment: alignment, spacing: verticalSpacing) {
            content
        }
        .expand(false, fill: true)
        .buildRenderTree()
    }
}

/// A description of a column in a `LazyVGrid`.
public struct GridItem: Sendable, Equatable {
    public enum Size: Sendable, Equatable {
        case flexible
        case fixed(Int)
        case adaptive(minimum: Int)

        public static func flexible(minimum: Int = 40, maximum: Int = 1000) -> Size {
            .flexible
        }
    }

    public let size: Size
    public let spacing: Int

    public init(_ size: Size = .flexible, spacing: Int = 18) {
        self.size = size
        self.spacing = spacing
    }
}

/// A container view that arranges its child views in a multi-column grid growing vertically.
public struct LazyVGrid<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let columns: [GridItem]
    public let spacing: Int
    private let content: Content

    public init(
        columns: [GridItem],
        spacing: Int = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns.isEmpty ? [GridItem(.flexible)] : columns
        self.spacing = spacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let items = content.buildRenderTree().flattenedChildren
        let colCount = max(1, columns.count)
        let hSpacing = columns.first?.spacing ?? spacing

        var rows: [RenderNode] = []
        var idx = 0
        while idx < items.count {
            let end = min(idx + colCount, items.count)
            var rowChildren = Array(items[idx..<end]).map { node in
                node.modifyingStyle { style in
                    style.expand = true
                    style.fill = true
                }
            }
            while rowChildren.count < colCount {
                var emptyStyle = ViewStyle()
                emptyStyle.expand = true
                emptyStyle.fill = true
                rowChildren.append(.spacer(minLength: 1, style: emptyStyle))
            }
            var rowStyle = ViewStyle()
            rowStyle.homogeneous = true
            rowStyle.expand = false
            rowStyle.fill = true
            rows.append(.hstack(alignment: .center, spacing: hSpacing, children: rowChildren, style: rowStyle))
            idx += colCount
        }

        var gridStyle = ViewStyle()
        gridStyle.expand = false
        gridStyle.fill = true
        return .vstack(alignment: .leading, spacing: spacing, children: rows, style: gridStyle)
    }
}



/// A container view that arranges its child views in a grid that grows horizontally.
public struct LazyHGrid<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let rows: [GridItem]
    public let spacing: Int
    private let content: Content

    public init(
        rows: [GridItem],
        spacing: Int = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.rows = rows
        self.spacing = spacing
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        LazyVGrid(columns: rows, spacing: spacing) {
            content
        }
        .buildRenderTree()
    }
}
