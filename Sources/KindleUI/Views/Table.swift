import Foundation

// MARK: - 2. Table, TableColumn & KeyPathComparator

/// A comparator that compares values using a `Comparable` property at a key path.
public struct KeyPathComparator<Compared>: Equatable, Sendable {
    public var order: SortOrder
    private let keyPathID: String
    private let compareFn: @Sendable (Compared, Compared) -> Bool

    public init<Value: Comparable>(
        _ keyPath: KeyPath<Compared, Value> & Sendable,
        order: SortOrder = .forward
    ) {
        self.order = order
        self.keyPathID = String(describing: keyPath)
        self.compareFn = { lhs, rhs in
            lhs[keyPath: keyPath] < rhs[keyPath: keyPath]
        }
    }

    public static func == (lhs: KeyPathComparator<Compared>, rhs: KeyPathComparator<Compared>) -> Bool {
        lhs.keyPathID == rhs.keyPathID && lhs.order == rhs.order
    }

    public func compare(_ lhs: Compared, _ rhs: Compared) -> Bool {
        if compareFn(lhs, rhs) {
            return order == .forward
        } else if compareFn(rhs, lhs) {
            return order == .reverse
        }
        return false
    }

    internal var identifier: String { keyPathID }
}

extension Array {
    /// Returns the elements of the sequence, sorted using the given comparator.
    public func sorted(using comparator: KeyPathComparator<Element>) -> [Element] {
        self.sorted { a, b in comparator.compare(a, b) }
    }

    /// Returns the elements of the sequence, sorted using the given array of comparators.
    public func sorted(using comparators: [KeyPathComparator<Element>]) -> [Element] {
        guard let first = comparators.first else { return self }
        return self.sorted(using: first)
    }
}

/// A column definition in a `Table` view.
public struct TableColumn<RowValue>: @unchecked Sendable {
    public let title: String
    public let alignment: HorizontalAlignment
    public let width: Int?
    internal let comparator: KeyPathComparator<RowValue>?
    internal let makeCell: (RowValue) -> RenderNode

    public init(
        _ title: String,
        value keyPath: KeyPath<RowValue, String> & Sendable,
        alignment: HorizontalAlignment = .leading,
        width: Int? = nil
    ) {
        self.title = title
        self.alignment = alignment
        self.width = width
        self.comparator = KeyPathComparator(keyPath)
        self.makeCell = { row in
            Text(row[keyPath: keyPath])
                .font(.body)
                .multilineTextAlignment(alignment)
                .buildRenderTree()
        }
    }

    public init<V: Comparable & CustomStringConvertible>(
        _ title: String,
        value keyPath: KeyPath<RowValue, V> & Sendable,
        alignment: HorizontalAlignment = .leading,
        width: Int? = nil
    ) {
        self.title = title
        self.alignment = alignment
        self.width = width
        self.comparator = KeyPathComparator(keyPath)
        self.makeCell = { row in
            Text(String(describing: row[keyPath: keyPath]))
                .font(.monospaced)
                .multilineTextAlignment(alignment)
                .buildRenderTree()
        }
    }

    public init<Content: View>(
        _ title: String,
        alignment: HorizontalAlignment = .leading,
        width: Int? = nil,
        sortUsing comparator: KeyPathComparator<RowValue>? = nil,
        @ViewBuilder content: @escaping (RowValue) -> Content
    ) {
        self.title = title
        self.alignment = alignment
        self.width = width
        self.comparator = comparator
        self.makeCell = { row in
            content(row).buildRenderTree()
        }
    }
}

@resultBuilder
public struct TableColumnBuilder<RowValue> {
    public static func buildBlock(_ columns: TableColumn<RowValue>...) -> [TableColumn<RowValue>] {
        columns
    }
}

