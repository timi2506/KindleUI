import Foundation
import CKindleGTK

/// A scrollable view (`gtk_scrolled_window_new`).
public struct ScrollView<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let showsIndicators: Bool
    private let content: Content

    public init(showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = true
        return .scrollView(showsIndicators: showsIndicators, child: content.buildRenderTree(), style: style)
    }
}



/// A proxy value that supports programmatic scrolling of the scrollable views within a view hierarchy.
public struct ScrollViewProxy: @unchecked Sendable {
    public init() {}

    /// Scrolls to the top, bottom, or the specified target anchor ID.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: Alignment? = nil) {
        if anchor == .bottom {
            kgtk_set_scroll_position(999_999.0)
        } else if anchor == .top {
            kgtk_reset_scroll_position()
        }
        KindleStateRegistry.shared.scrollRequestHandler?(AnyHashable(id))
        KindleStateRegistry.shared.notifyStateMutation()
    }
}

/// A view that provides programmatic scrolling, by working with a proxy to scroll to known child views.
public struct ScrollViewReader<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: (ScrollViewProxy) -> Content

    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        content(ScrollViewProxy()).buildRenderTree()
    }
}



// MARK: - 14. Modern ScrollView Modifiers (iOS 17 / iOS 18)

/// The visibility of scroll indicators of a UI element.
public enum ScrollIndicatorVisibility: String, Sendable, Equatable, CaseIterable {
    case automatic
    case visible
    case hidden
    case never
}

/// The scroll target behavior of a scrollable view.
public enum ScrollTargetBehavior: String, Sendable, Equatable, CaseIterable {
    case paging
    case viewAligned
}

extension View {
    /// Sets the visibility of scroll indicators within this view.
    public func scrollIndicators(
        _ visibility: ScrollIndicatorVisibility,
        axes: Axis.Set = [.vertical]
    ) -> Self {
        _ = visibility
        _ = axes
        return self
    }

    /// Sets the scroll target behavior for views within this scroll container.
    public func scrollTargetBehavior(_ behavior: ScrollTargetBehavior) -> Self {
        _ = behavior
        return self
    }

    /// Configures the outermost layout as a scroll target layout.
    public func scrollTargetLayout(isEnabled: Bool = true) -> Self {
        _ = isEnabled
        return self
    }

    /// Associates a binding to the scroll position item ID within a `ScrollView`.
    public func scrollPosition<ID: Hashable>(
        id: Binding<ID?>,
        anchor: Alignment? = nil
    ) -> some View {
        _ = anchor
        return self.onChange(of: id.wrappedValue) { target in
            if let target = target {
                KindleStateRegistry.shared.scrollRequestHandler?(AnyHashable(target))
            }
        }
    }

    /// Disables or enables scrolling in scrollable views.
    public func scrollDisabled(_ disabled: Bool) -> Self {
        _ = disabled
        return self
    }

    /// Configures whether a scroll view clips its content to its bounds.
    public func scrollClipDisabled(_ disabled: Bool = true) -> Self {
        _ = disabled
        return self
    }

    /// Associates an initial scroll anchor with a `ScrollView`.
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> Self {
        _ = anchor
        return self
    }
}
