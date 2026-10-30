import Foundation
import CKindleGTK


/// Renders a `KindleUI` view hierarchy onto native GTK+-2.0 & Cairo widgets (for Kindle OS and Linux/X11 desktops).
public final class GTK2Renderer: @unchecked Sendable {
    internal var window: KWidgetRef?
    internal var rootContainer: KWidgetRef?
    internal var activeSignalTargets: [GTKSignalTarget] = []
    /// Tree path (indices into `RenderNode.renderChildren`) of the node each entry of `activeSignalTargets` was created for.
    internal var activeTargetPaths: [[Int]] = []
    internal var currentBuildPath: [Int] = []
    /// The (keyboard-wrapped) tree currently mounted, plus the environment it was mounted under. Used to decide
    /// whether the next render pass can be applied in place instead of rebuilding every widget.
    internal var mountedTree: RenderNode?
    internal var mountedTheme: KindleTheme?
    internal var mountedKeyboardVisible: Bool = false
    internal var mountedImageStamps: [(path: String, stamp: FileStamp)] = []
    internal var mountedWindowTitle: String?
    internal var mountedLabels: [(widget: KWidgetRef, text: String, markup: String?, fgGray: UInt8)] = []
    internal var mountedProgressBars: [(barWidget: KWidgetRef, labelWidget: KWidgetRef?, fraction: Double, text: String?)] = []
    internal let makeTree: () -> RenderNode
    internal let defaultConfig: KindleWindowConfig
    internal var isRebuilding: Bool = false
    internal var idleRebuildScheduled: Bool = false
    internal var pendingRebuild: Bool = false

    public init(defaultConfig: KindleWindowConfig, makeTree: @escaping () -> RenderNode) {
        self.defaultConfig = defaultConfig
        self.makeTree = makeTree
    }

    /// Starts the native GTK+-2.0 application loop. Returns `false` if GTK+-2.0 is not available on the host.
    public func start() -> Bool {
        guard kgtk_init() else {
            return false
        }

        KindleDevice.shared.configureEPDFromCommandLine()
        KindleDevice.shared.activeApplicationID = defaultConfig.applicationID
        KindleStateRegistry.shared.onStateDidChange = { [weak self] in
            self?.scheduleRebuild()
        }

        let initialTree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let effectiveConfig = initialTree.extractedWindowConfig ?? defaultConfig
        KindleDevice.shared.activeApplicationID = effectiveConfig.applicationID
        KindleDevice.shared.closeNativeSystemKeyboard(force: true)
        _ = KindleDevice.shared.nativeKeyboardHeightLogicalPx

        // GTK_WINDOW_TOPLEVEL = 0
        guard let win = kgtk_window_new(0) else {
            return false
        }
        self.window = win

        let awesomeTitle = effectiveConfig.awesomeWindowTitle
        awesomeTitle.withCString { cStr in
            kgtk_window_set_title(win, cStr)
        }
        var screenW: Int32 = 0
        var screenH: Int32 = 0
        kgtk_get_screen_size(&screenW, &screenH)
        let targetW: Int32
        let targetH: Int32
        if effectiveConfig.layer == .application, screenW > 0, screenH > 0 {
            targetW = screenW
            var chromeInsetH: Int32 = 0
            if effectiveConfig.persistentChrome.contains(.topBar) {
                chromeInsetH += Int32((Double(screenH) * 101.0 / 1648.0).rounded())
            }
            if effectiveConfig.persistentChrome.contains(.searchBar) {
                chromeInsetH += Int32((Double(screenH) * 115.0 / 1648.0).rounded())
            }
            if effectiveConfig.persistentChrome.contains(.bottomBar) {
                chromeInsetH += Int32((Double(screenH) * 162.0 / 1648.0).rounded())
            }
            targetH = max(200, screenH - chromeInsetH)
        } else {
            targetW = kgtk_scale_px(Int32(effectiveConfig.width))
            targetH = kgtk_scale_px(Int32(effectiveConfig.height))
        }
        kgtk_window_set_default_size(win, targetW, targetH)
        // GTK_WIN_POS_CENTER = 1
        kgtk_window_set_position(win, 1)

        let initialBg = extractRootBackground(from: initialTree) ?? KindleTheme.current.background
        kgtk_widget_modify_bg_gray(win, 0, initialBg.grayLevel)

        _ = "destroy".withCString { sig in
            kgtk_signal_connect(win, sig, gtkWindowDestroyTrampoline, nil)
        }
        kgtk_set_global_key_handler(gtkGlobalKeyHandlerTrampoline, nil)
        kgtk_set_webview_input_focus_handler(gtkWebViewInputFocusTrampoline, nil)
        kgtk_window_connect_quit_keys(win, gtkWindowQuitKeyTrampoline, nil)

        let rootBox = kgtk_vbox_new(false, 0)
        self.rootContainer = rootBox
        if let rootBox = rootBox {
            kgtk_widget_modify_bg_gray(rootBox, 0, initialBg.grayLevel)
            kgtk_container_add(win, rootBox)
        }

        mountedWindowTitle = awesomeTitle
        mountTree(KindleKeyboardManager.shared.wrapWithKeyboardOverlayIfNeeded(initialTree), rootBg: initialBg)
        kgtk_widget_show_all(win)
        kgtk_flush_updates(win)
        KindleDevice.shared.performAutomaticRefresh()
        if pendingRebuild && !idleRebuildScheduled {
            scheduleRebuild()
        }
        kgtk_main()
        return true
    }

