import Foundation

/// A control that initiates an action on tap, rendered with crisp Cairo E-Ink styling.
public struct Button<Label: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let titleText: String
    private let customLabel: Label?
    private let role: KindleButtonStyle?
    private let action: () -> Void

    public init(role: KindleButtonStyle? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.titleText = ""
        self.customLabel = label()
        self.role = role
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        if let customLabel = customLabel {
            let childNode = customLabel.buildRenderTree()
            if case .text(let str, _, _, var textStyle) = childNode {
                if let role = role, textStyle.buttonStyle == nil {
                    textStyle.buttonStyle = role
                }
                return .button(label: str, customChild: nil, action: action, style: textStyle)
            }
            var style = ViewStyle()
            style.buttonStyle = role
            if let childStyle = childNode.styleSnapshot {
                if let expH = childStyle.expandHorizontally { style.expandHorizontally = expH }
                if let fillH = childStyle.fillHorizontally { style.fillHorizontally = fillH; style.fill = fillH }
                if let expV = childStyle.expandVertically { style.expandVertically = expV }
                if let fillV = childStyle.fillVertically { style.fillVertically = fillV }
                if childStyle.expand { style.expand = true; style.fill = true }
                if let w = childStyle.width { style.width = w }
                if let h = childStyle.height { style.height = h }
                if let align = childStyle.alignment { style.alignment = align }
            }
            return .button(label: titleText, customChild: childNode, action: action, style: style)
        }
        var style = ViewStyle()
        style.buttonStyle = role
        return .button(label: titleText, customChild: nil, action: action, style: style)
    }
}

extension Button where Label == Text {
    public init(_ title: String, role: KindleButtonStyle? = nil, action: @escaping () -> Void) {
        self.titleText = title
        self.customLabel = Text(title)
        self.role = role
        self.action = action
    }
}



// MARK: - EInkButton

/// A pre-styled, high-contrast E-Ink button that automatically adapts to `KindleTheme.current`.
public struct EInkButton: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let isSelected: Bool
    public let isEnabled: Bool
    public let width: Int?
    public let height: Int?
    public let fontSize: Int
    public let expandHorizontally: Bool
    public let styleRole: KindleButtonStyle
    private let action: () -> Void

    public init(
        _ title: String,
        role: KindleButtonStyle = .automatic,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        width: Int? = nil,
        height: Int? = nil,
        fontSize: Int = 18,
        expand: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.styleRole = role
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.expandHorizontally = expand
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        let effectiveRole: KindleButtonStyle = isSelected ? .borderedProminent : styleRole
        var node = Button(title, action: action)
            .font(.system(size: fontSize, weight: .bold))
            .buttonStyle(effectiveRole)
            .disabled(!isEnabled)
            .frame(width: width, height: height)
            .buildRenderTree()
        if expandHorizontally {
            node = node.modifyingStyle { style in
                style.expand = true
                style.fill = true
            }
        }
        return node
    }
}