/// A container that presents rows of data arranged in one or more sortable columns.
public struct Table<Value: Identifiable>: View, _PrimitiveView {
    public typealias Body = Never
    private let rows: [Value]
    private let selection: Binding<Value.ID?>?
    private let sortOrder: Binding<[KeyPathComparator<Value>]>?
    private let columns: [TableColumn<Value>]

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        selection: Binding<Value.ID?>? = nil,
        sortOrder: Binding<[KeyPathComparator<Value>]>? = nil,
        @TableColumnBuilder<Value> columns: () -> [TableColumn<Value>]
    ) where Data.Element == Value {
        self.rows = Array(data)
        self.selection = selection
        self.sortOrder = sortOrder
        self.columns = columns()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let activeComparator = sortOrder?.wrappedValue.first

        let headerCells: [RenderNode] = columns.map { col in
            let isSortedCol = (col.comparator != nil && activeComparator?.identifier == col.comparator?.identifier)
            let arrow = isSortedCol ? (activeComparator?.order == .forward ? " ▲" : " ▼") : ""
            let cellView: AnyView
            if let colComp = col.comparator, let sortOrder = sortOrder {
                cellView = AnyView(
                    Button("\(col.title)\(arrow)") {
                        var nextComp = colComp
                        if isSortedCol {
                            nextComp.order = (activeComparator?.order == .forward) ? .reverse : .forward
                        } else {
                            nextComp.order = .forward
                        }
                        sortOrder.wrappedValue = [nextComp]
                    }
                    .buttonStyle(isSortedCol ? .borderedProminent : .unbordered)
                    .controlSize(.mini)
                )
            } else {
                cellView = AnyView(
                    Text(col.title)
                        .font(.headline)
                        .foregroundColor(theme.foreground)
                )
            }

            if let w = col.width {
                return cellView.frame(width: w).expand(false, fill: true).buildRenderTree()
            } else {
                return cellView.expand(true, fill: true).buildRenderTree()
            }
        }

        let headerRow = RenderNode.hstack(
            alignment: .center,
            spacing: 12,
            children: headerCells,
            style: {
                var s = ViewStyle()
                s.homogeneous = columns.allSatisfy { $0.width == nil }
                s.backgroundColor = theme.panelBackground
                s.contentPadding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                s.cornerRadius = 10
                return s
            }()
        )

        var rowNodes: [RenderNode] = [
            headerRow,
            Divider(thickness: 1, color: theme.subtleBorder).buildRenderTree()
        ]

        for (idx, row) in rows.enumerated() {
            let isSelected = (selection?.wrappedValue == row.id)
            let cells: [RenderNode] = columns.map { col in
                let raw = col.makeCell(row)
                if let w = col.width {
                    return raw.modifyingStyle { s in
                        s.width = w
                        s.expand = false
                        s.fill = true
                    }
                } else {
                    return raw.modifyingStyle { s in
                        s.expand = true
                        s.fill = true
                    }
                }
            }

            let rowHStack = RenderNode.hstack(
                alignment: .center,
                spacing: 12,
                children: cells,
                style: {
                    var s = ViewStyle()
                    s.homogeneous = columns.allSatisfy { $0.width == nil }
                    s.backgroundColor = isSelected ? theme.panelBackground : (idx % 2 == 1 ? theme.background : theme.cardBackground)
                    if isSelected {
                        s.borderColor = theme.foreground
                        s.borderWidth = 1
                        s.cornerRadius = 10
                    }
                    s.contentPadding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                    if let selection = selection {
                        let rowID = row.id
                        s.onTapGesture = {
                            if selection.wrappedValue == rowID {
                                selection.wrappedValue = nil
                            } else {
                                selection.wrappedValue = rowID
                            }
                        }
                    }
                    return s
                }()
            )
            rowNodes.append(rowHStack)
            if idx + 1 < rows.count {
                rowNodes.append(Divider(thickness: 1, color: theme.subtleBorder).buildRenderTree())
            }
        }

        var tableStyle = ViewStyle()
        tableStyle.backgroundColor = theme.cardBackground
        tableStyle.borderColor = theme.subtleBorder
        tableStyle.borderWidth = 1
        tableStyle.cornerRadius = 16
        tableStyle.contentPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        return .vstack(alignment: .leading, spacing: 4, children: rowNodes, style: tableStyle)
    }
}