    internal func scheduleRebuild() {
        pendingRebuild = true
        if kgtk_is_slider_dragging() {
            updateLiveWidgetsDuringDrag()
            return
        }
        if isRebuilding || rootContainer == nil || window == nil {
            return
        }
        guard !idleRebuildScheduled else { return }
        idleRebuildScheduled = true
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        kgtk_schedule_idle(gtkIdleRebuildTrampoline, selfPtr)
    }

    internal func updateLiveWidgetsDuringDrag() {
        guard !isRebuilding, let window = window else { return }
        let rawTree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let effectiveTree = KindleKeyboardManager.shared.wrapWithKeyboardOverlayIfNeeded(rawTree)
        let rootBg = extractRootBackground(from: effectiveTree) ?? KindleTheme.current.background
        let initialContext = RenderContext(
            font: .body,
            fg: KindleTheme.current.foreground,
            bg: rootBg,
            buttonStyle: nil,
            toggleStyle: nil,
            controlSize: nil,
            isDisabled: false
        )
        var texts: [(String, String?, UInt8)] = []
        var progressBars: [(Double, String?)] = []
        collectLiveNodeValues(from: effectiveTree, context: initialContext, texts: &texts, progressBars: &progressBars)

        var didMutate = false
        if texts.count == mountedLabels.count {
            for i in 0..<texts.count {
                let (newTxt, newMarkup, newFgGray) = texts[i]
                if newTxt != mountedLabels[i].text || newMarkup != mountedLabels[i].markup {
                    mountedLabels[i].text = newTxt
                    mountedLabels[i].markup = newMarkup
                    if let markup = newMarkup {
                        markup.withCString { kgtk_label_set_markup(mountedLabels[i].widget, $0) }
                    } else {
                        newTxt.withCString { kgtk_label_set_text(mountedLabels[i].widget, $0) }
                    }
                    didMutate = true
                }
                if newFgGray != mountedLabels[i].fgGray {
                    mountedLabels[i].fgGray = newFgGray
                    kgtk_widget_modify_fg_gray(mountedLabels[i].widget, 0, newFgGray)
                    kgtk_widget_queue_draw(mountedLabels[i].widget)
                    didMutate = true
                }
            }
        }
        if progressBars.count == mountedProgressBars.count {
            for i in 0..<progressBars.count {
                let (newFrac, newTxt) = progressBars[i]
                if abs(newFrac - mountedProgressBars[i].fraction) > 0.0001 {
                    mountedProgressBars[i].fraction = newFrac
                    kgtk_custom_progress_set_fraction(mountedProgressBars[i].barWidget, newFrac)
                    didMutate = true
                }
                if newTxt != mountedProgressBars[i].text,
                   let lbl = mountedProgressBars[i].labelWidget,
                   let txt = newTxt {
                    mountedProgressBars[i].text = txt
                    txt.withCString { kgtk_label_set_text(lbl, $0) }
                    didMutate = true
                }
            }
        }
        if didMutate {
            kgtk_flush_live_drag(window)
        }
    }

    internal func collectLiveNodeValues(
        from node: RenderNode,
        context: RenderContext,
        texts: inout [(String, String?, UInt8)],
        progressBars: inout [(Double, String?)]
    ) {
        if let s = nodeStyle(node), s.isHidden {
            return
        }
        let theme = KindleTheme.current
        switch node {
        case .empty:
            break
        case .group(let children):
            for child in children {
                collectLiveNodeValues(from: child, context: context, texts: &texts, progressBars: &progressBars)
            }
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            let childCtx = context.merging(style)
            for child in children {
                collectLiveNodeValues(from: child, context: childCtx, texts: &texts, progressBars: &progressBars)
            }
        case .scrollView(_, let child, let style):
            let childCtx = context.merging(style)
            collectLiveNodeValues(from: child, context: childCtx, texts: &texts, progressBars: &progressBars)
        case .card(_, let child, let style):
            var cardStyle = style
            if cardStyle.backgroundColor == nil { cardStyle.backgroundColor = theme.cardBackground }
            let childCtx = context.merging(cardStyle)
            collectLiveNodeValues(from: child, context: childCtx, texts: &texts, progressBars: &progressBars)
        case .text(let content, _, _, let style):
            let baseFg = style.foregroundColor ?? context.fg ?? theme.foreground
            let targetBg = style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg
            let blendedFg = context.blend(baseFg, localOpacity: style.opacity, against: targetBg).grayLevel
            texts.append((content, style.pangoMarkup, blendedFg))
        case .button(_, let customChild, _, let style):
            if let customChild = customChild {
                let childCtx = context.merging(style)
                collectLiveNodeValues(from: customChild, context: childCtx, texts: &texts, progressBars: &progressBars)
            }
        case .progressBar(let fraction, let text, _):
            progressBars.append((fraction, text))
        default:
            break
        }
    }

