import Foundation

/// Internal protocol allowing primitives to build a `RenderNode` directly without infinite recursion.
public protocol _PrimitiveView {
    func _makeNode() -> RenderNode
}

/// A type that represents part of your Kindle application's user interface
/// and provides modifiers that you use to configure views.
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never {
        fatalError("Never.body should never be called.")
    }
}

extension View where Body == Never {
    public var body: Never {
        fatalError("\(Self.self) is a primitive view; its body should not be evaluated directly.")
    }
}

extension View {
    /// Evaluates the view hierarchy into a concrete `RenderNode` tree.
    public func buildRenderTree() -> RenderNode {
        if let primitive = self as? _PrimitiveView {
            return primitive._makeNode()
        }
        KindleStateRegistry.shared.pushScope(String(reflecting: Self.self))
        defer { KindleStateRegistry.shared.popScope() }
        for child in Mirror(reflecting: self).children {
            if let stateProp = child.value as? _StateProperty {
                stateProp._bindToCurrentScope()
            }
        }
        return self.body.buildRenderTree()
    }
}



/// A view that doesn't contain any content.
public struct EmptyView: View, _PrimitiveView {
    public typealias Body = Never
    public init() {}
    public func _makeNode() -> RenderNode { .empty }
}

extension Optional: View, _PrimitiveView where Wrapped: View {
    public typealias Body = Never
    public func _makeNode() -> RenderNode {
        switch self {
        case .some(let wrapped):
            return wrapped.buildRenderTree()
        case .none:
            return .empty
        }
    }
}

/// A View created from a swift tuple of View values.
public struct TupleView<T>: View, _PrimitiveView {
    public typealias Body = Never
    private let builders: [() -> RenderNode]

    public init(_ nodes: [RenderNode]) {
        self.builders = nodes.map { node in { node } }
    }

    internal init(builders: [() -> RenderNode]) {
        self.builders = builders
    }

    public func _makeNode() -> RenderNode {
        .group(builders.map { $0() })
    }
}

/// A type-erased view.
public struct AnyView: View, _PrimitiveView {
    public typealias Body = Never
    private let builder: () -> RenderNode

    public init<V: View>(_ view: V) {
        self.builder = { view.buildRenderTree() }
    }

    internal init(node: RenderNode) {
        self.builder = { node }
    }

    public func _makeNode() -> RenderNode {
        builder()
    }
}

/// A type that collects multiple instances of a content type into a single unit.
public struct Group<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        content.buildRenderTree()
    }
}
