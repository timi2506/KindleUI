import Foundation
import CKindleGTK

/// A control that displays an editable E-Ink text interface with automatic on-screen keyboard support.
public struct TextField: View, _PrimitiveView {
    public typealias Body = Never
    public let placeholder: String
    public let text: Binding<String>
    public let onCommit: (() -> Void)?
    internal var isSecure: Bool = false

    public init(_ placeholder: String, text: Binding<String>, onCommit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.onCommit = onCommit
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let env = KindleStateRegistry.shared.currentEnvironment
        let submitHandler = env.activeOnSubmit ?? onCommit
        let focusBridge = env.activeFocusBridge
        let binding = text
        let currentVal = binding.wrappedValue
        let title = placeholder.isEmpty ? (isSecure ? "SecureField" : "TextField") : placeholder
        let secure = isSecure
        let kbLayout = env.keyboardType.isNumeric ? "123" : "abc"

        KindleKeyboardManager.shared.registerDefaultField(
            title: title,
            text: currentVal,
            isSecure: secure,
            isMultiline: false,
            onSubmit: submitHandler
        ) { updated in
            binding.wrappedValue = updated
        }
        KindleKeyboardManager.shared.markActiveFieldSeen(title)

        if let focusBridge = focusBridge,
           focusBridge.isFocused(),
           !KindleKeyboardManager.shared.isFieldFocused(title),
           !KindleStateRegistry.shared.suppressSideEffects {
            KindleKeyboardManager.shared.present(
                title: title,
                text: currentVal,
                isSecure: secure,
                isMultiline: false,
                fieldID: title,
                layout: kbLayout,
                notifyMutation: false,
                onSubmit: submitHandler,
                onDismiss: {
                    focusBridge.setFocused(false)
                }
            ) { updated in
                binding.wrappedValue = updated
            }
        }

        let displayStr: String
        if currentVal.isEmpty {
            displayStr = placeholder.isEmpty ? "Tap to enter text…" : placeholder
        } else if secure {
            displayStr = String(repeating: "•", count: currentVal.count)
        } else {
            displayStr = currentVal
        }

        let isFocused = KindleKeyboardManager.shared.isFieldFocused(title) || (focusBridge?.isFocused() ?? false)

        return Button(action: {
            if KindleKeyboardManager.shared.isFieldFocused(title) {
                submitHandler?()
                KindleKeyboardManager.shared.dismiss()
                focusBridge?.setFocused(false)
            } else {
                focusBridge?.setFocused(true)
                KindleKeyboardManager.shared.present(
                    title: title,
                    text: binding.wrappedValue,
                    isSecure: secure,
                    isMultiline: false,
                    fieldID: title,
                    layout: kbLayout,
                    onSubmit: submitHandler,
                    onDismiss: {
                        focusBridge?.setFocused(false)
                    }
                ) { updated in
                    binding.wrappedValue = updated
                }
            }
        }) {
            HStack(alignment: .center, spacing: 14) {
                Text(isFocused ? (displayStr + " ▌") : displayStr)
                    .lineLimit(1)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(currentVal.isEmpty ? theme.mutedForeground : theme.foreground)
                Spacer()
                if isFocused {
                    Badge("Done", prominent: true)
                }
            }
        }
        .buttonStyle(.bordered)
        .padding(EdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18))
        .frame(maxWidth: .infinity)
        .buildRenderTree()
    }
}



// MARK: - Built-In E-Ink On-Screen Keyboard & Text Input Controls

/// Coordinates the built-in high-contrast E-Ink Virtual Keyboard for `TextField`, `SecureField`, and `TextEditor`.
public final class KindleKeyboardManager: @unchecked Sendable {
    public static let shared = KindleKeyboardManager()

    public private(set) var isVisible: Bool = false
    public private(set) var activeFieldID: String? = nil
    public private(set) var fieldTitle: String = "Text Input"
    public private(set) var currentText: String = ""
    public private(set) var isSecure: Bool = false
    public private(set) var isMultiline: Bool = false
    public private(set) var isShift: Bool = false
    public private(set) var isSymbols: Bool = false
    public private(set) var showMaskedText: Bool = false

    private var onUpdate: ((String) -> Void)?
    private var onSubmit: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var fallbackTitle: String = "Scratchpad"
    private var fallbackText: String = ""
    private var fallbackIsSecure: Bool = false
    private var fallbackIsMultiline: Bool = false
    private var fallbackOnSubmit: (() -> Void)?
    private var fallbackOnUpdate: ((String) -> Void)?
    private var nativeKeyboardWatchTask: Task<Void, Never>? = nil
    internal private(set) var interactionGeneration: UInt64 = 0
    internal private(set) var activeFieldSeenInTopLayer: Bool = false