    internal func scheduleRebuildAfterDrag() {
        kgtk_reset_slider_dragging()
        if pendingRebuild {
            scheduleRebuild()
        } else {
            KindleDevice.shared.performAutomaticRefresh()
        }
    }

    internal func performScheduledRebuild() {
        idleRebuildScheduled = false
        guard pendingRebuild else { return }
        if kgtk_is_slider_dragging() {
            scheduleRebuild()
            return
        }
        if isRebuilding || rootContainer == nil || window == nil {
            // Keep pendingRebuild = true; start() and rebuildUI() schedule once finished.
            return
        }
        pendingRebuild = false
        rebuildUI()
    }

    internal func rebuildUI() {
        guard !isRebuilding, let rootContainer = rootContainer, let window = window else {
            pendingRebuild = true
            return
        }
        isRebuilding = true
        kgtk_reset_slider_dragging()

        let updatedTree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let effectiveTree = KindleKeyboardManager.shared.wrapWithKeyboardOverlayIfNeeded(updatedTree)

        if let newConfig = updatedTree.extractedWindowConfig {
            KindleDevice.shared.activeApplicationID = newConfig.applicationID
            let title = newConfig.awesomeWindowTitle
            if title != mountedWindowTitle {
                mountedWindowTitle = title
                title.withCString { cStr in
                    kgtk_window_set_title(window, cStr)
                }
            }
        }

        if applyIncrementalUpdate(effectiveTree, window: window) {
            KindleKeyboardManager.shared.flushPendingNativeKeyboardAction()
            isRebuilding = false
            if pendingRebuild && !idleRebuildScheduled {
                scheduleRebuild()
            }
            return
        }

        let rootBg = extractRootBackground(from: updatedTree) ?? KindleTheme.current.background
        kgtk_window_freeze_updates(window)
        kgtk_widget_modify_bg_gray(window, 0, rootBg.grayLevel)
        kgtk_widget_modify_bg_gray(rootContainer, 0, rootBg.grayLevel)

        _ = kgtk_take_suppressed_redraw_widget() // about to be destroyed
        kgtk_container_clear(rootContainer)
        activeSignalTargets.removeAll(keepingCapacity: true)
        activeTargetPaths.removeAll(keepingCapacity: true)

        mountTree(effectiveTree, rootBg: rootBg)
        kgtk_widget_show_all(rootContainer)
        kgtk_widget_queue_draw(window)
        kgtk_flush_updates(window)
        KindleKeyboardManager.shared.flushPendingNativeKeyboardAction()

        let forceFull = KindleStateRegistry.shared.pendingFullRefresh
        KindleStateRegistry.shared.pendingFullRefresh = false
        KindleDevice.shared.performAutomaticRefresh(forceFull: forceFull)
        isRebuilding = false

        if pendingRebuild && !idleRebuildScheduled {
            scheduleRebuild()
        }
    }

    // MARK: - Incremental (in-place) updates

    /// Applies `tree` to the already mounted widgets without rebuilding them, if that is provably equivalent
    /// to a full rebuild: the tree must be structurally identical to the mounted one (see
    /// `RenderNode.isStructurallyEqual(to:)`); only label text / progress values may differ, and those are
    /// patched in place. Signal handlers are re-bound to the closures of the new tree.
    ///
    /// Returns `false` (having changed nothing) whenever any precondition is not met, in which case the
    /// caller must fall back to a full rebuild.
    internal func applyIncrementalUpdate(_ tree: RenderNode, window: KWidgetRef) -> Bool {
        guard let mounted = mountedTree,
              !KindleStateRegistry.shared.pendingFullRefresh,
              mountedTheme == KindleTheme.current,
              mountedKeyboardVisible == KindleKeyboardManager.shared.isVisible,
              mounted.isStructurallyEqual(to: tree)
        else { return false }

        var texts: [(text: String, markup: String?)] = []
        var bars: [(fraction: Double, text: String?)] = []
        let hasVolatileContent = tree.collectLiveContent(texts: &texts, progressBars: &bars)
        guard !hasVolatileContent,
              texts.count == mountedLabels.count,
              bars.count == mountedProgressBars.count
        else { return false }

        // Images are loaded from disk when mounted; a rewritten file requires a remount.
        for entry in mountedImageStamps where FileStamp(path: entry.path) != entry.stamp {
            return false
        }

        guard retargetHandlers(to: tree) else { return false }
        mountedTree = tree

        var didMutate = false
        for i in 0..<texts.count {
            let (newText, newMarkup) = texts[i]
            guard newText != mountedLabels[i].text || newMarkup != mountedLabels[i].markup else { continue }
            mountedLabels[i].text = newText
            mountedLabels[i].markup = newMarkup
            if let markup = newMarkup {
                markup.withCString { kgtk_label_set_markup(mountedLabels[i].widget, $0) }
            } else {
                newText.withCString { kgtk_label_set_text(mountedLabels[i].widget, $0) }
            }
            didMutate = true
        }
        for i in 0..<bars.count {
            let (newFraction, newText) = bars[i]
            if abs(newFraction - mountedProgressBars[i].fraction) > 0.0001 {
                mountedProgressBars[i].fraction = newFraction
                kgtk_custom_progress_set_fraction(mountedProgressBars[i].barWidget, newFraction)
                didMutate = true
            }
            if let label = mountedProgressBars[i].labelWidget,
               let text = newText, !text.isEmpty,
               text != mountedProgressBars[i].text {
                mountedProgressBars[i].text = text
                text.withCString { kgtk_label_set_text(label, $0) }
                didMutate = true
            }
        }

        // A button click defers its un-pressed repaint to the pending rebuild; the widget survives in place now.
        let deferredRedraw = kgtk_take_suppressed_redraw_widget()
        if let deferredRedraw = deferredRedraw {
            kgtk_widget_queue_draw(deferredRedraw)
        }
        if didMutate || deferredRedraw != nil {
            kgtk_flush_live_drag(window)
        }
        if didMutate {
            KindleDevice.shared.performAutomaticRefresh()
        }
        return true
    }