/// A control for navigating to a URL.
public struct Link<LabelView: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let destination: URL
    private let titleText: String
    private let labelView: LabelView?

    public init(_ titleKey: String, destination: URL) where LabelView == EmptyView {
        self.titleText = titleKey
        self.destination = destination
        self.labelView = nil
    }

    public init(destination: URL, @ViewBuilder label: () -> LabelView) {
        self.titleText = destination.absoluteString
        self.destination = destination
        self.labelView = label()
    }

    public func _makeNode() -> RenderNode {
        let openSheetBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "link-sheet",
            initialValue: { false }
        )
        let targetURL = destination
        let webCtrlBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "link-web-ctrl",
            initialValue: {
                WebViewController(
                    id: "link-webview-\(abs(targetURL.absoluteString.hashValue))",
                    url: "about:blank",
                    zoomLevel: 1.8
                )
            }
        )
        let showSheet = Binding<Bool>(
            get: { openSheetBox.value },
            set: {
                openSheetBox.value = $0
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )
        let envOpenURL = KindleStateRegistry.shared.currentEnvironment.openURL
        let webCtrl = webCtrlBox.value

        return Button {
            envOpenURL(targetURL)
            let isHTTPS = targetURL.scheme?.lowercased() == "https"
            webCtrl.load(url: targetURL.absoluteString, viaModernTLS: isHTTPS)
            showSheet.wrappedValue = true
        } label: {
            if let labelView = labelView {
                labelView
            } else {
                HStack(alignment: .center, spacing: 10) {
                    Icon(.globe, size: 34)
                    Text(titleText)
                        .underline()
                        .font(.headline)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .sheet(isPresented: showSheet, title: titleText, detent: .large) {
            VStack(alignment: .leading, spacing: 10) {
                Text(targetURL.absoluteString)
                    .font(.monospaced)
                WebView(controller: webCtrl, minHeight: 540)
            }
        }
        .buildRenderTree()
    }
}

/// In-memory & file-backed E-Ink clipboard shared by `PasteButton` and copy actions.
public final class KindleClipboard: @unchecked Sendable {
    public static let shared = KindleClipboard()
    public var string: String = "KindleUI Clipboard Text"
    private init() {}
}

/// A system button that reads items from the pasteboard and delivers them to a closure.
public struct PasteButton: View, _PrimitiveView {
    public typealias Body = Never
    private let action: ([String]) -> Void

    public init(payloadType: String.Type = String.self, onPaste: @escaping ([String]) -> Void) {
        _ = payloadType
        self.action = onPaste
    }

    public func _makeNode() -> RenderNode {
        Button("Paste") {
            action([KindleClipboard.shared.string])
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .buildRenderTree()
    }
}

/// A button that triggers a standard rename action from `@Environment(\.rename)`.
public struct RenameButton: View, _PrimitiveView {
    public typealias Body = Never

    public init() {}

    public func _makeNode() -> RenderNode {
        let renameHandler = KindleStateRegistry.shared.currentEnvironment.rename
        return Button("Rename") {
            renameHandler?()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(renameHandler == nil)
        .buildRenderTree()
    }
}



// MARK: - 10. .fileImporter, .fileExporter & ShareLink

/// A control that presents an E-Ink Share Sheet for copying or saving an item on the Kindle.
public struct ShareLink: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let item: String
    public let subject: String?
    public let message: String?

    public init(_ title: String = "Share", item: String, subject: String? = nil, message: String? = nil) {
        self.title = title
        self.item = item
        self.subject = subject
        self.message = message
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let presentedBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "share-sheet-open-\(title)",
            initialValue: { false }
        )
        let feedbackBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "share-sheet-feedback-\(title)",
            initialValue: { "" }
        )

        let showSheet = Binding<Bool>(
            get: { presentedBox.value },
            set: {
                presentedBox.value = $0
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )

        let resolvedSubject = subject ?? title

        return Button {
            feedbackBox.value = ""
            showSheet.wrappedValue = true
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Icon(.share, size: 32)
                Text(title)
                    .font(.headline)
            }
        }
        .buttonStyle(.card)
        .sheet(isPresented: showSheet, title: resolvedSubject, detent: .medium) {
            VStack(alignment: .leading, spacing: 16) {
                if let message = message, !message.isEmpty {
                    Text(message)
                        .lineWrap(true)
                        .font(.subheadline)
                        .foregroundColor(theme.mutedForeground)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item)
                        .lineWrap(true)
                        .font(.body)
                        .foregroundColor(theme.foreground)
                }
                .padding(16)
                .background(theme.panelBackground, cornerRadius: 16)
                .border(theme.subtleBorder, width: 1, cornerRadius: 16)

                HStack(spacing: 12, homogeneous: true) {
                    Button {
                        KindleClipboard.shared.string = item
                        feedbackBox.value = "Copied to clipboard"
                        KindleStateRegistry.shared.notifyStateMutation()
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.document, size: 28)
                            Text("Copy")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button {
                        let dir = FileManager.default.fileExists(atPath: "/mnt/us") ? "/mnt/us/documents" : "/tmp"
                        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                        let path = "\(dir)/shared-item.txt"
                        try? item.write(toFile: path, atomically: true, encoding: .utf8)
                        feedbackBox.value = "Saved to \(path)"
                        KindleStateRegistry.shared.notifyStateMutation()
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Icon(.folder, size: 28)
                            Text("Save to Device")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.card)
                    .frame(maxWidth: .infinity)
                }

                if !feedbackBox.value.isEmpty {
                    HStack(alignment: .center, spacing: 10) {
                        Icon(.check, size: 24)
                        Text(feedbackBox.value)
                            .lineWrap(true)
                            .font(.caption)
                        Spacer()
                    }
                    .padding(12)
                    .background(theme.panelBackground, cornerRadius: 12)
                    .border(theme.subtleBorder, width: 1, cornerRadius: 12)
                }
            }
        }
        .buildRenderTree()
    }
}
