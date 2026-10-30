import Foundation

// MARK: - @FocusState

/// A property wrapper type that can read and write a value that indicates the current focus location
/// of the native Kindle keyboard.
@propertyWrapper
public struct FocusState<Value: Hashable>: _StateProperty, @unchecked Sendable {
    @propertyWrapper
    public struct Binding: @unchecked Sendable {
        internal let resolver: _StateResolver<Value>

        internal var box: StateBox<Value> {
            resolver.box
        }

        public var wrappedValue: Value {
            get { resolver.box.value }
            nonmutating set {
                resolver.box.value = newValue
                if let b = newValue as? Bool, !b {
                    KindleKeyboardManager.shared.dismiss()
                } else if Mirror(reflecting: newValue).displayStyle == .optional,
                          Mirror(reflecting: newValue).children.isEmpty {
                    KindleKeyboardManager.shared.dismiss()
                }
            }
        }

        public var projectedValue: Binding { self }
    }

    internal let resolver: _StateResolver<Value>

    public init(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) where Value == Bool {
        self.resolver = _StateResolver(
            siteKey: "focus:\(fileID):\(line):\(column)",
            initialValue: { false }
        )
    }

    public init<T: Hashable>(
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) where Value == T? {
        self.resolver = _StateResolver(
            siteKey: "focus:\(fileID):\(line):\(column)",
            initialValue: { nil }
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
        nonmutating set {
            resolver.box.value = newValue
            if let b = newValue as? Bool, !b {
                KindleKeyboardManager.shared.dismiss()
            } else if Mirror(reflecting: newValue).displayStyle == .optional,
                      Mirror(reflecting: newValue).children.isEmpty {
                KindleKeyboardManager.shared.dismiss()
            }
        }
    }

    public var projectedValue: Binding {
        Binding(resolver: resolver)
    }
}


internal struct _FocusBridge: @unchecked Sendable {
    let isFocused: () -> Bool
    let setFocused: (Bool) -> Void
}

/// Keyboard layout types for text input controls (`TextField`, `SecureField`, `TextEditor`).
public enum UIKeyboardType: String, Sendable, Equatable, CaseIterable {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case emailAddress
    case decimalPad

    public var isNumeric: Bool {
        switch self {
        case .numbersAndPunctuation, .numberPad, .phonePad, .decimalPad:
            return true
        default:
            return false
        }
    }
}

/// A semantic label for the submit/return key on the keyboard.
public enum SubmitLabel: String, Sendable, Equatable, CaseIterable {
    case done = "Done"
    case go = "Go"
    case send = "Send"
    case join = "Join"
    case route = "Route"
    case search = "Search"
    case `return` = "Return"
    case next = "Next"
    case `continue` = "Continue"
}

/// Autocapitalization behavior for text input controls.
public enum TextInputAutocapitalization: String, Sendable, Equatable, CaseIterable {
    case never
    case words
    case sentences
    case characters
}
