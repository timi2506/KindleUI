import Foundation

/// A container that presents rows of data arranged in a single scrollable column with E-Ink dividers.
public struct List<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let rawRows = content.buildRenderTree().flattenedChildren
        var separatedRows: [RenderNode] = []
        for (idx, row) in rawRows.enumerated() {
            let paddedRow = row.modifyingStyle { s in
                if s.padding == nil && s.contentPadding == nil {
                    s.padding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                }
            }
            separatedRows.append(paddedRow)
            if idx + 1 < rawRows.count {
                var divStyle = ViewStyle()
                divStyle.foregroundColor = theme.subtleBorder
                divStyle.height = 1
                separatedRows.append(.divider(vertical: false, style: divStyle))
            }
        }
        var cardStyle = ViewStyle()
        cardStyle.backgroundColor = theme.panelBackground
        cardStyle.borderColor = theme.subtleBorder
        cardStyle.borderWidth = 1
        cardStyle.cornerRadius = 16
        cardStyle.contentPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        return .vstack(alignment: .leading, spacing: 2, children: separatedRows, style: cardStyle)
    }
}

/// A button that toggles the `EditMode` environment value between `.active` and `.inactive`.
public struct EditButton: View, _PrimitiveView {
    public typealias Body = Never

    public init() {}

    public func _makeNode() -> RenderNode {
        let editBinding = KindleStateRegistry.shared.currentEnvironment.editMode
        let isEditing = editBinding?.wrappedValue.isEditing ?? false
        return Button(isEditing ? "Done" : "Edit") {
            if let editBinding = editBinding {
                editBinding.wrappedValue = isEditing ? .inactive : .active
            } else {
                KindleStateRegistry.shared.defaultEditMode = isEditing ? .inactive : .active
                KindleStateRegistry.shared.notifyStateMutation()
            }
        }
        .buttonStyle(isEditing ? .borderedProminent : .bordered)
        .controlSize(.small)
        .buildRenderTree()
    }
}

