import Foundation

/// An indication of a scene's operational state (`active`, `inactive`, or `background`).
public enum ScenePhase: String, Sendable, Equatable, CaseIterable {
    case active
    case inactive
    case background
}

/// The reasons to apply a redaction to data displayed on screen.
public struct RedactionReasons: OptionSet, Sendable, Equatable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Displayed data should appear as generic placeholders (skeleton bars).
    public static let placeholder = RedactionReasons(rawValue: 1 << 0)
    /// Displayed data should be obscured to protect private information.
    public static let privacy = RedactionReasons(rawValue: 1 << 1)
}

// MARK: - @Environment, EnvironmentKey & EnvironmentValues

/// A key for accessing values in the environment.
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

/// An action that dismisses the current presentation (`NavigationStack` destination, `.sheet`, `.fullScreenCover`, or `.alert`).
public struct DismissAction: Sendable {
    private let handler: @Sendable () -> Void

    public init(_ handler: @escaping @Sendable () -> Void = {}) {
        self.handler = handler
    }

    public func callAsFunction() {
        if let last = KindleStateRegistry.shared.activeDismissActions.last {
            last()
        } else {
            handler()
        }
    }
}



/// An action that opens a URL from the environment (`@Environment(\.openURL)`).
public struct OpenURLAction: Sendable {
    private let handler: @Sendable (URL) -> Void

    public init(handler: @escaping @Sendable (URL) -> Void = { _ in }) {
        self.handler = handler
    }

    public func callAsFunction(_ url: URL) {
        handler(url)
    }
}

/// A collection of environment values propagated through a KindleUI view hierarchy.
public struct EnvironmentValues: @unchecked Sendable {
    private var storage: [ObjectIdentifier: Any] = [:]
    private var objectStorage: [ObjectIdentifier: AnyObject] = [:]
    private var colorSchemeOverride: KindleColorScheme? = nil
    private var editModeBindingOverride: Binding<EditMode>? = nil
    private var modelContainerOverride: ModelContainer? = nil
    private var scenePhaseOverride: ScenePhase? = nil
    public var isEnabled: Bool = true
    public var redactionReasons: RedactionReasons = []
    public var keyboardType: UIKeyboardType = .default
    public var submitLabel: SubmitLabel = .done
    public var textInputAutocapitalization: TextInputAutocapitalization = .sentences
    public var autocorrectionDisabled: Bool = false
    public var isSearching: Bool = false
    public var dismissSearch: DismissAction = DismissAction()
    public var openURL: OpenURLAction = OpenURLAction()
    public var rename: (() -> Void)? = nil
    internal var activeFocusBridge: _FocusBridge? = nil
    internal var activeOnSubmit: (() -> Void)? = nil

    public var colorScheme: KindleColorScheme {
        get { colorSchemeOverride ?? KindleStateRegistry.shared.colorScheme }
        set { colorSchemeOverride = newValue }
    }

    public var scenePhase: ScenePhase {
        get {
            if let override = scenePhaseOverride {
                return override
            }
            if let state = KindleDevice.shared.getLipcString(service: "com.lab126.powerd", property: "state") {
                let lower = state.lowercased()
                if lower.contains("screen_saver") || lower.contains("suspended") {
                    return .background
                } else if lower.contains("ready_to_suspend") {
                    return .inactive
                }
            }
            return .active
        }
        set { scenePhaseOverride = newValue }
    }

    public var editMode: Binding<EditMode>? {
        get {
            if let override = editModeBindingOverride {
                return override
            }
            return Binding(
                get: { KindleStateRegistry.shared.defaultEditMode },
                set: {
                    KindleStateRegistry.shared.defaultEditMode = $0
                    KindleStateRegistry.shared.notifyStateMutation()
                }
            )
        }
        set { editModeBindingOverride = newValue }
    }

    public var modelContext: ModelContext {
        get {
            let container = modelContainerOverride
                ?? KindleStateRegistry.shared.defaultModelContainer
                ?? ModelContainer.shared
            return container.mainContext
        }
        set {
            modelContainerOverride = newValue.container
        }
    }

    public var dismiss: DismissAction {
        DismissAction()
    }

    public init() {}

    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get {
            if let val = storage[ObjectIdentifier(key)] as? K.Value {
                return val
            }
            return K.defaultValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    public mutating func setObservableObject<T: AnyObject>(_ object: T) {
        objectStorage[ObjectIdentifier(T.self)] = object
    }

    public func observableObject<T: AnyObject>(ofType type: T.Type) -> T? {
        objectStorage[ObjectIdentifier(type)] as? T
    }
}

/// A property wrapper that reads a value or `@Observable` object from a view's `EnvironmentValues`.
@propertyWrapper
public struct Environment<Value>: @unchecked Sendable {
    private let getter: () -> Value

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.getter = {
            KindleStateRegistry.shared.currentEnvironment[keyPath: keyPath]
        }
    }

    public init(_ type: Value.Type) where Value: AnyObject {
        self.getter = {
            guard let obj = KindleStateRegistry.shared.currentEnvironment.observableObject(ofType: type) else {
                fatalError("No @Observable object of type \(type) found in Environment. Apply .environment(\(type)(...)) to an ancestor view.")
            }
            return obj
        }
    }

    public init<T: AnyObject>(_ type: T.Type) where Value == T? {
        self.getter = {
            KindleStateRegistry.shared.currentEnvironment.observableObject(ofType: type)
        }
    }

    public var wrappedValue: Value {
        getter()
    }
}



extension View {
    // MARK: - Structural Identity (.id) & Environment (.environment)

    /// Binds a view's identity (and its `@State` / lifecycle scope) to the given hashable value.
    public func id<ID: Hashable>(_ id: ID) -> some View {
        _IDModifiedView(content: self, id: id)
    }

    /// Sets the environment value of the specified key path to the given value for this view's hierarchy.
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View {
        _EnvironmentModifiedView(content: self) { env in
            env[keyPath: keyPath] = value
        }
    }

    /// Places an `@Observable` object in the view hierarchy's environment so descendants can read it via `@Environment(T.self)`.
    public func environment<T: AnyObject>(_ object: T) -> some View {
        _EnvironmentModifiedView(content: self) { env in
            env.setObservableObject(object)
        }
    }

}

internal struct _IDModifiedView<Content: View, ID: Hashable>: View, _PrimitiveView {
    typealias Body = Never
    let content: Content
    let id: ID

    func _makeNode() -> RenderNode {
        KindleStateRegistry.shared.pushScope("id:\(id)")
        defer { KindleStateRegistry.shared.popScope() }
        return content.buildRenderTree().modifyingStyle { style in
            style.explicitID = AnyHashable(id)
        }
    }
}

internal struct _EnvironmentModifiedView<Content: View>: View, _PrimitiveView {
    typealias Body = Never
    let content: Content
    let transform: (inout EnvironmentValues) -> Void

    func _makeNode() -> RenderNode {
        KindleStateRegistry.shared.pushEnvironment(transform)
        defer { KindleStateRegistry.shared.popEnvironment() }
        return content.buildRenderTree()
    }
}
