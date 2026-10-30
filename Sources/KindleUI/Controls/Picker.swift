import Foundation

// MARK: - Picker (Segmented E-Ink Control)

/// A segmented E-Ink picker control that presents mutually exclusive options in a unified rounded bar or pill row.
public struct Picker<SelectionValue: Equatable>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String?
    public let selection: Binding<SelectionValue>
    public let options: [SelectionValue]
    public let labelProvider: (SelectionValue) -> String
    public let height: Int?
    public let onSelect: ((SelectionValue) -> Void)?
    private var styleVariant: KindlePickerStyle = .segmented

    public init<C: RandomAccessCollection>(
        _ title: String? = nil,
        selection: Binding<SelectionValue>,
        options: C,
        height: Int? = nil,
        onSelect: ((SelectionValue) -> Void)? = nil,
        label: @escaping (SelectionValue) -> String
    ) where C.Element == SelectionValue {
        self.title = title
        self.selection = selection
        self.options = Array(options)
        self.height = height
        self.onSelect = onSelect
        self.labelProvider = label
    }

    /// Sets the presentation style for this `Picker` (`.segmented`, `.pills`, or `.cards`).
    public func pickerStyle(_ style: KindlePickerStyle) -> Picker<SelectionValue> {
        var copy = self
        copy.styleVariant = style
        return copy
    }

    private static func segmentedItemShape(index: Int, count: Int) -> UnevenRoundedRectangle {
        if count <= 1 {
            return UnevenRoundedRectangle(topLeadingRadius: 999, bottomLeadingRadius: 999, bottomTrailingRadius: 999, topTrailingRadius: 999)
        } else if index == 0 {
            return UnevenRoundedRectangle(topLeadingRadius: 999, bottomLeadingRadius: 999, bottomTrailingRadius: 0, topTrailingRadius: 0)
        } else if index == count - 1 {
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 999, topTrailingRadius: 999)
        } else {
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
        }
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let current = selection.wrappedValue

        let controlNode: RenderNode
        switch styleVariant {
        case .segmented:
            // Pill-shaped outer track where only the first item is rounded on the left and last item on the right
            controlNode = HStack(alignment: .center, spacing: 4, homogeneous: true) {
                ForEach(options.indices) { idx in
                    let item = options[idx]
                    let active = (item == current)
                    let itemShape = Self.segmentedItemShape(index: idx, count: options.count)
                    Button(labelProvider(item)) {
                        if selection.wrappedValue != item {
                            selection.wrappedValue = item
                            onSelect?(item)
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .buttonStyle(active ? .borderedProminent : .plain)
                    .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                    .clipShape(itemShape)
                    .frame(height: height)
                    .expand(true, fill: true)
                }
            }
            .padding(6)
            .background(theme.panelBackground, cornerRadius: 999)
            .border(theme.subtleBorder, width: 1, cornerRadius: 999)
            .buildRenderTree()

        case .pills:
            controlNode = HStack(alignment: .center, spacing: 16, homogeneous: true) {
                ForEach(options) { item in
                    let active = (item == current)
                    Button(labelProvider(item)) {
                        if selection.wrappedValue != item {
                            selection.wrappedValue = item
                            onSelect?(item)
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .buttonStyle(active ? .borderedProminent : .capsule)
                    .cornerRadius(999)
                    .frame(height: height)
                    .expand(true, fill: true)
                }
            }
            .buildRenderTree()

        case .cards:
            controlNode = HStack(alignment: .center, spacing: 16, homogeneous: true) {
                ForEach(options) { item in
                    let active = (item == current)
                    Button(labelProvider(item)) {
                        if selection.wrappedValue != item {
                            selection.wrappedValue = item
                            onSelect?(item)
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .buttonStyle(active ? .borderedProminent : .card)
                    .frame(height: height)
                    .expand(true, fill: true)
                }
            }
            .buildRenderTree()
        }

        if let title = title, !title.isEmpty {
            return VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.mutedForeground)
                AnyView(node: controlNode)
            }
            .buildRenderTree()
        }
        return controlNode
    }
}

extension Picker where SelectionValue: CaseIterable & RawRepresentable, SelectionValue.RawValue == String {
    /// Creates a segmented E-Ink picker from all cases of a string-backed `CaseIterable` enum.
    public init(
        _ title: String? = nil,
        selection: Binding<SelectionValue>,
        height: Int? = nil,
        onSelect: ((SelectionValue) -> Void)? = nil
    ) {
        self.init(
            title,
            selection: selection,
            options: Array(SelectionValue.allCases),
            height: height,
            onSelect: onSelect,
            label: { $0.rawValue }
        )
    }
}



/// A control for presenting a collapsible E-Ink menu of actions.
public struct Menu<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let icon: KindleIconName?
    private let isExpandedBox: StateBox<Bool>
    private let content: () -> Content

    public init(
        _ title: String,
        icon: KindleIconName? = nil,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isExpandedBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "menu:\(fileID):\(line):\(column)",
            initialValue: { false }
        )
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let expanded = isExpandedBox.value
        let box = isExpandedBox
        let items = content().buildRenderTree().flattenedChildren

        return VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                box.value.toggle()
            }) {
                HStack(alignment: .center, spacing: 12) {
                    if let icon = icon {
                        Icon(icon, size: 36)
                    }
                    Text(title)
                        .font(.headline)
                    Icon(expanded ? .chevronUp : .chevronDown, size: 32)
                }
            }
            .buttonStyle(expanded ? .borderedProminent : .bordered)
            .controlSize(.small)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<items.count) { idx in
                        AnyView(node: items[idx].modifyingStyle { s in
                            s.expand = false
                            s.fill = true
                        })
                    }
                }
                .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
                .background(theme.cardBackground, cornerRadius: 18)
                .border(theme.subtleBorder, width: 1, cornerRadius: 18)
                .shadow(color: theme.shadowColor, x: 2, y: 2)
            }
        }
        .buildRenderTree()
    }
}



/// A control used to select an E-Ink 4-bit grayscale shade (`Y0`..`Y15`).
public struct ColorPicker: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let selection: Binding<EInkColor>

    private static let palette: [(String, EInkColor)] = [
        ("Y0", .gray4Bit(0)),
        ("Y3", .gray4Bit(3)),
        ("Y6", .gray4Bit(6)),
        ("Y9", .gray4Bit(9)),
        ("Y12", .gray4Bit(12)),
        ("Y15", .gray4Bit(15))
    ]

    public init(_ title: String, selection: Binding<EInkColor>) {
        self.title = title
        self.selection = selection
    }

    public func _makeNode() -> RenderNode {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.headline)
            Spacer()
            ForEach(0..<Self.palette.count) { idx in
                let (name, shade) = Self.palette[idx]
                let isSelected = (abs(Int(selection.wrappedValue.grayLevel) - Int(shade.grayLevel)) <= 12)
                Button(name) {
                    selection.wrappedValue = shade
                }
                .buttonStyle(isSelected ? .borderedProminent : .bordered)
                .controlSize(.mini)
            }
        }
        .buildRenderTree()
    }
}