/// A structure that computes views on demand from an underlying collection of identified data.
public struct ForEach<Data: RandomAccessCollection, Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let items: [(String, Data.Element)]
    private let contentBuilder: (Data.Element) -> Content
    private var deleteHandler: ((IndexSet) -> Void)? = nil
    private var moveHandler: ((IndexSet, Int) -> Void)? = nil

    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        var collected: [(String, Data.Element)] = []
        for (idx, element) in data.enumerated() {
            collected.append(("idx:\(idx)", element))
        }
        self.items = collected
        self.contentBuilder = content
    }

    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) where Data.Element: Identifiable {
        self.items = data.map { ("id:\($0.id)", $0) }
        self.contentBuilder = content
    }

    public init<ID: Hashable>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.items = data.map { ("id:\($0[keyPath: id])", $0) }
        self.contentBuilder = content
    }

    /// Sets the deletion action for the dynamic view (`ForEach`).
    public func onDelete(perform action: ((IndexSet) -> Void)?) -> ForEach {
        var copy = self
        copy.deleteHandler = action
        return copy
    }

    /// Sets the move action for the dynamic view (`ForEach`).
    public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> ForEach {
        var copy = self
        copy.moveHandler = action
        return copy
    }

    public func _makeNode() -> RenderNode {
        let isEditing = KindleStateRegistry.shared.currentEnvironment.editMode?.wrappedValue.isEditing ?? false
        let onDelete = deleteHandler
        let onMove = moveHandler
        let total = items.count

        let built = items.enumerated().map { (idx, pair) -> RenderNode in
            let (scopeID, element) = pair
            KindleStateRegistry.shared.pushScope("ForEach[\(scopeID)]")
            defer { KindleStateRegistry.shared.popScope() }

            guard onDelete != nil || onMove != nil else {
                return contentBuilder(element).buildRenderTree()
            }

            let revealedBox = KindleStateRegistry.shared.obtainBox(
                siteKey: "foreach-reveal",
                initialValue: { false }
            )
            let showControls = isEditing || revealedBox.value
            let childView = contentBuilder(element)

            return HStack(alignment: .center, spacing: 12) {
                childView
                    .expand(true, fill: true)

                if showControls {
                    if let onMove = onMove {
                        Button("↑") {
                            guard idx > 0 else { return }
                            onMove(IndexSet(integer: idx), idx - 1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(idx == 0)

                        Button("↓") {
                            guard idx + 1 < total else { return }
                            onMove(IndexSet(integer: idx), idx + 2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(idx + 1 >= total)
                    }
                    if let onDelete = onDelete {
                        Button("Delete") {
                            revealedBox.value = false
                            onDelete(IndexSet(integer: idx))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                    }
                }
            }
            .onSwipeGesture(
                threshold: 32,
                onLeft: {
                    revealedBox.value = true
                },
                onRight: {
                    revealedBox.value = false
                }
            )
            .buildRenderTree()
        }
        return .group(built)
    }
}



// MARK: - 3. OutlineGroup & Hierarchical List(children:)

/// A structure that computes views and disclosure groups on demand from an underlying tree of tree-structured, identified data.
public struct OutlineGroup<DataElement: Identifiable, RowContent: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let roots: [DataElement]
    private let childrenKeyPath: KeyPath<DataElement, [DataElement]?>
    private let rowContent: (DataElement) -> RowContent

    public init(
        _ data: [DataElement],
        children: KeyPath<DataElement, [DataElement]?>,
        @ViewBuilder content: @escaping (DataElement) -> RowContent
    ) {
        self.roots = data
        self.childrenKeyPath = children
        self.rowContent = content
    }

    public init(
        _ root: DataElement,
        children: KeyPath<DataElement, [DataElement]?>,
        @ViewBuilder content: @escaping (DataElement) -> RowContent
    ) {
        self.roots = [root]
        self.childrenKeyPath = children
        self.rowContent = content
    }

    public func _makeNode() -> RenderNode {
        var nodes: [RenderNode] = []
        for item in roots {
            appendTreeNodes(for: item, depth: 0, into: &nodes)
        }
        return .vstack(alignment: .leading, spacing: 6, children: nodes, style: ViewStyle())
    }

    private func appendTreeNodes(for item: DataElement, depth: Int, into output: inout [RenderNode]) {
        let itemID = "\(item.id)"
        let subitems = item[keyPath: childrenKeyPath] ?? []
        let hasChildren = !subitems.isEmpty
        let leadingIndent = depth * 28

        KindleStateRegistry.shared.pushScope("Outline[\(itemID)]")
        let expandedBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "expanded",
            initialValue: { depth == 0 }
        )
        KindleStateRegistry.shared.popScope()

        let isExpanded = expandedBox.value
        let rowView = HStack(alignment: .center, spacing: 10) {
            if hasChildren {
                Button(isExpanded ? "▼" : "▶") {
                    expandedBox.value.toggle()
                    KindleStateRegistry.shared.notifyStateMutation()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                Text("•")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }

            rowContent(item)
                .expand(true, fill: true)
        }
        .padding(EdgeInsets(top: 4, leading: leadingIndent, bottom: 4, trailing: 4))
        .buildRenderTree()

        output.append(rowView)

        if hasChildren && isExpanded {
            for child in subitems {
                appendTreeNodes(for: child, depth: depth + 1, into: &output)
            }
        }
    }
}

extension List {
    /// Creates a hierarchical list that identifies its rows based on a key path to the child nodes.
    public init<DataElement: Identifiable, RowContent: View>(
        _ data: [DataElement],
        children: KeyPath<DataElement, [DataElement]?>,
        @ViewBuilder rowContent: @escaping (DataElement) -> RowContent
    ) where Content == OutlineGroup<DataElement, RowContent> {
        self.init {
            OutlineGroup(data, children: children, content: rowContent)
        }
    }
}
