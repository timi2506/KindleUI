import Foundation
import CKindleGTK

// MARK: - 12. Legacy Combine-Style Observation, @GestureState & @ScaledMetric

/// A publisher that emits before an `ObservableObject` has changed.
public final class ObservableObjectPublisher: @unchecked Sendable {
    public init() {}

    public func send() {
        KindleStateRegistry.shared.notifyStateMutation()
    }
}

/// A type of object with a publisher that emits before the object has changed.
public protocol ObservableObject: AnyObject {
    var objectWillChange: ObservableObjectPublisher { get }
}

extension ObservableObject {
    public var objectWillChange: ObservableObjectPublisher {
        ObservableObjectPublisher()
    }
}

/// A property wrapper that publishes changes to an `ObservableObject` property and triggers a KindleUI view update.
@propertyWrapper
public struct Published<Value>: @unchecked Sendable {
    private var storage: Value

    public init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    public var wrappedValue: Value {
        get { storage }
        set {
            storage = newValue
            KindleStateRegistry.shared.notifyStateMutation()
        }
    }

    public var projectedValue: Binding<Value> {
        var copy = self
        return Binding(
            get: { copy.storage },
            set: {
                copy.storage = $0
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )
    }
}

/// A property wrapper type that instantiates an observable object and preserves it across render passes.
@propertyWrapper
public struct StateObject<ObjectType: AnyObject>: _StateProperty, @unchecked Sendable {
    private let resolver: _StateResolver<ObjectType>

    public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {
        self.resolver = _StateResolver(siteKey: "stateobj", initialValue: thunk)
    }

    public func _bindToCurrentScope() {
        resolver.bindToCurrentScope()
    }

    public var wrappedValue: ObjectType {
        resolver.box.value
    }

    public var projectedValue: Bindable<ObjectType> {
        Bindable(wrappedValue)
    }
}

/// A property wrapper type that subscribes to an observable object and invalidates a view whenever the observable object changes.
@propertyWrapper
public struct ObservedObject<ObjectType: AnyObject>: @unchecked Sendable {
    public var wrappedValue: ObjectType

    public init(wrappedValue: ObjectType) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Bindable<ObjectType> {
        Bindable(wrappedValue)
    }
}

/// A property wrapper type for an observable object supplied by a parent or ancestor view via `.environmentObject(_:)`.
@propertyWrapper
public struct EnvironmentObject<ObjectType: AnyObject>: @unchecked Sendable {
    public init() {}

    public var wrappedValue: ObjectType {
        guard let obj = KindleStateRegistry.shared.currentEnvironment.observableObject(ofType: ObjectType.self) else {
            fatalError("No ObservableObject of type \(ObjectType.self) found in environment. Apply .environmentObject(...) to an ancestor view.")
        }
        return obj
    }

    public var projectedValue: Bindable<ObjectType> {
        Bindable(wrappedValue)
    }
}

extension View {
    /// Supplies an `ObservableObject` to a view hierarchy's environment.
    public func environmentObject<T: AnyObject>(_ object: T) -> some View {
        self.environment(object)
    }
}

/// A property wrapper type that updates a property while the user performs a gesture and resets the property back to its initial state when the gesture ends.
@propertyWrapper
public struct GestureState<Value>: _StateProperty, @unchecked Sendable {
    private let initialValue: Value
    private let resolver: _StateResolver<Value>

    public init(wrappedValue: Value) {
        self.initialValue = wrappedValue
        self.resolver = _StateResolver(siteKey: "gesturestate", initialValue: { wrappedValue })
    }

    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    public func _bindToCurrentScope() {
        resolver.bindToCurrentScope()
    }

    public var wrappedValue: Value {
        resolver.box.value
    }

    public var projectedValue: GestureState<Value> {
        self
    }

    internal func _update(_ newValue: Value) {
        resolver.box.value = newValue
        KindleStateRegistry.shared.notifyStateMutation()
    }

    internal func _reset() {
        resolver.box.value = initialValue
        KindleStateRegistry.shared.notifyStateMutation()
    }
}

extension DragGesture {
    /// Updates the provided `@GestureState` property as the drag gesture's value changes, resetting it when the drag ends.
    public func updating<State>(_ state: GestureState<State>, body: @escaping @Sendable (Value, inout State, inout Transaction) -> Void) -> DragGesture {
        self
            .onChanged { val in
                var current = state.wrappedValue
                var tx = Transaction()
                body(val, &current, &tx)
                state._update(current)
            }
            .onEnded { _ in
                state._reset()
            }
    }
}

/// A dynamic property that scales a numeric value according to the Kindle device UI scale factor.
@propertyWrapper
public struct ScaledMetric<Value: BinaryFloatingPoint>: Sendable {
    private let baseValue: Double

    public init(wrappedValue: Value) {
        self.baseValue = Double(wrappedValue)
    }

    public init(wrappedValue: Value, relativeTo textStyle: KindleFont) {
        _ = textStyle
        self.baseValue = Double(wrappedValue)
    }

    public var wrappedValue: Value {
        let scale = max(0.5, kgtk_get_ui_scale())
        return Value(baseValue * scale)
    }
}
