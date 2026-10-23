import Foundation

/// Central reactive state registry and runtime coordinator for KindleUI.
public final class KindleStateRegistry: @unchecked Sendable {
    public static let shared = KindleStateRegistry()

    private var slots: [Int: AnyObject] = [:]
    private var currentSlotIndex: Int = 0
    public private(set) var isEvaluatingBody: Bool = false
    public var onStateDidChange: (() -> Void)?

    private init() {}

    public func beginRenderPass() {
        isEvaluatingBody = true
        currentSlotIndex = 0
    }

    public func endRenderPass() {
        isEvaluatingBody = false
    }

    public func resetAllState() {
        slots.removeAll()
        currentSlotIndex = 0
    }

    internal func obtainBox<Value>(initialValue: Value) -> StateBox<Value> {
        if isEvaluatingBody {
            let slot = currentSlotIndex
            currentSlotIndex += 1
            if let existing = slots[slot] as? StateBox<Value> {
                return existing
            }
            let created = StateBox<Value>(initialValue)
            slots[slot] = created
            return created
        } else {
            let created = StateBox<Value>(initialValue)
            return created
        }
    }

    internal func notifyStateMutation() {
        onStateDidChange?()
    }
}

/// Reference-type storage box backing a `@State` property.
public final class StateBox<Value>: @unchecked Sendable {
    public var value: Value {
        didSet {
            KindleStateRegistry.shared.notifyStateMutation()
        }
    }

    public init(_ initialValue: Value) {
        self.value = initialValue
    }
}

/// A property wrapper type that can read and write a value managed by KindleUI.
///
/// Use `@State` just like in SwiftUI:
/// ```swift
/// struct CounterView: View {
///     @State private var count = 0
///     var body: some View {
///         VStack {
///             Text("Count: \(count)")
///             Button("Increment") { count += 1 }
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct State<Value>: @unchecked Sendable {
    internal let box: StateBox<Value>

    public init(wrappedValue value: Value) {
        self.box = KindleStateRegistry.shared.obtainBox(initialValue: value)
    }

    public init(initialValue value: Value) {
        self.box = KindleStateRegistry.shared.obtainBox(initialValue: value)
    }

    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { box.value },
            set: { box.value = $0 }
        )
    }
}

/// A property wrapper type that can read and write a value owned by a source of truth.
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

    /// Creates a binding with an immutable value.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}