    /// Points every mounted signal target at the matching closure(s) of `tree`. All-or-nothing: returns
    /// `false` without touching any target if some target can't be matched to a node of the expected kind.
    internal func retargetHandlers(to tree: RenderNode) -> Bool {
        guard activeSignalTargets.count == activeTargetPaths.count else { return false }
        var replacements: [GTKSignalTarget.Handler] = []
        replacements.reserveCapacity(activeSignalTargets.count)

        for (target, path) in zip(activeSignalTargets, activeTargetPaths) {
            guard let node = tree.node(atPath: path) else { return false }
            switch (target.handler, node) {
            case (.tap, .button(_, _, let action, _)):
                replacements.append(.tap(action))
            case (.tap, .toggle(_, let isOn, let onToggle, _)):
                replacements.append(.tap({ onToggle(!isOn) }))
            case (.textChange, .textField(_, _, let onChange, _)):
                replacements.append(.textChange(onChange))
            case (.textEditorChange, .textEditor(_, _, let onChange, _)):
                replacements.append(.textEditorChange(onChange))
            case (.sliderChange, .slider(_, _, _, let onChange, _)):
                replacements.append(.sliderChange(onChange))
            case (.canvas(_, _, let oldPointer), .canvas(let buffer, _, let onPrepare, let onPointer, _)):
                // Canvases mounted behind a modal were built without a pointer handler; keep it that way.
                replacements.append(.canvas(buffer: buffer, onPrepare: onPrepare, onPointer: oldPointer == nil ? nil : onPointer))
            case (.webViewLoad, .webView(_, _, _, _, _, _, let onLoadFinished, _)):
                replacements.append(.webViewLoad(onLoadFinished))
            case (.gesture, _):
                guard let style = nodeStyle(node), style.hasGestures else { return false }
                replacements.append(makeGestureHandler(for: style))
            default:
                return false
            }
        }

        for (target, handler) in zip(activeSignalTargets, replacements) {
            target.handler = handler
        }
        return true
    }

    internal func extractRootBackground(from node: RenderNode) -> EInkColor? {
        if let s = nodeStyle(node), s.isHidden {
            return nil
        }

        switch node {
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            return style.backgroundColor ?? children.first.flatMap { extractRootBackground(from: $0) }
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.backgroundColor ?? extractRootBackground(from: child)
        default:
            return nil
        }
    }

    /// Mounts `effectiveTree` (already wrapped by `KindleKeyboardManager.wrapWithKeyboardOverlayIfNeeded`).
    internal func mountTree(_ effectiveTree: RenderNode, rootBg: EInkColor) {
        guard let rootContainer = rootContainer else { return }
        mountedLabels.removeAll(keepingCapacity: true)
        mountedProgressBars.removeAll(keepingCapacity: true)
        mountedImageStamps.removeAll(keepingCapacity: true)
        currentBuildPath.removeAll(keepingCapacity: true)
        let initialContext = RenderContext(
            font: .body,
            fg: KindleTheme.current.foreground,
            bg: rootBg,
            buttonStyle: nil,
            toggleStyle: nil,
            controlSize: nil,
            isDisabled: false
        )
        if let childWidget = buildWidget(for: effectiveTree, context: initialContext) {
            kgtk_box_pack_start(rootContainer, childWidget, true, true, 0)
        }
        mountedTree = effectiveTree
        mountedTheme = KindleTheme.current
        mountedKeyboardVisible = KindleKeyboardManager.shared.isVisible
    }

    internal func makeGestureHandler(for style: ViewStyle) -> GTKSignalTarget.Handler {
        .gesture(
            onTap: style.onTapGesture,
            onLongPress: style.onLongPressGesture,
            onSwipeLeft: style.onSwipeLeft,
            onSwipeRight: style.onSwipeRight,
            onSwipeUp: style.onSwipeUp,
            onSwipeDown: style.onSwipeDown,
            onDragChanged: style.onDragChanged,
            onDragEnded: style.onDragEnded,
            onDragReleaseFlush: { [weak self] in
                self?.scheduleRebuildAfterDrag()
            }
        )
    }

