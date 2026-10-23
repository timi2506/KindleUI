import Foundation
import CKindleGTK

/// Holds a closure registered with a GTK2 widget signal so its pointer stays alive during the current render cycle.
internal final class GTKSignalTarget {
    enum Handler {
        case tap(() -> Void)
        case toggle((Bool) -> Void)
        case textChange((String) -> Void)
        case sliderChange((Double) -> Void)
    }

    let handler: Handler
    init(_ handler: Handler) {
        self.handler = handler
    }
}

private func gtkClickedTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    if case .tap(let action) = target.handler {
        action()
    }
}

private func gtkToggledTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    if case .toggle(let onToggle) = target.handler {
        let isActive = kgtk_toggle_button_get_active(widget)
        onToggle(isActive)
    }
}

private func gtkEntryActivateTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    if case .textChange(let onChange) = target.handler {
        if let cStr = kgtk_entry_get_text(widget) {
            onChange(String(cString: cStr))
        }
    }
}

private func gtkValueChangedTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    if case .sliderChange(let onChange) = target.handler {
        let val = kgtk_range_get_value(widget)
        onChange(val)
    }
}

private func gtkWindowDestroyTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    kgtk_main_quit()
}

/// Renders a `KindleUI` view hierarchy onto native GTK+-2.0 widgets (for Kindle OS and Linux/X11 desktops).
public final class GTK2Renderer: @unchecked Sendable {
    private var window: KWidgetRef?
    private var rootContainer: KWidgetRef?
    private var activeSignalTargets: [GTKSignalTarget] = []
    private let makeTree: () -> RenderNode
    private let defaultConfig: KindleWindowConfig
    private var isRebuilding: Bool = false

    public init(defaultConfig: KindleWindowConfig, makeTree: @escaping () -> RenderNode) {
        self.defaultConfig = defaultConfig
        self.makeTree = makeTree
    }

    /// Starts the native GTK+-2.0 application loop. Returns `false` if GTK+-2.0 is not available on the host.
    public func start() -> Bool {
        guard kgtk_init() else {
            return false
        }

        KindleStateRegistry.shared.beginRenderPass()
        let initialTree = makeTree()
        KindleStateRegistry.shared.endRenderPass()

        let effectiveConfig = initialTree.extractedWindowConfig ?? defaultConfig

        // GTK_WINDOW_TOPLEVEL = 0
        guard let win = kgtk_window_new(0) else {
            return false
        }
        self.window = win

        let awesomeTitle = effectiveConfig.awesomeWindowTitle
        awesomeTitle.withCString { cStr in
            kgtk_window_set_title(win, cStr)
        }
        kgtk_window_set_default_size(win, Int32(effectiveConfig.width), Int32(effectiveConfig.height))
        // GTK_WIN_POS_CENTER = 1
        kgtk_window_set_position(win, 1)
        // White E-Ink paper background (GTK_STATE_NORMAL = 0)
        kgtk_widget_modify_bg_gray(win, 0, EInkColor.paperWhite.grayLevel)

        _ = "destroy".withCString { sig in
            kgtk_signal_connect(win, sig, gtkWindowDestroyTrampoline, nil)
        }

        let rootBox = kgtk_vbox_new(false, 0)
        self.rootContainer = rootBox
        if let rootBox = rootBox {
            kgtk_container_add(win, rootBox)
        }

        KindleStateRegistry.shared.onStateDidChange = { [weak self] in
            self?.rebuildUI()
        }

        mountTree(initialTree)
        kgtk_widget_show_all(win)
        kgtk_main()
        return true
    }

    private func rebuildUI() {
        guard !isRebuilding, let rootContainer = rootContainer, let window = window else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        KindleStateRegistry.shared.beginRenderPass()
        let updatedTree = makeTree()
        KindleStateRegistry.shared.endRenderPass()

        if let newConfig = updatedTree.extractedWindowConfig {
            newConfig.awesomeWindowTitle.withCString { cStr in
                kgtk_window_set_title(window, cStr)
            }
        }

        kgtk_container_clear(rootContainer)
        activeSignalTargets.removeAll(keepingCapacity: true)

        mountTree(updatedTree)
        kgtk_widget_show_all(rootContainer)
    }

    private func mountTree(_ tree: RenderNode) {
        guard let rootContainer = rootContainer else { return }
        if let childWidget = buildWidget(for: tree) {
            kgtk_box_pack_start(rootContainer, childWidget, true, true, 0)
        }
    }