    internal enum PendingNativeKBAction {
        case none
        case open(layout: String)
        case close
    }
    internal var pendingNativeKBAction: PendingNativeKBAction = .none

    private init() {}

    internal func flushPendingNativeKeyboardAction() {
        let action = pendingNativeKBAction
        pendingNativeKBAction = .none
        switch action {
        case .none:
            break
        case .open(let layout):
            KindleDevice.shared.openNativeSystemKeyboard(layout: layout)
            startNativeKeyboardWatchIfNeeded()
        case .close:
            KindleDevice.shared.closeNativeSystemKeyboard()
        }
    }

    public func isFieldFocused(_ id: String) -> Bool {
        isVisible && activeFieldID == id
    }

    internal func beginRenderPass() {
        fallbackOnUpdate = nil
        fallbackOnSubmit = nil
        activeFieldSeenInTopLayer = false
    }

    internal func markActiveFieldSeen(_ id: String) {
        if isVisible && activeFieldID == id {
            activeFieldSeenInTopLayer = true
        }
    }

    internal func didEnterModalLayer() {
        activeFieldSeenInTopLayer = false
    }

    internal func endRenderPassCheck() {
        guard isVisible else { return }
        if let activeID = activeFieldID,
           (activeID.hasPrefix("webview:") || activeID == "Kindle Scratchpad") {
            return
        }
        if !activeFieldSeenInTopLayer {
            dismiss()
        }
    }

    internal func registerDefaultField(
        title: String,
        text: String,
        isSecure: Bool,
        isMultiline: Bool,
        onSubmit: (() -> Void)? = nil,
        onUpdate: @escaping (String) -> Void
    ) {
        self.fallbackTitle = title
        self.fallbackText = text
        self.fallbackIsSecure = isSecure
        self.fallbackIsMultiline = isMultiline
        self.fallbackOnSubmit = onSubmit
        self.fallbackOnUpdate = onUpdate
    }

    public func present(
        title: String,
        text: String,
        isSecure: Bool = false,
        isMultiline: Bool = false,
        fieldID: String? = nil,
        layout: String = "abc",
        notifyMutation: Bool = true,
        onSubmit: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onUpdate: @escaping (String) -> Void
    ) {
        self.activeFieldID = fieldID ?? title
        self.fieldTitle = title
        self.currentText = text
        self.isSecure = isSecure
        self.isMultiline = isMultiline
        self.showMaskedText = false
        self.isShift = text.isEmpty
        self.isSymbols = (layout == "123")
        self.onSubmit = onSubmit
        self.onDismiss = onDismiss
        self.onUpdate = onUpdate
        self.isVisible = true
        self.activeFieldSeenInTopLayer = true
        self.interactionGeneration &+= 1
        self.pendingNativeKBAction = .open(layout: layout)
        if notifyMutation {
            KindleStateRegistry.shared.notifyStateMutation()
        }
        if KindleStateRegistry.shared.onStateDidChange == nil {
            flushPendingNativeKeyboardAction()
        }
    }

