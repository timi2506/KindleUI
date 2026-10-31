import Foundation

// MARK: - Modal Overlays (.alert, .confirmationDialog, .sheet)

/// Defines a button in an E-Ink `.alert` or `.confirmationDialog`.
public struct AlertButton {
    public enum Role: Sendable, Equatable {
        case `default`
        case cancel
        case destructive
    }

    public let title: String
    public let role: Role
    public let action: (() -> Void)?

    public init(_ title: String, role: Role = .default, action: (() -> Void)? = nil) {
        self.title = title
        self.role = role
        self.action = action
    }

    public static func `default`(_ title: String, action: (() -> Void)? = nil) -> AlertButton {
        AlertButton(title, role: .default, action: action)
    }

    public static func cancel(_ title: String = "Cancel", action: (() -> Void)? = nil) -> AlertButton {
        AlertButton(title, role: .cancel, action: action)
    }

    public static func destructive(_ title: String, action: (() -> Void)? = nil) -> AlertButton {
        AlertButton(title, role: .destructive, action: action)
    }

    public static func ok(_ title: String = "OK", action: (() -> Void)? = nil) -> AlertButton {
        AlertButton(title, role: .default, action: action)
    }
}

internal struct ModalOverlayView<Upstream: View, ModalContent: View>: View, _PrimitiveView {
    typealias Body = Never
    let isPresented: Binding<Bool>
    let alignment: Alignment
    var isFullScreen: Bool = false
    var hasScrim: Bool = true
    let upstream: Upstream
    let modalContent: () -> ModalContent

    func _makeNode() -> RenderNode {
        let baseNode = upstream.buildRenderTree()
        guard isPresented.wrappedValue else {
            return baseNode
        }
        let binding = isPresented
        KindleStateRegistry.shared.activeDismissActions.append {
            binding.wrappedValue = false
        }
        KindleKeyboardManager.shared.didEnterModalLayer()
        let overlayNode = modalContent().buildRenderTree()
        if KindleStateRegistry.shared.isEvaluatingBody {
            KindleStateRegistry.shared.activeModalOverlays.append((
                alignment: alignment,
                node: overlayNode,
                isFullScreen: isFullScreen,
                hasScrim: hasScrim
            ))
            return baseNode
        }
        return RenderNode.zstack(
            alignment: alignment,
            children: [baseNode, overlayNode],
            style: {
                var s = ViewStyle()
                s.expand = true
                s.fill = true
                s.isModalOverlay = true
                s.isFullScreenModal = isFullScreen
                s.hasModalScrim = hasScrim
                return s
            }()
        )
    }
}