    private func buildWidget(for node: RenderNode, inheritedFont: KindleFont? = nil) -> KWidgetRef? {
        switch node {
        case .empty:
            return nil

        case .group(let children):
            guard let box = kgtk_vbox_new(false, 4) else { return nil }
            for child in children {
                if let w = buildWidget(for: child, inheritedFont: inheritedFont) {
                    let (expand, fill) = expansionFlags(for: child)
                    kgtk_box_pack_start(box, w, expand, fill, 0)
                }
            }
            return box

        case .vstack(let alignment, let spacing, let children, let style):
            guard let box = kgtk_vbox_new(false, Int32(spacing)) else { return nil }
            let fontToPass = style.font ?? inheritedFont
            for child in children {
                if let w = buildWidget(for: child, inheritedFont: fontToPass) {
                    let alignedW = alignHorizontallyIfNeeded(widget: w, child: child, alignment: alignment)
                    let (expand, fill) = expansionFlags(for: child)
                    kgtk_box_pack_start(box, alignedW, expand, fill, 0)
                }
            }
            return applyStyle(style, to: box, inheritedFont: inheritedFont)

        case .hstack(let alignment, let spacing, let children, let style):
            guard let box = kgtk_hbox_new(false, Int32(spacing)) else { return nil }
            let fontToPass = style.font ?? inheritedFont
            for child in children {
                if let w = buildWidget(for: child, inheritedFont: fontToPass) {
                    let alignedW = alignVerticallyIfNeeded(widget: w, alignment: alignment)
                    let (expand, fill) = expansionFlags(for: child)
                    kgtk_box_pack_start(box, alignedW, expand, fill, 0)
                }
            }
            return applyStyle(style, to: box, inheritedFont: inheritedFont)

        case .zstack(_, let children, let style):
            guard let box = kgtk_vbox_new(false, 0) else { return nil }
            let fontToPass = style.font ?? inheritedFont
            for child in children {
                if let w = buildWidget(for: child, inheritedFont: fontToPass) {
                    kgtk_box_pack_start(box, w, true, true, 0)
                }
            }
            return applyStyle(style, to: box, inheritedFont: inheritedFont)

        case .scrollView(_, let child, let style):
            guard let sw = kgtk_scrolled_window_new() else { return nil }
            if let childWidget = buildWidget(for: child, inheritedFont: style.font ?? inheritedFont) {
                kgtk_scrolled_window_add_with_viewport(sw, childWidget)
            }
            return applyStyle(style, to: sw, inheritedFont: inheritedFont)

        case .card(let title, let child, let style):
            let frame: KWidgetRef?
            if let title = title {
                frame = title.withCString { kgtk_frame_new($0) }
            } else {
                frame = kgtk_frame_new(nil)
            }
            guard let unwrappedFrame = frame else { return nil }
            // GTK_SHADOW_ETCHED_IN = 3
            kgtk_frame_set_shadow_type(unwrappedFrame, 3)
            if let childWidget = buildWidget(for: child, inheritedFont: style.font ?? inheritedFont) {
                if let padAlign = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0) {
                    kgtk_alignment_set_padding(padAlign, 8, 8, 10, 10)
                    kgtk_container_add(padAlign, childWidget)
                    kgtk_container_add(unwrappedFrame, padAlign)
                } else {
                    kgtk_container_add(unwrappedFrame, childWidget)
                }
            }
            return applyStyle(style, to: unwrappedFrame, inheritedFont: inheritedFont)

        case .text(let content, let wrap, let alignment, let style):
            guard let label = content.withCString({ kgtk_label_new($0) }) else { return nil }
            kgtk_label_set_line_wrap(label, wrap)
            kgtk_misc_set_alignment(label, alignment.gtkAlign, 0.5)
            return applyStyle(style, to: label, inheritedFont: inheritedFont)

        case .button(let label, let customChild, let action, let style):
            let btn: KWidgetRef?
            if let customChild = customChild {
                btn = "".withCString { kgtk_button_new_with_label($0) }
                if let b = btn, let cw = buildWidget(for: customChild, inheritedFont: style.font ?? inheritedFont) {
                    kgtk_container_clear(b)
                    kgtk_container_add(b, cw)
                }
            } else {
                btn = label.withCString { kgtk_button_new_with_label($0) }
            }
            guard let unwrappedBtn = btn else { return nil }
            let target = GTKSignalTarget(.tap(action))
            activeSignalTargets.append(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            _ = "clicked".withCString { sig in
                kgtk_signal_connect(unwrappedBtn, sig, gtkClickedTrampoline, ptr)
            }
            return applyStyle(style, to: unwrappedBtn, inheritedFont: inheritedFont)

        case .toggle(let label, let isOn, let onToggle, let style):
            guard let check = label.withCString({ kgtk_check_button_new_with_label($0) }) else { return nil }
            kgtk_toggle_button_set_active(check, isOn)
            let target = GTKSignalTarget(.toggle(onToggle))
            activeSignalTargets.append(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            _ = "toggled".withCString { sig in
                kgtk_signal_connect(check, sig, gtkToggledTrampoline, ptr)
            }
            return applyStyle(style, to: check, inheritedFont: inheritedFont)

        case .textField(let placeholder, let text, let onTextChange, let style):
            guard let entry = kgtk_entry_new() else { return nil }
            let displayVal = text.isEmpty ? placeholder : text
            displayVal.withCString { kgtk_entry_set_text(entry, $0) }
            let target = GTKSignalTarget(.textChange(onTextChange))
            activeSignalTargets.append(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            _ = "activate".withCString { sig in
                kgtk_signal_connect(entry, sig, gtkEntryActivateTrampoline, ptr)
            }
            return applyStyle(style, to: entry, inheritedFont: inheritedFont)

        case .slider(let value, let range, let step, let onValueChange, let style):
            guard let scale = kgtk_hscale_new_with_range(range.lowerBound, range.upperBound, step) else { return nil }
            kgtk_range_set_value(scale, value)
            let target = GTKSignalTarget(.sliderChange(onValueChange))
            activeSignalTargets.append(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            _ = "value-changed".withCString { sig in
                kgtk_signal_connect(scale, sig, gtkValueChangedTrampoline, ptr)
            }
            return applyStyle(style, to: scale, inheritedFont: inheritedFont)

        case .progressBar(let fraction, let text, let style):
            guard let pbar = kgtk_progress_bar_new() else { return nil }
            kgtk_progress_bar_set_fraction(pbar, fraction)
            if let text = text {
                text.withCString { kgtk_progress_bar_set_text(pbar, $0) }
            }
            return applyStyle(style, to: pbar, inheritedFont: inheritedFont)

        case .divider(let vertical, let style):
            let sep = vertical ? kgtk_vseparator_new() : kgtk_hseparator_new()
            guard let unwrappedSep = sep else { return nil }
            return applyStyle(style, to: unwrappedSep, inheritedFont: inheritedFont)

        case .spacer(let minLength, let style):
            guard let box = kgtk_vbox_new(false, 0) else { return nil }
            if let minLength = minLength {
                kgtk_widget_set_size_request(box, Int32(minLength), Int32(minLength))
            }
            return applyStyle(style, to: box, inheritedFont: inheritedFont)

        case .image(let path, _, let style):
            guard let img = path.withCString({ kgtk_image_new_from_file($0) }) else { return nil }
            return applyStyle(style, to: img, inheritedFont: inheritedFont)
        }
    }

    private func applyStyle(_ style: ViewStyle, to widget: KWidgetRef, inheritedFont: KindleFont?) -> KWidgetRef {
        var current = widget

        if let font = style.font ?? inheritedFont {
            font.pangoDescription.withCString { desc in
                kgtk_widget_modify_font_string(current, desc)
            }
        }

        if let fg = style.foregroundColor {
            kgtk_widget_modify_fg_gray(current, 0, fg.grayLevel)
        }

        if let width = style.width, let height = style.height {
            kgtk_widget_set_size_request(current, Int32(width), Int32(height))
        } else if let width = style.width {
            kgtk_widget_set_size_request(current, Int32(width), -1)
        } else if let height = style.height {
            kgtk_widget_set_size_request(current, -1, Int32(height))
        }

        if let padding = style.padding {
            if let align = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0) {
                kgtk_alignment_set_padding(
                    align,
                    Int32(padding.top),
                    Int32(padding.bottom),
                    Int32(padding.leading),
                    Int32(padding.trailing)
                )
                kgtk_container_add(align, current)
                current = align
            }
        }

        if style.borderWidth > 0 {
            if let frame = kgtk_frame_new(nil) {
                // GTK_SHADOW_SOLID / IN = 1
                kgtk_frame_set_shadow_type(frame, 1)
                kgtk_container_set_border_width(frame, Int32(style.borderWidth))
                kgtk_container_add(frame, current)
                current = frame
            }
        }

        if let bg = style.backgroundColor {
            if let eventBox = kgtk_event_box_new() {
                kgtk_widget_modify_bg_gray(eventBox, 0, bg.grayLevel)
                kgtk_container_add(eventBox, current)
                current = eventBox
            } else {
                kgtk_widget_modify_bg_gray(current, 0, bg.grayLevel)
            }
        }

        if let onAppear = style.onAppear {
            onAppear()
        }

        return current
    }

    private func alignHorizontallyIfNeeded(widget: KWidgetRef, child: RenderNode, alignment: HorizontalAlignment) -> KWidgetRef {
        if case .text = child {
            return widget
        }
        return widget
    }

    private func alignVerticallyIfNeeded(widget: KWidgetRef, alignment: VerticalAlignment) -> KWidgetRef {
        return widget
    }

    private func expansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        switch node {
        case .spacer:
            return (true, true)
        case .scrollView(_, _, let style):
            return (style.expand, style.fill)
        case .vstack(_, _, _, let style),
             .hstack(_, _, _, let style),
             .zstack(_, _, let style),
             .card(_, _, let style),
             .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .image(_, _, let style):
            return (style.expand, style.fill)
        case .empty, .group:
            return (false, true)
        }
    }
}