    internal func registerTarget(_ target: GTKSignalTarget) {
        activeSignalTargets.append(target)
        activeTargetPaths.append(currentBuildPath)
    }

    /// Builds the child at `index` of the node currently being built, tracking its tree path.
    internal func buildChild(
        _ child: RenderNode,
        at index: Int,
        context: RenderContext
    ) -> KWidgetRef? {
        currentBuildPath.append(index)
        defer { currentBuildPath.removeLast() }
        return buildWidget(for: child, context: context)
    }

    internal func buildWidget(
        for node: RenderNode,
        context: RenderContext
    ) -> KWidgetRef? {
        let theme = KindleTheme.current

        if let s = nodeStyle(node), s.isHidden {
            return nil
        }

        switch node {
        case .empty:
            return nil

        case .group(let children):
            guard let box = kgtk_vbox_new(false, 6) else { return nil }
            for (index, child) in children.enumerated() {
                if let w = buildChild(child, at: index, context: context) {
                    let (expand, fill) = expansionFlags(for: child)
                    kgtk_box_pack_start(box, w, expand, fill, 0)
                }
            }
            return box

        case .vstack(let alignment, let spacing, let children, let style):
            guard let box = kgtk_vbox_new(style.homogeneous, Int32(spacing)) else { return nil }
            let childCtx = context.merging(style)
            for (index, child) in children.enumerated() {
                if let w = buildChild(child, at: index, context: childCtx) {
                    let alignedW = alignHorizontallyIfNeeded(widget: w, child: child, alignment: alignment)
                    let (expand, fill) = verticalExpansionFlags(for: child)
                    kgtk_box_pack_start(box, alignedW, expand, fill, 0)
                }
            }
            return applyStyle(style, to: box, context: context)

        case .hstack(let alignment, let spacing, let children, let style):
            guard let box = kgtk_hbox_new(style.homogeneous, Int32(spacing)) else { return nil }
            let childCtx = context.merging(style)
            for (index, child) in children.enumerated() {
                if let w = buildChild(child, at: index, context: childCtx) {
                    let alignedW = alignVerticallyIfNeeded(widget: w, child: child, alignment: alignment)
                    let (expand, fill) = horizontalExpansionFlags(for: child)
                    kgtk_box_pack_start(box, alignedW, expand, fill, 0)
                }
            }
            return applyStyle(style, to: box, context: context)

        case .zstack(let alignment, let children, let style):
            if style.isFullScreenModal, let topModal = children.last {
                let childCtx = context.merging(style)
                if let w = buildChild(topModal, at: children.count - 1, context: childCtx) {
                    return applyStyle(style, to: w, context: context)
                }
            }
            guard let zbox = kgtk_zstack_new() else { return nil }
            let childCtx = context.merging(style)
            var builtWidgets: [(KWidgetRef, RenderNode)] = []
            for (idx, child) in children.enumerated() {
                var itemCtx = childCtx
                if style.isModalOverlay && style.hasModalScrim && idx == 0 && children.count >= 2 {
                    itemCtx.isBehindModal = true
                    itemCtx.isDisabled = true
                }
                if let w = buildChild(child, at: idx, context: itemCtx) {
                    builtWidgets.append((w, child))
                }
            }
            if style.isModalOverlay, builtWidgets.count >= 2 {
                let modalChild = children.count >= 2 ? children[1] : children[0]
                let cs = nodeStyle(modalChild)
                let hAlign = (cs?.alignment?.horizontal ?? alignment.horizontal).gtkAlign
                let vAlign = (cs?.alignment?.vertical ?? alignment.vertical).gtkAlign
                let isSheet = (alignment.vertical == .bottom)
                let fillsW = cs?.fillHorizontally ?? cs?.expandHorizontally ?? cs?.fill ?? isSheet
                let fillsH = cs?.fillVertically ?? cs?.expandVertically ?? cs?.expand ?? false
                let xscale: Double = (cs?.width != nil) ? 0.0 : (fillsW ? 1.0 : 0.0)
                let yscale: Double = (cs?.height != nil) ? 0.0 : (fillsH ? 1.0 : 0.0)

                if style.hasModalScrim {
                    kgtk_widget_set_sensitive(builtWidgets[0].0, false)
                    if let scrim = kgtk_modal_scrim_new(
                        builtWidgets[1].0,
                        theme.background.grayLevel,
                        0.78,
                        Double(hAlign),
                        Double(vAlign),
                        xscale,
                        yscale
                    ) {
                        builtWidgets[1].0 = scrim
                    }
                } else {
                    // Non-modal overlay (e.g. popover): no background dimming, no sensitivity disabling.
                    // Wrap in transparent alignment container so child respects its natural width/height and alignment.
                    if let align = kgtk_alignment_new(
                        hAlign,
                        vAlign,
                        Float(xscale),
                        Float(yscale)
                    ) {
                        kgtk_container_add(align, builtWidgets[1].0)
                        builtWidgets[1].0 = align
                    }
                }
            }
            // gtk_table_attach prepends to table->children, so attach in reverse order
            // so builtWidgets[0] is exposed first (bottom) and builtWidgets.last is exposed last (top).
            for (w, child) in builtWidgets.reversed() {
                var placed = w
                if !style.isModalOverlay {
                    let cs = nodeStyle(child)
                    let isUnwrappedText: Bool = {
                        if case .text(_, let wrap, _, _) = child { return !wrap }
                        return false
                    }()
                    let fillsW = cs?.fillHorizontally ?? cs?.expandHorizontally ?? cs?.fill ?? (!isUnwrappedText)
                    let fillsH = cs?.fillVertically ?? cs?.expandVertically ?? cs?.expand ?? false
                    let fixedW = cs?.width != nil || !fillsW
                    let fixedH = cs?.height != nil || !fillsH
                    if fixedW || fixedH {
                        let hAlign = (cs?.alignment?.horizontal ?? alignment.horizontal).gtkAlign
                        let vAlign = (cs?.alignment?.vertical ?? alignment.vertical).gtkAlign
                        if let align = kgtk_alignment_new(
                            hAlign,
                            vAlign,
                            fixedW ? 0.0 : 1.0,
                            fixedH ? 0.0 : 1.0
                        ) {
                            kgtk_container_add(align, w)
                            placed = align
                        }
                    }
                }
                kgtk_zstack_add(zbox, placed)
            }
            return applyStyle(style, to: zbox, context: context)

        case .scrollView(let showsIndicators, let child, let style):
            let childCtx = context.merging(style)
            let bgGray = (style.backgroundColor ?? context.bg).grayLevel
            if context.isBehindModal {
                guard let frozen = kgtk_frozen_scrolled_view_new(bgGray) else { return nil }
                if let childWidget = buildChild(child, at: 0, context: childCtx) {
                    kgtk_frozen_scrolled_view_add(frozen, childWidget)
                }
                return applyStyle(style, to: frozen, context: context)
            }
            guard let sw = kgtk_scrolled_window_new() else { return nil }
            kgtk_scrolled_window_set_show_indicators(sw, showsIndicators)
            if let childWidget = buildChild(child, at: 0, context: childCtx) {
                kgtk_scrolled_window_add_with_viewport(sw, childWidget)
            }
            kgtk_scrolled_window_set_bg_gray(sw, bgGray)
            return applyStyle(style, to: sw, context: context)

        case .card(let title, let child, let style):
            var cardStyle = style
            if cardStyle.backgroundColor == nil {
                cardStyle.backgroundColor = theme.cardBackground
            }
            if cardStyle.borderWidth == 0 {
                cardStyle.borderWidth = 1
                cardStyle.borderColor = theme.subtleBorder
            }
            if cardStyle.cornerRadius == nil {
                cardStyle.cornerRadius = 18
            }
            if cardStyle.contentPadding == nil {
                cardStyle.contentPadding = EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20)
            }
            let childCtx = context.merging(cardStyle)
            guard let innerChild = buildChild(child, at: 0, context: childCtx) else { return nil }

            let bodyWidget: KWidgetRef
            if let title = title, !title.isEmpty {
                let vbox = kgtk_vbox_new(false, 10)
                if let lbl = title.uppercased().withCString({ kgtk_label_new($0) }) {
                    kgtk_label_set_line_wrap(lbl, false)
                    kgtk_misc_set_alignment(lbl, 0.0, 0.5)
                    KindleFont.system(size: 14, weight: .bold).pangoDescription.withCString {
                        kgtk_widget_modify_font_string(lbl, $0)
                    }
                    kgtk_widget_modify_fg_gray(lbl, 0, theme.mutedForeground.grayLevel)
                    if let vbox = vbox {
                        kgtk_box_pack_start(vbox, lbl, false, true, 0)
                    }
                }
                if let vbox = vbox {
                    kgtk_box_pack_start(vbox, innerChild, true, true, 0)
                    bodyWidget = vbox
                } else {
                    bodyWidget = innerChild
                }
            } else {
                bodyWidget = innerChild
            }
            return applyStyle(cardStyle, to: bodyWidget, context: context)

        case .text(let content, let wrap, let alignment, let style):
            guard let label = content.withCString({ kgtk_label_new($0) }) else { return nil }
            if let markup = style.pangoMarkup {
                markup.withCString { kgtk_label_set_markup(label, $0) }
            }
            let baseFg = style.foregroundColor ?? context.fg ?? theme.foreground
            let targetBg = style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg
            let initialFgGray = context.blend(baseFg, localOpacity: style.opacity, against: targetBg).grayLevel
            mountedLabels.append((widget: label, text: content, markup: style.pangoMarkup, fgGray: initialFgGray))
            kgtk_label_set_line_wrap(label, wrap)
            kgtk_misc_set_alignment(label, wrap ? 0.0 : alignment.gtkAlign, wrap ? 0.0 : 0.5)
            let justify: Int32
            switch alignment {
            case .leading:  justify = 0 // GTK_JUSTIFY_LEFT
            case .trailing: justify = 1 // GTK_JUSTIFY_RIGHT
            case .center:   justify = 2 // GTK_JUSTIFY_CENTER
            }
            kgtk_label_set_justify(label, justify)
            return applyStyle(style, to: label, context: context)

        case .button(let label, let customChild, let action, let style):
            return buildStyledButton(
                label: label,
                customChild: customChild,
                action: action,
                style: style,
                context: context
            )

        case .toggle(let label, let isOn, let onToggle, let style):
            return buildStyledToggle(
                label: label,
                isOn: isOn,
                onToggle: onToggle,
                style: style,
                context: context
            )

        case .textField(let placeholder, let text, let onTextChange, let style):
            let displayVal = text.isEmpty ? placeholder : text
            if context.isBehindModal {
                guard let lbl = displayVal.withCString({ kgtk_label_new($0) }) else { return nil }
                kgtk_misc_set_alignment(lbl, 0.0, 0.5)
                var boxStyle = style
                if boxStyle.backgroundColor == nil { boxStyle.backgroundColor = theme.cardBackground }
                if boxStyle.borderWidth == 0 {
                    boxStyle.borderWidth = 1
                    boxStyle.borderColor = theme.subtleBorder
                }
                if boxStyle.cornerRadius == nil { boxStyle.cornerRadius = 14 }
                if boxStyle.contentPadding == nil {
                    boxStyle.contentPadding = EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
                }
                return applyStyle(boxStyle, to: lbl, context: context)
            }
            guard let entry = kgtk_entry_new() else { return nil }
            displayVal.withCString { kgtk_entry_set_text(entry, $0) }
            let target = GTKSignalTarget(.textChange(onTextChange))
            registerTarget(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            _ = "activate".withCString { sig in
                kgtk_signal_connect(entry, sig, gtkEntryActivateTrampoline, ptr)
            }
            return applyStyle(style, to: entry, context: context)

        case .textEditor(let text, let minHeight, let onTextChange, let style):
            var editorStyle = style
            if editorStyle.backgroundColor == nil { editorStyle.backgroundColor = theme.cardBackground }
            if editorStyle.borderWidth == 0 {
                editorStyle.borderWidth = 1
                editorStyle.borderColor = theme.subtleBorder
            }
            if editorStyle.cornerRadius == nil { editorStyle.cornerRadius = 16 }
            if context.isBehindModal {
                guard let lbl = text.withCString({ kgtk_label_new($0) }) else { return nil }
                kgtk_label_set_line_wrap(lbl, true)
                kgtk_misc_set_alignment(lbl, 0.0, 0.0)
                if editorStyle.height == nil { editorStyle.height = minHeight }
                return applyStyle(editorStyle, to: lbl, context: context)
            }
            let fg = (style.foregroundColor ?? context.fg ?? theme.foreground).grayLevel
            let bg = (style.backgroundColor ?? theme.cardBackground).grayLevel
            let fontDesc = (style.font ?? context.font ?? .body).pangoDescription
            let target = GTKSignalTarget(.textEditorChange(onTextChange))
            registerTarget(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            guard let tv = text.withCString({ txtPtr in
                fontDesc.withCString { fontPtr in
                    kgtk_text_editor_new(
                        txtPtr,
                        Int32(minHeight),
                        fg,
                        bg,
                        fontPtr,
                        gtkTextEditorChangedTrampoline,
                        ptr
                    )
                }
            }) else { return nil }
            return applyStyle(editorStyle, to: tv, context: context)

        case .slider(let value, let range, let step, let onValueChange, let style):
            let fg = (style.tintColor ?? style.foregroundColor ?? context.fg ?? theme.foreground).grayLevel
            let bg = (style.backgroundColor ?? context.bg).grayLevel
            let track = theme.panelBackground.grayLevel

            let target = GTKSignalTarget(.sliderChange(onValueChange))
            registerTarget(target)
            let valPtr = Unmanaged.passUnretained(target).toOpaque()
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()

            guard let slider = kgtk_custom_slider_new(
                value,
                range.lowerBound,
                range.upperBound,
                step,
                fg,
                bg,
                track,
                gtkValueChangedTrampoline,
                valPtr,
                gtkScaleDragEndTrampoline,
                selfPtr
            ) else { return nil }
            return applyStyle(style, to: slider, context: context)

        case .progressBar(let fraction, let text, var style):
            let fg = (style.tintColor ?? style.foregroundColor ?? context.fg ?? theme.foreground).grayLevel
            let bg = (style.backgroundColor ?? context.bg).grayLevel
            let track = (bg == theme.panelBackground.grayLevel) ? theme.subtleBorder.grayLevel : theme.panelBackground.grayLevel
            let barHeight = style.height ?? 16
            guard let pbar = kgtk_custom_progress_new(fraction, fg, bg, track, Int32(barHeight)) else {
                return nil
            }
            if let text = text, !text.isEmpty, let vbox = kgtk_vbox_new(false, 8) {
                var headerLbl: KWidgetRef? = nil
                if let lbl = text.withCString({ kgtk_label_new($0) }) {
                    headerLbl = lbl
                    kgtk_label_set_line_wrap(lbl, false)
                    kgtk_misc_set_alignment(lbl, 0.0, 0.5)
                    let f = style.font ?? context.font ?? .caption
                    f.pangoDescription.withCString { kgtk_widget_modify_font_string(lbl, $0) }
                    kgtk_widget_modify_fg_gray(lbl, 0, fg)
                    kgtk_box_pack_start(vbox, lbl, false, true, 0)
                }
                mountedProgressBars.append((barWidget: pbar, labelWidget: headerLbl, fraction: fraction, text: text))
                kgtk_box_pack_start(vbox, pbar, false, true, 0)
                style.height = nil
                return applyStyle(style, to: vbox, context: context)
            }
            style.height = barHeight
            mountedProgressBars.append((barWidget: pbar, labelWidget: nil, fraction: fraction, text: nil))
            return applyStyle(style, to: pbar, context: context)

        case .divider(let vertical, let style):
            let thickness = vertical ? (style.width ?? 2) : (style.height ?? 2)
            let gray = context.blend(style.foregroundColor ?? theme.subtleBorder, localOpacity: style.opacity).grayLevel
            guard let sep = kgtk_custom_divider_new(vertical, Int32(thickness), gray) else { return nil }
            return applyStyle(style, to: sep, context: context)

        case .spacer(let minLength, let style):
            guard let box = kgtk_vbox_new(false, 0) else { return nil }
            if let minLength = minLength {
                kgtk_widget_set_size_request(box, Int32(minLength), Int32(minLength))
            }
            return applyStyle(style, to: box, context: context)

        case .image(let path, _, let style):
            let maxW = Int32(style.width ?? -1)
            let maxH = Int32(style.height ?? -1)
            mountedImageStamps.append((path: path, stamp: FileStamp(path: path)))
            guard let img = path.withCString({ kgtk_image_new_from_file_scaled($0, maxW, maxH) }) else { return nil }
            var imgStyle = style
            imgStyle.width = nil
            imgStyle.height = nil
            return applyStyle(imgStyle, to: img, context: context)

        case .icon(let icon, let size, let style):
            let bg = (style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg).grayLevel
            let fg = context.blend(style.foregroundColor ?? context.fg ?? theme.foreground, localOpacity: style.opacity).grayLevel
            guard let ic = kgtk_custom_icon_new(icon.rawValue, Int32(size), fg, bg, style.backgroundColor != nil) else {
                return nil
            }
            return applyStyle(style, to: ic, context: context)

        case .canvas(let buffer, _, let onPrepare, let onPointer, let style):
            let reqW = Int32(style.width ?? 400)
            let reqH = Int32(style.height ?? 320)
            if context.isBehindModal {
                guard let box = kgtk_nowindow_canvas_new() else { return nil }
                kgtk_widget_set_size_request(box, reqW, reqH)
                let target = GTKSignalTarget(.canvas(
                    buffer: buffer,
                    onPrepare: onPrepare,
                    onPointer: nil
                ))
                registerTarget(target)
                let ptr = Unmanaged.passUnretained(target).toOpaque()
                kgtk_drawing_area_connect(box, gtkCanvasExposeTrampoline, nil, ptr)
                return applyStyle(style, to: box, context: context)
            }
            guard let da = kgtk_drawing_area_new() else { return nil }
            kgtk_widget_set_size_request(da, reqW, reqH)
            let target = GTKSignalTarget(.canvas(
                buffer: buffer,
                onPrepare: onPrepare,
                onPointer: onPointer
            ))
            registerTarget(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            kgtk_drawing_area_connect(da, gtkCanvasExposeTrampoline, gtkCanvasPointerTrampoline, ptr)
            return applyStyle(style, to: da, context: context)

        case .webView(let id, let url, let html, let baseURL, let zoomLevel, let minHeight, let onLoadFinished, let style):
            var wvStyle = style
            if wvStyle.backgroundColor == nil { wvStyle.backgroundColor = theme.cardBackground }
            if wvStyle.borderWidth == 0 {
                wvStyle.borderWidth = 1
                wvStyle.borderColor = theme.subtleBorder
            }
            if wvStyle.cornerRadius == nil { wvStyle.cornerRadius = 16 }
            if wvStyle.contentPadding == nil {
                wvStyle.contentPadding = EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            }
            if context.isBehindModal {
                guard let box = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0) else { return nil }
                kgtk_widget_set_size_request(box, -1, Int32(minHeight))
                return applyStyle(wvStyle, to: box, context: context)
            }
            let target = GTKSignalTarget(.webViewLoad(onLoadFinished))
            registerTarget(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            let htmlStr = html ?? ""
            let baseStr = baseURL ?? "https://kindle.local/"
            let effectiveMinHeight = KindleKeyboardManager.shared.isVisible ? min(minHeight, 260) : minHeight
            let sw = id.withCString { cId in
                url.withCString { cUrl in
                    htmlStr.withCString { cHtml in
                        baseStr.withCString { cBase in
                            kgtk_webview_obtain(
                                cId,
                                cUrl,
                                htmlStr.isEmpty ? nil : cHtml,
                                cBase,
                                zoomLevel,
                                Int32(effectiveMinHeight),
                                gtkWebViewLoadFinishedTrampoline,
                                ptr
                            )
                        }
                    }
                }
            }
            guard let webWidget = sw else { return nil }
            return applyStyle(wvStyle, to: webWidget, context: context)
        }
    }

}
