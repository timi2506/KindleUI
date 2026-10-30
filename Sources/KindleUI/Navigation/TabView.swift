import Foundation
import CKindleGTK

// MARK: - TabView, Tab & KindleTab

/// A single tab page definition inside a `TabView`, supporting both a title and a vector icon (like iOS `Tab`).
public struct KindleTab<Tag: Equatable> {
    public let title: String
    public let icon: KindleIconName?
    public let badge: String?
    public let tag: Tag
    internal let makeContent: () -> RenderNode

    public init<Content: View>(
        _ title: String,
        icon: KindleIconName? = nil,
        badge: String? = nil,
        value: Tag,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.badge = badge
        self.tag = value
        self.makeContent = { content().buildRenderTree() }
    }

    public init<Content: View>(
        _ title: String,
        systemImage: String,
        badge: String? = nil,
        value: Tag,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = KindleIconName(systemName: systemImage)
        self.badge = badge
        self.tag = value
        self.makeContent = { content().buildRenderTree() }
    }
}

/// SwiftUI 18+ `Tab` alias for `KindleTab`.
public typealias Tab<Tag: Equatable> = KindleTab<Tag>

@resultBuilder
public struct KindleTabBuilder<Tag: Equatable> {
    public static func buildExpression(_ expression: KindleTab<Tag>) -> KindleTab<Tag> {
        expression
    }

    public static func buildBlock(_ tabs: KindleTab<Tag>...) -> [KindleTab<Tag>] {
        tabs
    }
}

/// A container view that switches between multiple child views using an iOS-style E-Ink bottom Tab Bar with icons and labels.
///
/// Automatically triggers an E-Ink display refresh when switching tabs.
public struct TabView<SelectionValue: Equatable>: View, _PrimitiveView {
    public typealias Body = Never
    public let selection: Binding<SelectionValue>
    public let tabs: [KindleTab<SelectionValue>]
    public let onTabChange: ((SelectionValue) -> Void)?
    private var styleVariant: KindleTabViewStyle = .bottomBar

    public init(
        selection: Binding<SelectionValue>,
        onTabChange: ((SelectionValue) -> Void)? = nil,
        @KindleTabBuilder<SelectionValue> content: () -> [KindleTab<SelectionValue>]
    ) {
        self.selection = selection
        self.onTabChange = onTabChange
        self.tabs = content()
    }

    /// Sets the visual style of the `TabView` dock.
    public func tabViewStyle(_ style: KindleTabViewStyle) -> TabView<SelectionValue> {
        var copy = self
        copy.styleVariant = style
        return copy
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let current = selection.wrappedValue
        let lastTabBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "tabview-last-selection",
            initialValue: { Optional<SelectionValue>.some(current) }
        )
        if let prevTab = lastTabBox.value, prevTab != current {
            kgtk_reset_scroll_position()
        }
        lastTabBox.value = current
        let activeNode = ((tabs.first(where: { $0.tag == current }) ?? tabs.first)?.makeContent() ?? .empty)
            .modifyingStyle { s in
                s.expand = true
                s.fill = true
            }

        let hPad = tabs.count >= 6 ? 10 : (tabs.count >= 5 ? 14 : (tabs.count >= 4 ? 18 : 24))
        let vPad = tabs.count >= 5 ? 30 : 26
        let fontPt = tabs.count >= 6 ? 12 : (tabs.count >= 5 ? 13 : (tabs.count >= 4 ? 14 : 15))
        let iconPx = tabs.count >= 6 ? 22 : 24
        let iconSpacing = tabs.count >= 5 ? 8 : 10
        let barSpacing = 4

