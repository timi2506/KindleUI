import Foundation

extension View {
    // MARK: - Focus & Submit (.focused, .onSubmit)

    /// Binds this view's focus state to the given boolean focus state binding.
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        _EnvironmentModifiedView(content: self) { env in
            env.activeFocusBridge = _FocusBridge(
                isFocused: { condition.wrappedValue },
                setFocused: { newValue in
                    if condition.box.value != newValue {
                        condition.box.value = newValue
                    }
                }
            )
        }
    }

    /// Binds this view's focus state to the given optional hashable focus state binding when equal to `value`.
    public func focused<V: Hashable>(_ binding: FocusState<V?>.Binding, equals value: V) -> some View {
        _EnvironmentModifiedView(content: self) { env in
            env.activeFocusBridge = _FocusBridge(
                isFocused: { binding.wrappedValue == value },
                setFocused: { newValue in
                    if newValue {
                        if binding.box.value != value {
                            binding.box.value = value
                        }
                    } else if binding.box.value == value {
                        binding.box.value = nil
                    }
                }
            )
        }
    }

    /// Adds an action to perform when the user submits a value to this view (e.g. pressing Return or Done on the Kindle keyboard).
    public func onSubmit(_ action: @escaping () -> Void) -> some View {
        _EnvironmentModifiedView(
            content: ModifiedContent(content: self) { style in
                style.onSubmitHandler = action
            }
        ) { env in
            env.activeOnSubmit = action
        }
    }

    // MARK: - .searchable & .refreshable

    /// Marks this view as searchable and renders a Kindle E-Ink search bar at the top of the view.
    public func searchable(
        text: Binding<String>,
        prompt: String = "Search…",
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        let theme = KindleTheme.current
        let isSearchingActive = !text.wrappedValue.isEmpty
        let clearAction = DismissAction {
            text.wrappedValue = ""
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Icon(.search, size: 24)
                    .foregroundColor(theme.mutedForeground)
                TextField(prompt, text: text, onCommit: onSubmit)
                if isSearchingActive {
                    Button("Clear") {
                        text.wrappedValue = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
            .background(theme.cardBackground, cornerRadius: 16)
            .border(theme.subtleBorder, width: 1, cornerRadius: 16)

            self
                .environment(\.isSearching, isSearchingActive)
                .environment(\.dismissSearch, clearAction)
        }
        .expand(true, fill: true)
    }

    /// Marks this view as refreshable and adds an E-Ink refresh bar + pull-down swipe gesture.
    public func refreshable(action: @escaping @Sendable () async -> Void) -> some View {
        let trigger: () -> Void = {
            Task {
                await action()
                KindleStateRegistry.shared.notifyStateMutation()
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("Swipe down or tap Refresh to reload")
                    .font(.caption)
                Spacer()
                Button(action: trigger) {
                    Label("Refresh", icon: .refresh, iconSize: 30, spacing: 8)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            self
        }
        .onSwipeGesture(onDown: trigger)
        .expand(false, fill: true)
    }

}

// MARK: - 15. Search Suggestions, Scopes & Text Input Modifiers

extension View {
    /// Configures the search suggestions for a `.searchable` view.
    public func searchSuggestions<Suggestions: View>(
        @ViewBuilder _ suggestions: () -> Suggestions
    ) -> some View {
        let theme = KindleTheme.current
        let isSearching = KindleStateRegistry.shared.currentEnvironment.isSearching
        return VStack(alignment: .leading, spacing: 10) {
            if isSearching {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUGGESTIONS")
                        .font(.caption)
                        .foregroundColor(theme.mutedForeground)
                    suggestions()
                }
                .padding(12)
                .background(theme.panelBackground, cornerRadius: 12)
                .border(theme.subtleBorder, width: 2, cornerRadius: 12)
            }
            self
        }
    }

    /// Configures the search scopes for a `.searchable` view.
    public func searchScopes<ScopeValue: Equatable & CaseIterable & RawRepresentable, Scopes: View>(
        _ scope: Binding<ScopeValue>,
        @ViewBuilder scopes: () -> Scopes
    ) -> some View where ScopeValue.RawValue == String {
        _ = scopes()
        return VStack(alignment: .leading, spacing: 10) {
            Picker(selection: scope)
                .pickerStyle(.segmented)
            self
        }
    }

    /// Sets the keyboard type for text input controls within this view (e.g. `.numberPad`, `.decimalPad`, `.emailAddress`).
    public func keyboardType(_ type: UIKeyboardType) -> some View {
        self.environment(\.keyboardType, type)
    }

    /// Sets the semantic submit label for the keyboard when editing text within this view.
    public func submitLabel(_ submitLabel: SubmitLabel) -> some View {
        self.environment(\.submitLabel, submitLabel)
    }

    /// Sets how often the shift key is automatically enabled during text input.
    public func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View {
        self.environment(\.textInputAutocapitalization, autocapitalization ?? .never)
    }

    /// Sets whether to disable autocorrection for this view.
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View {
        self.environment(\.autocorrectionDisabled, disable)
    }
}



// MARK: - 18. Sensory Feedback & Accessibility Modifiers

/// Represents patterns of sensory feedback (mapped on Kindle E-Ink to optional waveform pulses).
public enum SensoryFeedback: String, Sendable, Equatable, CaseIterable {
    case impact
    case selection
    case success
    case warning
    case error
    case increase
    case decrease
}

extension View {
    /// Plays the specified `feedback` when the provided `trigger` value changes.
    public func sensoryFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T
    ) -> some View {
        self.onChange(of: trigger) { _ in
            if feedback == .warning || feedback == .error {
                KindleDevice.shared.refreshScreen(full: true)
            }
        }
    }

    /// Adds a label to the view that describes its contents for accessibility.
    public func accessibilityLabel(_ label: String) -> Self {
        _ = label
        return self
    }

    /// Adds a textual description of the value that the view contains for accessibility.
    public func accessibilityValue(_ value: String) -> Self {
        _ = value
        return self
    }

    /// Communicates to the user what happens after performing the view's action.
    public func accessibilityHint(_ hint: String) -> Self {
        _ = hint
        return self
    }

    /// Specifies whether to hide this view from system accessibility features.
    public func accessibilityHidden(_ hidden: Bool) -> Self {
        _ = hidden
        return self
    }
}
