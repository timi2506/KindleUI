import Foundation

// MARK: - PreferenceKey & EditMode

/// A named value produced by a view that flows upward to ancestor views in the hierarchy.
public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
    static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
}

/// Indicates whether the user is currently editing the contents of a `List` or `ForEach`.
public enum EditMode: String, Sendable, Equatable {
    case inactive
    case active
    case transient

    public var isEditing: Bool {
        self != .inactive
    }
}



// MARK: - PreferenceKey Modifiers (.preference, .onPreferenceChange) & .modelContainer

private struct _PreferenceWriterView<Content: View, K: PreferenceKey>: View, _PrimitiveView {
    typealias Body = Never
    let content: Content
    let value: K.Value

    func _makeNode() -> RenderNode {
        let node = content.buildRenderTree()
        KindleStateRegistry.shared.emitPreference(key: K.self, value: value)
        return node
    }
}

private struct _PreferenceReaderView<Content: View, K: PreferenceKey>: View, _PrimitiveView where K.Value: Equatable {
    typealias Body = Never
    let content: Content
    let siteID: String
    let action: (K.Value) -> Void

    func _makeNode() -> RenderNode {
        KindleStateRegistry.shared.withPreferenceObservation(
            key: K.self,
            siteID: siteID,
            evaluateChild: { content.buildRenderTree() },
            perform: action
        )
    }
}

extension View {
    /// Sets a value for the specified `PreferenceKey` that flows upward to ancestor views.
    public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View {
        _PreferenceWriterView<Self, K>(content: self, value: value)
    }

    /// Adds an action to perform when the specified `PreferenceKey` value changes in this view's subtree.
    public func onPreferenceChange<K: PreferenceKey>(
        _ key: K.Type = K.self,
        siteID: String = #fileID + ":\(#line)",
        perform action: @escaping (K.Value) -> Void
    ) -> some View where K.Value: Equatable {
        _PreferenceReaderView<Self, K>(content: self, siteID: siteID, action: action)
    }

    /// Injects a `ModelContainer` into the view hierarchy's environment for `@Query` and `@Environment(\.modelContext)`.
}