        let itemShapeForIndex: (Int) -> UnevenRoundedRectangle = { idx in
            if tabs.count <= 1 {
                return UnevenRoundedRectangle(topLeadingRadius: 999, bottomLeadingRadius: 999, bottomTrailingRadius: 999, topTrailingRadius: 999)
            } else if idx == 0 {
                return UnevenRoundedRectangle(topLeadingRadius: 999, bottomLeadingRadius: 999, bottomTrailingRadius: 0, topTrailingRadius: 0)
            } else if idx == tabs.count - 1 {
                return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 999, topTrailingRadius: 999)
            } else {
                return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
            }
        }

        let selectTab: (SelectionValue) -> Void = { tag in
            guard selection.wrappedValue != tag else { return }
            if KindleKeyboardManager.shared.isVisible {
                KindleKeyboardManager.shared.dismiss()
            }
            kgtk_reset_scroll_position()
            if KindleDevice.shared.refreshPolicy.fullRefreshOnTabChange {
                KindleStateRegistry.shared.pendingFullRefresh = true
            }
            selection.wrappedValue = tag
            onTabChange?(tag)
        }

        let tabBar: RenderNode
        switch styleVariant {
        case .bottomBar:
            tabBar = HStack(alignment: .center, spacing: barSpacing, homogeneous: true) {
                ForEach(tabs.indices) { idx in
                    let tab = tabs[idx]
                    let isSelected = (tab.tag == current)
                    let labelTitle = tab.badge != nil ? "\(tab.title) (\(tab.badge!))" : tab.title
                    let pillBg = isSelected ? theme.foreground : theme.cardBackground
                    let itemShape = itemShapeForIndex(idx)
                    if let icon = tab.icon {
                        Button(action: { selectTab(tab.tag) }) {
                            HStack(alignment: .center, spacing: iconSpacing) {
                                Icon(icon, size: iconPx)
                                Text(labelTitle)
                                    .font(.system(size: fontPt, weight: .bold))
                                    .lineLimit(1)
                            }
                            .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: vPad, leading: hPad, bottom: vPad, trailing: hPad))
                        .background(pillBg)
                        .buttonStyle(isSelected ? .borderedProminent : .plain)
                        .clipShape(itemShape)
                        .expand(true, fill: true)
                    } else {
                        Button(labelTitle) {
                            selectTab(tab.tag)
                        }
                        .font(.system(size: fontPt, weight: .bold))
                        .padding(EdgeInsets(top: vPad + 2, leading: hPad, bottom: vPad + 2, trailing: hPad))
                        .background(pillBg)
                        .buttonStyle(isSelected ? .borderedProminent : .plain)
                        .clipShape(itemShape)
                        .expand(true, fill: true)
                    }
                }
            }
            .padding(6)
            .background(theme.subtleBorder, cornerRadius: 999)
            .padding(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .buildRenderTree()

        case .segmented:
            tabBar = HStack(alignment: .center, spacing: 4, homogeneous: true) {
                ForEach(tabs.indices) { idx in
                    let tab = tabs[idx]
                    let isSelected = (tab.tag == current)
                    let itemShape = itemShapeForIndex(idx)
                    if let icon = tab.icon {
                        Button(action: { selectTab(tab.tag) }) {
                            HStack(alignment: .center, spacing: 8) {
                                Icon(icon, size: 24)
                                Text(tab.title)
                                    .font(.system(size: fontPt, weight: .bold))
                            }
                            .expand(false, fill: false)
                        }
                        .buttonStyle(isSelected ? .borderedProminent : .plain)
                        .padding(EdgeInsets(top: 12, leading: hPad, bottom: 12, trailing: hPad))
                        .clipShape(itemShape)
                        .expand(true, fill: true)
                    } else {
                        Button(tab.title) {
                            selectTab(tab.tag)
                        }
                        .font(.system(size: fontPt, weight: .bold))
                        .buttonStyle(isSelected ? .borderedProminent : .plain)
                        .padding(EdgeInsets(top: 14, leading: hPad, bottom: 14, trailing: hPad))
                        .clipShape(itemShape)
                        .expand(true, fill: true)
                    }
                }
            }
            .padding(6)
            .background(theme.panelBackground, cornerRadius: 999)
            .border(theme.subtleBorder, width: 1, cornerRadius: 999)
            .padding(EdgeInsets(top: 4, leading: 24, bottom: 12, trailing: 24))
            .buildRenderTree()
        }

        let hideBottomBarForKeyboard = (styleVariant == .bottomBar && KindleKeyboardManager.shared.isVisible)
        return RenderNode.vstack(
            alignment: .leading,
            spacing: 8,
            children: hideBottomBarForKeyboard ? [activeNode] : [activeNode, tabBar],
            style: {
                var s = ViewStyle()
                s.expand = true
                s.fill = true
                return s
            }()
        )
    }
}
