import Foundation
import CKindleGTK

// MARK: - NavigationStack, NavigationView, NavigationLink & NavigationPath

/// A type-erased list of data representing the content of a navigation stack.
public struct NavigationPath: Equatable, @unchecked Sendable {
    internal var elements: [AnyHashable] = []

    public init() {}

    public init<S: Sequence>(_ elements: S) where S.Element: Hashable {
        self.elements = elements.map { AnyHashable($0) }
    }

    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }

    public mutating func append<V: Hashable>(_ value: V) {
        elements.append(AnyHashable(value))
    }

    public mutating func removeLast(_ k: Int = 1) {
        let n = min(max(0, k), elements.count)
        elements.removeLast(n)
    }
}

/// Represents a pushed destination on a `NavigationStack`.
public struct NavigationEntry {
    public let title: String
    internal let makeNode: () -> RenderNode

    public init<V: View>(title: String = "", @ViewBuilder content: @escaping () -> V) {
        self.title = title
        self.makeNode = { content().buildRenderTree() }
    }
}

/// Manages a stack of pushed views and value-based destination resolvers for `NavigationStack`.
public final class KindleNavigationStorage: @unchecked Sendable {
    public static let shared = KindleNavigationStorage()

    private var stacks: [String: [NavigationEntry]] = [:]
    internal var destinationResolvers: [String: [ObjectIdentifier: (AnyHashable) -> RenderNode]] = [:]
    internal var activePathBindings: [String: Binding<NavigationPath>] = [:]
    internal var activeStackID: String = "default"

    private init() {}

    public func entries(for stackID: String) -> [NavigationEntry] {
        stacks[stackID] ?? []
    }

    internal func registerDestination<D: Hashable>(
        for type: D.Type,
        stackID: String? = nil,
        builder: @escaping (D) -> RenderNode
    ) {
        let id = stackID ?? activeStackID
        var map = destinationResolvers[id] ?? [:]
        map[ObjectIdentifier(type)] = { anyVal in
            guard let typed = anyVal.base as? D else { return .empty }
            return builder(typed)
        }
        destinationResolvers[id] = map
    }

    internal func resolveDestination(for value: AnyHashable, stackID: String? = nil) -> RenderNode? {
        let id = stackID ?? activeStackID
        let typeID = ObjectIdentifier(type(of: value.base))
        if let resolver = destinationResolvers[id]?[typeID] {
            return resolver(value)
        }
        for (_, map) in destinationResolvers {
            if let resolver = map[typeID] {
                return resolver(value)
            }
        }
        return nil
    }