    private func startNativeKeyboardWatchIfNeeded() {
        nativeKeyboardWatchTask?.cancel()
        nativeKeyboardWatchTask = nil
        guard KindleDevice.shared.isUsingNativeSystemKeyboard else { return }
        nativeKeyboardWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            while !Task.isCancelled {
                guard let self = self, self.isVisible else { break }
                if !KindleDevice.shared.isUsingNativeSystemKeyboard { break }
                if let shown = KindleDevice.shared.getLipcInt(service: "com.lab126.keyboard", property: "show"),
                   shown == 0 {
                    kgtk_schedule_idle({ _ in
                        KindleKeyboardManager.shared.dismiss()
                    }, nil)
                    break
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    public func showDefault(layout: String = "abc") {
        interactionGeneration &+= 1
        if isVisible {
            KindleDevice.shared.openNativeSystemKeyboard(layout: layout)
            return
        }
        if let fb = fallbackOnUpdate {
            present(
                title: fallbackTitle,
                text: fallbackText,
                isSecure: fallbackIsSecure,
                isMultiline: fallbackIsMultiline,
                layout: layout,
                onSubmit: fallbackOnSubmit,
                onUpdate: fb
            )
        } else {
            present(
                title: "Kindle Scratchpad",
                text: currentText,
                isSecure: false,
                isMultiline: false,
                layout: layout
            ) { [weak self] updated in
                self?.currentText = updated
            }
        }
    }

    public func submitAndDismiss() {
        let submitCallback = onSubmit
        dismiss()
        submitCallback?()
    }

    public func dismiss() {
        nativeKeyboardWatchTask?.cancel()
        nativeKeyboardWatchTask = nil
        guard isVisible else {
            KindleDevice.shared.closeNativeSystemKeyboard()
            return
        }
        let dismissCallback = onDismiss
        isVisible = false
        activeFieldID = nil
        onUpdate = nil
        onSubmit = nil
        onDismiss = nil
        dismissCallback?()
        self.pendingNativeKBAction = .close
        KindleStateRegistry.shared.notifyStateMutation()
        if KindleStateRegistry.shared.onStateDidChange == nil {
            flushPendingNativeKeyboardAction()
        }
    }

    public func append(_ str: String) {
        interactionGeneration &+= 1
        currentText += str
        onUpdate?(currentText)
        if isShift, str.count == 1, let ch = str.first, ch.isLetter {
            isShift = false
        }
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func backspace() {
        interactionGeneration &+= 1
        guard !currentText.isEmpty else { return }
        currentText.removeLast()
        onUpdate?(currentText)
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func clear() {
        interactionGeneration &+= 1
        currentText = ""
        isShift = true
        onUpdate?("")
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func toggleShift() {
        interactionGeneration &+= 1
        isShift.toggle()
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func toggleSymbols() {
        interactionGeneration &+= 1
        isSymbols.toggle()
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func toggleMaskPreview() {
        interactionGeneration &+= 1
        showMaskedText.toggle()
        KindleStateRegistry.shared.notifyStateMutation()
    }

    public func handleHardwareKey(_ keyval: UInt32) -> Bool {
        guard isVisible else { return false }
        if keyval == 0xff1b { // Escape
            dismiss()
            return true
        }
        if keyval == 0xff08 || keyval == 0xffff { // BackSpace / Delete
            backspace()
            return true
        }
        if keyval == 0xff0d || keyval == 0xff8d { // Return / Enter
            if isMultiline {
                append("\n")
            } else {
                submitAndDismiss()
            }
            return true
        }
        if keyval >= 0x20 && !(0xff00...0xffff).contains(keyval), let scalar = UnicodeScalar(keyval) {
            append(String(scalar))
            return true
        }
        return true
    }

    internal func wrapWithKeyboardOverlayIfNeeded(_ baseNode: RenderNode) -> RenderNode {
        guard isVisible else { return baseNode }
        let expandedBase = baseNode.modifyingStyle { s in
            s.expand = true
            s.fill = true
        }
        let overlayNode = buildKeyboardView().buildRenderTree()
        return RenderNode.vstack(
            alignment: .center,
            spacing: 0,
            children: [expandedBase, overlayNode],
            style: {
                var s = ViewStyle()
                s.expand = true
                s.fill = true
                return s
            }()
        )
    }

    private func buildKeyboardView() -> some View {
        let theme = KindleTheme.current
        let useNativeKB = KindleDevice.shared.isUsingNativeSystemKeyboard
        let previewStr: String = {
            if currentText.isEmpty {
                return "Type using the keys below… ▌"
            }
            if isSecure && !showMaskedText {
                return String(repeating: "•", count: currentText.count) + "▌"
            }
            return currentText + "▌"
        }()

        let row1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        let row2 = isSymbols
            ? ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]
            : (isShift ? ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"] : ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
        let row3 = isSymbols
            ? ["_", "/", ":", ";", "\"", "'", "+", "=", "?", "~"]
            : (isShift ? ["A", "S", "D", "F", "G", "H", "J", "K", "L", "-"] : ["a", "s", "d", "f", "g", "h", "j", "k", "l", "-"])
        let row4Letters = isSymbols
            ? ["[", "]", "{", "}", "<", ">", "\\", "|"]
            : (isShift ? ["Z", "X", "C", "V", "B", "N", "M", "."] : ["z", "x", "c", "v", "b", "n", "m", "."])

        return VStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                // Header bar with field title, character count, Clear & Done
                HStack(alignment: .center, spacing: 12) {
                    Text(fieldTitle)
                        .font(.headline)
                        .foregroundColor(theme.foreground)
                    Text("\(currentText.count) chars")
                        .font(.caption)
                        .foregroundColor(theme.mutedForeground)
                    Spacer()
                    if isSecure {
                        Button(showMaskedText ? "Mask •••" : "Show Text") {
                            KindleKeyboardManager.shared.toggleMaskPreview()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Button("Clear") {
                        KindleKeyboardManager.shared.clear()
                    }
                    .buttonStyle(.unbordered)
                    .controlSize(.small)

                    Button("Done") {
                        KindleKeyboardManager.shared.submitAndDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                // Live input preview box (always visible above keys)
                HStack(alignment: .center, spacing: 10) {
                    Text(previewStr)
                        .font(.body)
                        .lineWrap(true)
                        .foregroundColor(currentText.isEmpty ? theme.mutedForeground : theme.foreground)
                        .expand(true, fill: true)
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .background(theme.panelBackground, cornerRadius: 14)
                .border(theme.subtleBorder, width: 1, cornerRadius: 14)

                if !useNativeKB {
                    // Row 1: Numbers 1-0
                    HStack(alignment: .center, spacing: 8, homogeneous: true) {
                        ForEach(0..<row1.count) { idx in
                            let k = row1[idx]
                            Button(k) {
                                KindleKeyboardManager.shared.append(k)
                            }
                            .buttonStyle(.bordered)
                            .font(.headline)
                            .padding(EdgeInsets(top: 14, leading: 4, bottom: 14, trailing: 4))
                        }
                    }

                    // Row 2: QWERTYUIOP or Symbols
                    HStack(alignment: .center, spacing: 8, homogeneous: true) {
                        ForEach(0..<row2.count) { idx in
                            let k = row2[idx]
                            Button(k) {
                                KindleKeyboardManager.shared.append(k)
                            }
                            .buttonStyle(.bordered)
                            .font(.title2)
                            .padding(EdgeInsets(top: 16, leading: 4, bottom: 16, trailing: 4))
                        }
                    }

                    // Row 3: ASDFGHJKL-
                    HStack(alignment: .center, spacing: 8, homogeneous: true) {
                        ForEach(0..<row3.count) { idx in
                            let k = row3[idx]
                            Button(k) {
                                KindleKeyboardManager.shared.append(k)
                            }
                            .buttonStyle(.bordered)
                            .font(.title2)
                            .padding(EdgeInsets(top: 16, leading: 4, bottom: 16, trailing: 4))
                        }
                    }

                    // Row 4: Shift + ZXCVBNM. + Backspace
                    HStack(alignment: .center, spacing: 8, homogeneous: true) {
                        Button(isShift ? "⇧ ON" : "⇧") {
                            KindleKeyboardManager.shared.toggleShift()
                        }
                        .buttonStyle(isShift ? .borderedProminent : .unbordered)
                        .font(.headline)
                        .padding(EdgeInsets(top: 16, leading: 4, bottom: 16, trailing: 4))

                        ForEach(0..<row4Letters.count) { idx in
                            let k = row4Letters[idx]
                            Button(k) {
                                KindleKeyboardManager.shared.append(k)
                            }
                            .buttonStyle(.bordered)
                            .font(.title2)
                            .padding(EdgeInsets(top: 16, leading: 4, bottom: 16, trailing: 4))
                        }

                        Button("⌫") {
                            KindleKeyboardManager.shared.backspace()
                        }
                        .buttonStyle(.unbordered)
                        .font(.headline)
                        .padding(EdgeInsets(top: 16, leading: 4, bottom: 16, trailing: 4))
                    }

                    // Row 5: Symbols toggle, Spacebar, Newline/At, Done
                    HStack(alignment: .center, spacing: 10) {
                        Button(isSymbols ? "ABC" : "!?#") {
                            KindleKeyboardManager.shared.toggleSymbols()
                        }
                        .buttonStyle(isSymbols ? .borderedProminent : .unbordered)
                        .font(.headline)
                        .padding(EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22))
                        .expand(false, fill: true)

                        Button(",") {
                            KindleKeyboardManager.shared.append(",")
                        }
                        .buttonStyle(.bordered)
                        .font(.title2)
                        .padding(EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22))
                        .expand(false, fill: true)

                        Button("Space") {
                            KindleKeyboardManager.shared.append(" ")
                        }
                        .buttonStyle(.bordered)
                        .font(.headline)
                        .padding(EdgeInsets(top: 16, leading: 40, bottom: 16, trailing: 40))
                        .expand(true, fill: true)

                        if isMultiline {
                            Button("↵ Line") {
                                KindleKeyboardManager.shared.append("\n")
                            }
                            .buttonStyle(.bordered)
                            .font(.headline)
                            .padding(EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22))
                            .expand(false, fill: true)
                        } else {
                            Button("@") {
                                KindleKeyboardManager.shared.append("@")
                            }
                            .buttonStyle(.bordered)
                            .font(.title2)
                            .padding(EdgeInsets(top: 16, leading: 22, bottom: 16, trailing: 22))
                            .expand(false, fill: true)
                        }

                        Button("Done ✓") {
                            KindleKeyboardManager.shared.submitAndDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.headline)
                        .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
                        .expand(false, fill: true)
                    }
                }
            }
            .padding(EdgeInsets(top: 16, leading: 24, bottom: 18, trailing: 24))
            .background(theme.cardBackground, cornerRadius: 22)
            .border(theme.border, width: 2, cornerRadius: 22)
            .expand(false, fill: true)

            if useNativeKB {
                let kbH = KindleDevice.shared.nativeKeyboardHeightLogicalPx
                VStack(spacing: 0) {
                    Spacer(minLength: kbH)
                }
                .frame(height: kbH)
                .expand(false, fill: true)
            }
        }
        .expand(false, fill: true)
    }
}

/// A single-line password/secret input field with bullet masking and on-screen keyboard support.
public struct SecureField: View, _PrimitiveView {
    public typealias Body = Never
    public let placeholder: String
    public let text: Binding<String>

    public init(_ placeholder: String = "", text: Binding<String>) {
        self.placeholder = placeholder
        self.text = text
    }

    public func _makeNode() -> RenderNode {
        var tf = TextField(placeholder, text: text)
        tf.isSecure = true
        return tf._makeNode()
    }
}

/// A multi-line editable E-Ink text view with automatic on-screen keyboard support.
public struct TextEditor: View, _PrimitiveView {
    public typealias Body = Never
    public let text: Binding<String>
    public let minHeight: Int

    public init(text: Binding<String>, minHeight: Int = 180) {
        self.text = text
        self.minHeight = max(60, minHeight)
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let env = KindleStateRegistry.shared.currentEnvironment
        let submitHandler = env.activeOnSubmit
        let focusBridge = env.activeFocusBridge
        let binding = text
        let currentVal = binding.wrappedValue
        let fieldID = "TextEditor:\(minHeight)"

        KindleKeyboardManager.shared.registerDefaultField(
            title: "Notes",
            text: currentVal,
            isSecure: false,
            isMultiline: true,
            onSubmit: submitHandler
        ) { updated in
            binding.wrappedValue = updated
        }
        KindleKeyboardManager.shared.markActiveFieldSeen(fieldID)

        if let focusBridge = focusBridge,
           focusBridge.isFocused(),
           !KindleKeyboardManager.shared.isFieldFocused(fieldID),
           !KindleStateRegistry.shared.suppressSideEffects {
            KindleKeyboardManager.shared.present(
                title: "Notes",
                text: currentVal,
                isSecure: false,
                isMultiline: true,
                fieldID: fieldID,
                notifyMutation: false,
                onSubmit: submitHandler,
                onDismiss: {
                    focusBridge.setFocused(false)
                }
            ) { updated in
                binding.wrappedValue = updated
            }
        }

        let isFocused = KindleKeyboardManager.shared.isFieldFocused(fieldID) || (focusBridge?.isFocused() ?? false)
        let displayStr = currentVal.isEmpty ? "Tap to edit notes…" : currentVal
        let explicitLines = displayStr.split(separator: "\n", omittingEmptySubsequences: false)
        let wrappedLineCount = explicitLines.reduce(0) { acc, line in
            acc + max(1, (line.count + 47) / 48)
        }
        let effectiveHeight = max(minHeight, wrappedLineCount * 38 + (isFocused ? 84 : 44))

        return Button(action: {
            if KindleKeyboardManager.shared.isFieldFocused(fieldID) {
                submitHandler?()
                KindleKeyboardManager.shared.dismiss()
                focusBridge?.setFocused(false)
            } else {
                focusBridge?.setFocused(true)
                KindleKeyboardManager.shared.present(
                    title: "Notes",
                    text: binding.wrappedValue,
                    isSecure: false,
                    isMultiline: true,
                    fieldID: fieldID,
                    onSubmit: submitHandler,
                    onDismiss: {
                        focusBridge?.setFocused(false)
                    }
                ) { updated in
                    binding.wrappedValue = updated
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isFocused ? (displayStr + " ▌") : displayStr)
                    .font(.body)
                    .lineWrap(true)
                    .foregroundColor(currentVal.isEmpty ? theme.mutedForeground : theme.foreground)
                if isFocused {
                    HStack(alignment: .center, spacing: 10) {
                        Spacer()
                        Badge("Done", prominent: true)
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        .frame(height: effectiveHeight)
        .expand(false, fill: true)
        .buildRenderTree()
    }
}
