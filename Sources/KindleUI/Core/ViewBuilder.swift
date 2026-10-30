import Foundation

/// A custom parameter attribute that constructs KindleUI views from closures, matching SwiftUI's `@ViewBuilder`.
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<[RenderNode]> {
        var builders: [() -> RenderNode] = []
        repeat builders.append({ (each content).buildRenderTree() })
        return TupleView(builders: builders)
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> Content? {
        content
    }

    public static func buildEither<Content: View>(first component: Content) -> AnyView {
        AnyView(component)
    }

    public static func buildEither<Content: View>(second component: Content) -> AnyView {
        AnyView(component)
    }

    public static func buildArray<Content: View>(_ components: [Content]) -> TupleView<[RenderNode]> {
        TupleView(builders: components.map { item in { item.buildRenderTree() } })
    }
}