extension View {
    /// Presents a high-contrast E-Ink alert card centered over the screen when `isPresented` is `true`.
    public func alert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        primaryButton: AlertButton = .ok(),
        secondaryButton: AlertButton? = nil
    ) -> some View {
        let theme = KindleTheme.current
        return ModalOverlayView(isPresented: isPresented, alignment: .center, upstream: self) {
            VStack(alignment: .center, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 18) {
                        Icon(.warning, size: 48)
                            .foregroundColor(theme.foreground)
                        Text(title)
                            .font(.title)
                            .foregroundColor(theme.foreground)
                        Spacer()
                    }

                    if let message = message, !message.isEmpty {
                        Text(message)
                            .font(.body)
                            .lineWrap(true)
                            .frame(width: 1120)
                            .foregroundColor(theme.mutedForeground)
                    }

                    HStack(alignment: .center, spacing: 18, homogeneous: true) {
                        if let secondary = secondaryButton {
                            Button(secondary.title) {
                                isPresented.wrappedValue = false
                                secondary.action?()
                            }
                            .buttonStyle(secondary.role == .cancel ? .unbordered : .bordered)
                            .expand(true, fill: true)
                        }

                        Button(primaryButton.title) {
                            isPresented.wrappedValue = false
                            primaryButton.action?()
                        }
                        .buttonStyle(.borderedProminent)
                        .expand(true, fill: true)
                    }
                }
                .padding(EdgeInsets(top: 36, leading: 40, bottom: 36, trailing: 40))
                .background(theme.cardBackground, cornerRadius: 28)
                .border(theme.border, width: 4, cornerRadius: 28)
                .shadow(color: theme.shadowColor, x: 8, y: 8)
                .frame(width: 1240)

                Spacer()
            }
            .expand(true, fill: true)
        }
    }

    /// Presents a multi-option E-Ink confirmation dialog anchored at the bottom of the screen when `isPresented` is `true`.
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        actions: [AlertButton]
    ) -> some View {
        let theme = KindleTheme.current
        return ModalOverlayView(isPresented: isPresented, alignment: .bottom, upstream: self) {
            VStack(alignment: .center, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 16) {
                        Icon(.info, size: 44)
                            .foregroundColor(theme.foreground)
                        Text(title)
                            .font(.title)
                            .foregroundColor(theme.foreground)
                        Spacer()
                    }

                    if let message = message, !message.isEmpty {
                        Text(message)
                            .font(.body)
                            .lineWrap(true)
                            .frame(width: 1300)
                            .foregroundColor(theme.mutedForeground)
                    }

                    ForEach(actions.indices) { idx in
                        let btn = actions[idx]
                        Button(btn.title) {
                            isPresented.wrappedValue = false
                            btn.action?()
                        }
                        .buttonStyle(btn.role == .destructive ? .borderedProminent : (btn.role == .cancel ? .unbordered : .bordered))
                        .expand(false, fill: true)
                    }
                }
                .padding(EdgeInsets(top: 32, leading: 36, bottom: 32, trailing: 36))
                .background(theme.cardBackground, cornerRadius: 28)
                .border(theme.border, width: 4, cornerRadius: 28)
                .shadow(color: theme.shadowColor, x: 8, y: 8)
                .frame(width: 1420)
                .padding(.bottom, 84)
            }
            .expand(true, fill: true)
        }
    }

    /// Presents a confirmation dialog with a primary confirm button and a cancel button.
    public func confirmationDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        confirmTitle: String,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        let confirmBtn: AlertButton = isDestructive
            ? .destructive(confirmTitle, action: onConfirm)
            : .default(confirmTitle, action: onConfirm)
        return confirmationDialog(
            title,
            isPresented: isPresented,
            message: message,
            actions: [confirmBtn, .cancel("Cancel")]
        )
    }

    /// Presents a bottom-anchored E-Ink sheet drawer over the screen when `isPresented` is `true`.
    ///
    /// Includes a top grabber pill handle (supports swipe-down or tap-outside to dismiss),
    /// full-width bottom-sheet geometry, and configurable `PresentationDetent` height (`.medium`, `.large`, or `.fit`).
    public func sheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        detent: PresentationDetent = .medium,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        let theme = KindleTheme.current
        let sheetHeight: Int? = {
            switch detent {
            case .medium: return 1240
            case .large:  return 1960
            case .fit:    return nil
            }
        }()

        return ModalOverlayView(isPresented: isPresented, alignment: .bottom, upstream: self) {
            VStack(alignment: .leading, spacing: 0) {
                // Dimmed backdrop region above the bottom sheet: tapping outside dismisses the sheet
                VStack(alignment: .center, spacing: 0) {
                    Spacer()
                }
                .expand(true, fill: true)
                .onTapGesture {
                    isPresented.wrappedValue = false
                }

                // Bottom-anchored full-width sheet drawer
                VStack(alignment: .leading, spacing: 22) {
                    // Top grabber handle + header bar (swipe down to dismiss)
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 0) {
                            Spacer()
                            Capsule()
                                .fill(theme.mutedForeground)
                                .frame(width: 160, height: 12)
                            Spacer()
                        }
                        .padding(.top, 4)

                        HStack(alignment: .center, spacing: 18) {
                            if let title = title, !title.isEmpty {
                                Text(title)
                                    .font(.title)
                                    .foregroundColor(theme.foreground)
                            }
                            Spacer()
                            Button("Done ✕") {
                                isPresented.wrappedValue = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .onSwipeGesture(
                        onDown: {
                            isPresented.wrappedValue = false
                        }
                    )

                    Divider(thickness: 2, color: theme.subtleBorder)

                    content()
                }
                .padding(EdgeInsets(top: 22, leading: 44, bottom: 38, trailing: 44))
                .background(theme.cardBackground, cornerRadius: 36)
                .border(theme.border, width: 4, cornerRadius: 36)
                .frame(height: sheetHeight)
                .expand(false, fill: true)
            }
            .expand(true, fill: true)
        }
    }

    /// Presents a bottom-anchored E-Ink sheet using the given optional item as a data source for the sheet's content.
    public func sheet<Item, SheetContent: View>(
        item: Binding<Item?>,
        title: String? = nil,
        detent: PresentationDetent = .medium,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        let boolBinding = Binding<Bool>(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        return self.sheet(isPresented: boolBinding, title: title, detent: detent) {
            if let current = item.wrappedValue {
                content(current)
            }
        }
    }

    /// Presents a modal view that covers as much of the E-Ink screen as possible when `isPresented` is `true`.
    public func fullScreenCover<CoverContent: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        @ViewBuilder content: @escaping () -> CoverContent
    ) -> some View {
        let theme = KindleTheme.current
        return ModalOverlayView(isPresented: isPresented, alignment: .top, isFullScreen: true, upstream: self) {
            VStack(alignment: .leading, spacing: 14) {
                if let title = title, !title.isEmpty {
                    HStack(alignment: .center, spacing: 18) {
                        Text(title)
                            .font(.title)
                            .foregroundColor(theme.foreground)
                        Spacer()
                        Button("Close ✕") {
                            isPresented.wrappedValue = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    Divider(thickness: 1, color: theme.subtleBorder)
                }
                content()
            }
            .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
            .background(theme.background)
            .expand(true, fill: true)
        }
    }

    /// Presents an alert using the given optional `presenting` data when `isPresented` is `true`.
    public func alert<T>(
        _ title: String,
        isPresented: Binding<Bool>,
        presenting data: T?,
        message: (T) -> String,
        primaryButton: (T) -> AlertButton = { _ in .ok() },
        secondaryButton: ((T) -> AlertButton)? = nil
    ) -> some View {
        let msg = data.map(message)
        let primary = data.map(primaryButton) ?? .ok()
        let secondary = data.flatMap { d in secondaryButton?(d) }
        return alert(
            title,
            isPresented: isPresented,
            message: msg,
            primaryButton: primary,
            secondaryButton: secondary
        )
    }
}

/// Defines the vertical height detent of a bottom `.sheet` presentation.
public enum PresentationDetent: String, CaseIterable, Sendable, Equatable {
    case medium = "Medium (Half)"
    case large = "Large (Tall)"
    case fit = "Fit Content"
}



// MARK: - 5. .contextMenu, .popover, @ViewBuilder .overlay / .background & .badge

/// Anchor mode for positioning a popover relative to its source view.
public enum PopoverAttachmentAnchor: Sendable, Equatable {
    /// Anchors to the bounds of the presenting view (e.g. below toolbar/controls).
    case bounds
    /// Anchors with a custom offset in logical points.
    case point(x: Int, y: Int)
    /// Anchors to a specified rectangular region in logical points.
    case rect(x: Int, y: Int, width: Int, height: Int)
}

extension View {
    /// Attaches a context menu to the view that opens on long-press.
    public func contextMenu<MenuItems: View>(
        @ViewBuilder menuItems: @escaping () -> MenuItems
    ) -> some View {
        let presentedBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "ctx-menu",
            initialValue: { false }
        )
        let isOpenBinding = Binding<Bool>(
            get: { presentedBox.value },
            set: { newVal in
                presentedBox.value = newVal
                KindleStateRegistry.shared.notifyStateMutation()
            }
        )
        return self
            .onLongPressGesture {
                isOpenBinding.wrappedValue = true
            }
            .sheet(isPresented: isOpenBinding, title: "Context Actions", detent: .medium) {
                VStack(alignment: .leading, spacing: 10) {
                    menuItems()
                }
            }
    }

    /// Presents a popover callout card when a given condition is true.
    public func popover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        attachmentAnchor: PopoverAttachmentAnchor = .bounds,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        let theme = KindleTheme.current
        let alignment: Alignment = {
            if arrowEdge.contains(.bottom) { return .bottomTrailing }
            if arrowEdge.contains(.leading) { return .topLeading }
            if arrowEdge.contains(.trailing) { return .topTrailing }
            return .topTrailing
        }()
        let topPad: Int = {
            switch attachmentAnchor {
            case .point(_, let y):
                return y
            case .rect(_, let y, _, let h):
                return y + h + 10
            case .bounds:
                // When anchored with arrow pointing up (.top), position the popover card
                // snug directly below the presenting button row (~298 logical points on Kindle).
                return arrowEdge.contains(.top) ? 298 : 28
            }
        }()
        let bottomPad = arrowEdge.contains(.bottom) ? 120 : 28
        let trailingPad: Int = {
            switch attachmentAnchor {
            case .point(let x, _):
                return x
            case .rect(let x, _, let w, _):
                let centerX = x + w / 2
                let halfCard = 290
                return max(16, 1860 - (centerX + halfCard))
            case .bounds:
                // Horizontally centered below the triggering popover button in standard Kindle layout.
                // Trigger button: [880, 995] px -> center = 937.5 px (~1411 logical pt).
                // Card width = 580 pt (~385.4 px) -> half = 290 pt (~192.7 px).
                // Trailing margin = 1860 - (1411 + 290) = 159 pt (105.6 px from screen right edge 1236).
                // Symmetrical overhang: 135 px on the left, 135 px on the right.
                return 159
            }
        }()
        let leadingPad = 28

        return ModalOverlayView(
            isPresented: isPresented,
            alignment: alignment,
            isFullScreen: false,
            hasScrim: false,
            upstream: self
        ) {
            content()
                .padding(22)
                .background(theme.cardBackground, cornerRadius: 16)
                .border(theme.foreground, width: 2, cornerRadius: 16)
                .shadow(color: theme.shadowColor, x: 4, y: 4)
                .frame(width: 580)
                .padding(EdgeInsets(top: topPad, leading: leadingPad, bottom: bottomPad, trailing: trailingPad))
        }
    }

    /// Presents a popover using the given item as a data source for the popover's content.
    public func popover<Item: Identifiable, PopoverContent: View>(
        item: Binding<Item?>,
        attachmentAnchor: PopoverAttachmentAnchor = .bounds,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping (Item) -> PopoverContent
    ) -> some View {
        let boolBinding = Binding<Bool>(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        return self.popover(isPresented: boolBinding, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) {
            if let current = item.wrappedValue {
                content(current)
            }
        }
    }

    /// Layers the views that you specify in front of this view.
    public func overlay<OverlayContent: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> OverlayContent
    ) -> some View {
        ZStack(alignment: alignment) {
            self
            content()
        }
    }

    /// Layers the views that you specify behind this view.
    public func background<BackgroundContent: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> BackgroundContent
    ) -> some View {
        ZStack(alignment: alignment) {
            content()
            self
        }
    }

    /// Generates a badge for the view from a string label.
    public func badge(_ label: String?) -> some View {
        HStack(alignment: .center, spacing: 10) {
            self
                .expand(true, fill: true)
            if let label = label, !label.isEmpty {
                Badge(label, prominent: true)
            }
        }
    }

    /// Generates a badge for the view from an integer count (`0` hides the badge).
    public func badge(_ count: Int) -> some View {
        self.badge(count > 0 ? "\(count)" : nil)
    }
}



extension View {
    /// Sets the available detents for the enclosing sheet.
    public func presentationDetents(
        _ detents: Set<PresentationDetent>,
        selection: Binding<PresentationDetent>? = nil
    ) -> Self {
        _ = detents
        _ = selection
        return self
    }

    /// Sets the visibility of the drag indicator on top of a sheet.
    public func presentationDragIndicator(_ visibility: ScrollIndicatorVisibility) -> Self {
        _ = visibility
        return self
    }

    /// Conditionally prevents interactive dismissal of a sheet or popover.
    public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> Self {
        _ = isDisabled
        return self
    }
}
