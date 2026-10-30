import Foundation

// MARK: - @AppStorage (Persistent Kindle Settings)

/// Protocol for types that can be persisted via `@AppStorage`.
public protocol AppStorageConvertible {
    func toAppStorageString() -> String
    static func fromAppStorageString(_ raw: String) -> Self?
}

extension String: AppStorageConvertible {
    public func toAppStorageString() -> String { self }
    public static func fromAppStorageString(_ raw: String) -> String? { raw }
}

extension Int: AppStorageConvertible {
    public func toAppStorageString() -> String { String(self) }
    public static func fromAppStorageString(_ raw: String) -> Int? { Int(raw) }
}

extension Double: AppStorageConvertible {
    public func toAppStorageString() -> String { String(self) }
    public static func fromAppStorageString(_ raw: String) -> Double? { Double(raw) }
}

extension Bool: AppStorageConvertible {
    public func toAppStorageString() -> String { self ? "true" : "false" }
    public static func fromAppStorageString(_ raw: String) -> Bool? {
        switch raw.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }
}

extension RawRepresentable where Self: AppStorageConvertible, RawValue: AppStorageConvertible {
    public func toAppStorageString() -> String {
        rawValue.toAppStorageString()
    }
    public static func fromAppStorageString(_ raw: String) -> Self? {
        guard let decoded = RawValue.fromAppStorageString(raw) else { return nil }
        return Self(rawValue: decoded)
    }
}

/// A property wrapper that reflects a persistent value on disk (`/mnt/us/extensions/kindleui_storage.json`)
/// and invalidates the view whenever the value changes.
@propertyWrapper
public struct AppStorage<Value: AppStorageConvertible>: @unchecked Sendable {
    public let key: String
    public let defaultValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            guard let raw = KindleStateRegistry.shared.appStorageValue(forKey: key),
                  let decoded = Value.fromAppStorageString(raw) else {
                return defaultValue
            }
            return decoded
        }
        nonmutating set {
            KindleStateRegistry.shared.setAppStorageValue(newValue.toAppStorageString(), forKey: key)
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

/// A property wrapper that reads and writes per-scene persistent state backed by `KindleStateRegistry`.
@propertyWrapper
public struct SceneStorage<Value: AppStorageConvertible>: @unchecked Sendable {
    public let key: String
    public let defaultValue: Value

    public init(wrappedValue: Value, _ key: String) {
        self.key = "scene.\(key)"
        self.defaultValue = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            guard let raw = KindleStateRegistry.shared.appStorageValue(forKey: key),
                  let decoded = Value.fromAppStorageString(raw) else {
                return defaultValue
            }
            return decoded
        }
        nonmutating set {
            KindleStateRegistry.shared.setAppStorageValue(newValue.toAppStorageString(), forKey: key)
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