    public func push(_ entry: NavigationEntry, stackID: String? = nil) {
        KindleKeyboardManager.shared.dismiss()
        let id = stackID ?? activeStackID
        var list = stacks[id] ?? []
        list.append(entry)
        stacks[id] = list
        kgtk_reset_scroll_position()
        if KindleDevice.shared.refreshPolicy.fullRefreshOnTabChange {
            KindleStateRegistry.shared.pendingFullRefresh = true
        }
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func pushValue<V: Hashable>(_ value: V, title: String = "", stackID: String? = nil) {
        KindleKeyboardManager.shared.dismiss()
        let id = stackID ?? activeStackID
        if let pathBinding = activePathBindings[id] {
            var current = pathBinding.wrappedValue
            current.append(value)
            pathBinding.wrappedValue = current
            kgtk_reset_scroll_position()
            if KindleDevice.shared.refreshPolicy.fullRefreshOnTabChange {
                KindleStateRegistry.shared.pendingFullRefresh = true
            }
            return
        }
        let anyVal = AnyHashable(value)
        let fallbackTitle = title.isEmpty ? "\(value)" : title
        push(
            NavigationEntry(title: fallbackTitle) {
                AnyView(
                    node: KindleNavigationStorage.shared.resolveDestination(for: anyVal, stackID: id)
                        ?? Text(fallbackTitle).font(.headline).buildRenderTree()
                )
            },
            stackID: id
        )
    }

    public func pop(stackID: String? = nil) {
        KindleKeyboardManager.shared.dismiss()
        let id = stackID ?? activeStackID
        if let pathBinding = activePathBindings[id], !pathBinding.wrappedValue.isEmpty {
            var current = pathBinding.wrappedValue
            current.removeLast()
            pathBinding.wrappedValue = current
            kgtk_reset_scroll_position()
            if KindleDevice.shared.refreshPolicy.fullRefreshOnTabChange {
                KindleStateRegistry.shared.pendingFullRefresh = true
            }
            return
        }
        guard var list = stacks[id], !list.isEmpty else { return }
        list.removeLast()
        stacks[id] = list
        kgtk_reset_scroll_position()
        if KindleDevice.shared.refreshPolicy.fullRefreshOnTabChange {
            KindleStateRegistry.shared.pendingFullRefresh = true
        }
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func popToRoot(stackID: String? = nil) {
        KindleKeyboardManager.shared.dismiss()
        let id = stackID ?? activeStackID
        if let pathBinding = activePathBindings[id], !pathBinding.wrappedValue.isEmpty {
            pathBinding.wrappedValue = NavigationPath()
        }
        stacks[id] = []
        kgtk_reset_scroll_position()
        KindleStateRegistry.shared.pendingFullRefresh = true
        KindleStateRegistry.shared.notifyStateMutation()
    }
}

/// A view that displays a root view and enables presentation of additional views over the root view.
public struct NavigationStack<Root: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let stackID: String
    private let pathBinding: Binding<NavigationPath>?
    private let root: () -> Root

    public init(id: String = "default", @ViewBuilder root: @escaping () -> Root) {
        self.stackID = id
        self.pathBinding = nil
        self.root = root
    }

    public init(id: String = "default", path: Binding<NavigationPath>, @ViewBuilder root: @escaping () -> Root) {
        self.stackID = id
        self.pathBinding = path
        self.root = root
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let prevID = KindleNavigationStorage.shared.activeStackID
        KindleNavigationStorage.shared.activeStackID = stackID
        if let pathBinding = pathBinding {
            KindleNavigationStorage.shared.activePathBindings[stackID] = pathBinding
        } else {
            KindleNavigationStorage.shared.activePathBindings.removeValue(forKey: stackID)
        }
        defer { KindleNavigationStorage.shared.activeStackID = prevID }

        // Evaluate root first so any .navigationDestination(for:) modifiers register their builders.
        let rootNode = root().buildRenderTree()

        let pathElements = pathBinding?.wrappedValue.elements ?? []
        let stack = KindleNavigationStorage.shared.entries(for: stackID)
        let totalDepth = pathElements.count + stack.count

        if let topEntry = stack.last {
            let sid = stackID
            KindleStateRegistry.shared.activeDismissActions.append {
                KindleNavigationStorage.shared.pop(stackID: sid)
            }
            let destNode = topEntry.makeNode()
            return buildPushedStackContainer(
                destNode: destNode,
                fallbackTitle: topEntry.title,
                depth: totalDepth,
                stackID: sid,
                theme: theme
            )
        } else if let topValue = pathElements.last {
            let sid = stackID
            KindleStateRegistry.shared.activeDismissActions.append {
                KindleNavigationStorage.shared.pop(stackID: sid)
            }
            let destNode = KindleNavigationStorage.shared.resolveDestination(for: topValue, stackID: sid)
                ?? Text("\(topValue.base)").font(.headline).buildRenderTree()
            return buildPushedStackContainer(
                destNode: destNode,
                fallbackTitle: "\(topValue.base)",
                depth: totalDepth,
                stackID: sid,
                theme: theme
            )
        } else {
            let navTitle = rootNode.extractedNavigationTitle
            let toolbarItems = rootNode.extractedToolbarNodes
            if (navTitle != nil && !(navTitle?.isEmpty ?? true)) || !toolbarItems.isEmpty {
                let header = HStack(alignment: .center, spacing: 16) {
                    if let navTitle = navTitle, !navTitle.isEmpty {
                        Text(navTitle)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(theme.foreground)
                    }
                    Spacer()
                    if !toolbarItems.isEmpty {
                        AnyView(
                            node: .hstack(
                                alignment: .center,
                                spacing: 12,
                                children: toolbarItems,
                                style: {
                                    var s = ViewStyle()
                                    s.expand = false
                                    s.fill = false
                                    return s
                                }()
                            )
                        )
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                .buildRenderTree()

                return RenderNode.vstack(
                    alignment: .leading,
                    spacing: 16,
                    children: [header, rootNode],
                    style: {
                        var s = ViewStyle()
                        s.expand = true
                        s.fill = true
                        return s
                    }()
                )
            }
            return rootNode
        }
    }

    private func buildPushedStackContainer(
        destNode: RenderNode,
        fallbackTitle: String,
        depth: Int,
        stackID sid: String,
        theme: KindleTheme
    ) -> RenderNode {
        let resolvedTitle = destNode.extractedNavigationTitle ?? (fallbackTitle.isEmpty ? "Details" : fallbackTitle)
        let toolbarItems = destNode.extractedToolbarNodes

        let navBar = HStack(alignment: .center, spacing: 20) {
            Button("← Back") {
                KindleNavigationStorage.shared.pop(stackID: sid)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(resolvedTitle)
                .font(.title2)
                .foregroundColor(theme.foreground)

            Spacer()

            if !toolbarItems.isEmpty {
                AnyView(
                    node: .hstack(
                        alignment: .center,
                        spacing: 12,
                        children: toolbarItems,
                        style: {
                            var s = ViewStyle()
                            s.expand = false
                            s.fill = false
                            return s
                        }()
                    )
                )
            }

            if depth > 1 {
                Button("Root") {
                    KindleNavigationStorage.shared.popToRoot(stackID: sid)
                }
                .buttonStyle(.unbordered)
                .controlSize(.small)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
        .buildRenderTree()

        return RenderNode.vstack(
            alignment: .leading,
            spacing: 16,
            children: [
                navBar,
                Divider(thickness: 2, color: theme.subtleBorder).buildRenderTree(),
                destNode
            ],
            style: {
                var s = ViewStyle()
                s.expand = true
                s.fill = true
                return s
            }()
        )
    }
}

/// Alias matching SwiftUI's `NavigationView`.
public typealias NavigationView<Root: View> = NavigationStack<Root>

/// A view that controls a navigation presentation inside a `NavigationStack`.
public struct NavigationLink<LabelView: View, Destination: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    private let destination: (() -> Destination)?
    private let pushedValue: AnyHashable?
    private let labelView: LabelView?

    public init(
        _ title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) where LabelView == EmptyView {
        self.title = title
        self.destination = destination
        self.pushedValue = nil
        self.labelView = nil
    }

    public init(
        title: String = "",
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> LabelView
    ) {
        self.title = title
        self.destination = destination
        self.pushedValue = nil
        self.labelView = label()
    }

    public init<V: Hashable>(
        _ title: String,
        value: V
    ) where LabelView == EmptyView, Destination == EmptyView {
        self.title = title
        self.destination = nil
        self.pushedValue = AnyHashable(value)
        self.labelView = nil
    }

    public init<V: Hashable>(
        value: V,
        @ViewBuilder label: () -> LabelView
    ) where Destination == EmptyView {
        self.title = "\(value)"
        self.destination = nil
        self.pushedValue = AnyHashable(value)
        self.labelView = label()
    }

    public func _makeNode() -> RenderNode {
        let stackID = KindleNavigationStorage.shared.activeStackID
        let destClosure = destination
        let navTitle = title
        let valToPush = pushedValue

        let pushAction: () -> Void = {
            if let valToPush = valToPush {
                KindleNavigationStorage.shared.pushValue(valToPush, title: navTitle, stackID: stackID)
            } else if let destClosure = destClosure {
                KindleNavigationStorage.shared.push(
                    NavigationEntry(title: navTitle, content: destClosure),
                    stackID: stackID
                )
            }
        }

        if let labelView = labelView {
            return Button(action: pushAction) {
                labelView
            }
            .buttonStyle(.plain)
            .expand(false, fill: true)
            .buildRenderTree()
        } else {
            return Button(action: pushAction) {
                HStack(alignment: .center, spacing: 12) {
                    Text(title)
                        .font(.headline)
                    Icon(.chevronRight, size: 28)
                }
            }
            .buttonStyle(.bordered)
            .expand(false, fill: false)
            .buildRenderTree()
        }
    }
}

extension View {
    /// Associates a destination view with a presented data type for use within a `NavigationStack`.
    public func navigationDestination<D: Hashable, C: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        KindleNavigationStorage.shared.registerDestination(for: data) { val in
            destination(val).buildRenderTree()
        }
        return self
    }
}
