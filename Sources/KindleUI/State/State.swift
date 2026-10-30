import Foundation

/// A property wrapper type that can read and write a value managed by KindleUI.
@propertyWrapper
public struct State<Value>: _StateProperty, @unchecked Sendable {
    internal let resolver: _StateResolver<Value>

    public init(
        wrappedValue value: @autoclosure @escaping () -> Value,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) {
        self.resolver = _StateResolver(
            siteKey: "\(fileID):\(line):\(column)",
            initialValue: value
        )
    }

    public init(
        initialValue value: @autoclosure @escaping () -> Value,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) {
        self.resolver = _StateResolver(
            siteKey: "\(fileID):\(line):\(column)",
            initialValue: value
        )
    }

    public func _bindToCurrentScope() {
        resolver.bindToCurrentScope()
    }

    internal var box: StateBox<Value> {
        resolver.box
    }

    public var wrappedValue: Value {
        get { resolver.box.value }
        nonmutating set { resolver.box.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        let r = resolver
        return Binding(
            get: { r.box.value },
            set: { r.box.value = $0 }
        )
    }
}

/// A property wrapper type that can read and write a value owned by a source of truth.
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value>: @unchecked Sendable {
    private let getter: () -> Value
    private let setter: (Value) -> Void

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    public var projectedValue: Binding<Value> {
        self
    }

    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let parent = self
        return Binding<Subject>(
            get: { parent.wrappedValue[keyPath: keyPath] },
            set: { parent.wrappedValue[keyPath: keyPath] = $0 }
        )
    }

    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let parent = self
        return Binding<Subject>(
            get: { parent.wrappedValue[keyPath: keyPath] },
            set: {
                parent.wrappedValue[keyPath: keyPath] = $0
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )
    }

    /// Creates a binding with an immutable value.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}

/// A property wrapper type that supports creating bindings to the mutable properties of `@Observable` objects.
@dynamicMemberLookup
@propertyWrapper
public struct Bindable<Value: AnyObject>: @unchecked Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Bindable<Value> {
        self
    }

    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let obj = wrappedValue
        return Binding<Subject>(
            get: { obj[keyPath: keyPath] },
            set: {
                obj[keyPath: keyPath] = $0
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )
    }
}
