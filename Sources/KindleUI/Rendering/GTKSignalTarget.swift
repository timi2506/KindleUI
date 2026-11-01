import Foundation
import CKindleGTK

/// Cheap identity of a file's current contents (size + modification time), used to notice that an image
/// shown at an unchanged path was rewritten on disk.
internal struct FileStamp: Equatable {
    var size: Int64 = -1
    var mtimeSec: Int64 = 0
    var mtimeNsec: Int64 = 0

    init(path: String) {
        var st = stat()
        guard stat(path, &st) == 0 else { return }
        size = Int64(st.st_size)
        #if canImport(Darwin)
        mtimeSec = Int64(st.st_mtimespec.tv_sec)
        mtimeNsec = Int64(st.st_mtimespec.tv_nsec)
        #else
        mtimeSec = Int64(st.st_mtim.tv_sec)
        mtimeNsec = Int64(st.st_mtim.tv_nsec)
        #endif
    }
}

/// Holds a closure or canvas context registered with a GTK2 widget signal so its pointer stays alive during the current render cycle.
internal final class GTKSignalTarget {
    enum Handler {
        case tap(() -> Void)
        case textChange((String) -> Void)
        case textEditorChange((String) -> Void)
        case sliderChange((Double) -> Void)
        case gesture(
            onTap: (() -> Void)?,
            onLongPress: (() -> Void)?,
            onSwipeLeft: (() -> Void)?,
            onSwipeRight: (() -> Void)?,
            onSwipeUp: (() -> Void)?,
            onSwipeDown: (() -> Void)?,
            onDragChanged: ((Int, Int, Int, Int) -> Void)?,
            onDragEnded: ((Int, Int, Int, Int) -> Void)?,
            onDragReleaseFlush: (() -> Void)?
        )
        case canvas(
            buffer: KindleCanvasBuffer,
            onPrepare: ((Int, Int) -> Void)?,
            onPointer: ((Int, Int, Int) -> KindleRect?)?
        )
        case webViewLoad((() -> Void)?)
    }

    var dragStartX: Int = 0
    var dragStartY: Int = 0
    /// Re-bound in place (without rebuilding the widget) when a render pass produced a structurally
    /// identical tree, so the widget always invokes the closures of the latest evaluation.
    var handler: Handler
    init(_ handler: Handler) {
        self.handler = handler
    }
}

internal func gtkClickedTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .tap(let action) = target.handler {
            KindleKeyboardManager.shared.performWithAutoDismiss {
                action()
            }
        }
    }
}

internal func gtkEntryActivateTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .textChange(let onChange) = target.handler {
            if let cStr = kgtk_entry_get_text(widget) {
                onChange(String(cString: cStr))
            }
        }
    }
}

internal func gtkTextEditorChangedTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .textEditorChange(let onChange) = target.handler {
            if let cStr = kgtk_text_editor_get_text(widget) {
                let s = String(cString: cStr)
                kgtk_free_string(cStr)
                onChange(s)
            }
        }
    }
}

internal func gtkGestureTrampoline(gestureType: Int32, dx: Int32, dy: Int32, userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .gesture(
            let onTap,
            let onLongPress,
            let onLeft,
            let onRight,
            let onUp,
            let onDown,
            let onDragChanged,
            let onDragEnded,
            let onDragReleaseFlush
        ) = target.handler {
            let shouldCheckDismiss = (1...6).contains(gestureType)
            let runGesture = {
                switch gestureType {
                case 1: onTap?()
                case 2: onLongPress?()
                case 3: onLeft?()
                case 4: onRight?()
                case 5: onUp?()
                case 6: onDown?()
                case 10:
                    onDragChanged?(target.dragStartX, target.dragStartY, Int(dx), Int(dy))
                case 11:
                    onDragEnded?(target.dragStartX, target.dragStartY, Int(dx), Int(dy))
                    onDragReleaseFlush?()
                case 12:
                    target.dragStartX = Int(dx)
                    target.dragStartY = Int(dy)
                default: break
                }
            }
            if shouldCheckDismiss {
                KindleKeyboardManager.shared.performWithAutoDismiss(runGesture)
            } else {
                runGesture()
            }
        }
    }
}

internal func gtkValueChangedTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .sliderChange(let onChange) = target.handler {
            let val = kgtk_custom_slider_get_value(widget)
            onChange(val)
        }
    }
}

internal func gtkCanvasExposeTrampoline(widget: KWidgetRef?, width: Int32, height: Int32, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData, width > 0, height > 0 else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .canvas(let buffer, let onPrepare, _) = target.handler {
            let w = Int(width)
            let h = Int(height)
            buffer.resizeIfNeeded(width: w, height: h)
            onPrepare?(w, h)
            buffer.pixels.withUnsafeBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    kgtk_draw_gray_pixels(widget, base, Int32(w), Int32(h), Int32(w))
                }
            }
        }
    }
}

internal func gtkCanvasPointerTrampoline(widget: KWidgetRef?, phase: Int32, x: Int32, y: Int32, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .canvas(_, _, let onPointer) = target.handler {
            if let dirty = onPointer?(Int(phase), Int(x), Int(y)) {
                kgtk_widget_queue_draw_rect(
                    widget,
                    Int32(dirty.x),
                    Int32(dirty.y),
                    Int32(dirty.w),
                    Int32(dirty.h)
                )
            }
            if phase == 2 {
                KindleDevice.shared.performAutomaticRefresh()
            }
        }
    }
}

internal func gtkWindowDestroyTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    kgtk_main_quit()
}

internal func gtkWindowQuitKeyTrampoline(userData: UnsafeMutableRawPointer?) {
    kgtk_main_quit()
}

internal func gtkGlobalKeyHandlerTrampoline(keyval: UInt32, userData: UnsafeMutableRawPointer?) -> Bool {
    KindleKeyboardManager.shared.handleHardwareKey(keyval)
}

internal func gtkWebViewInputFocusTrampoline(
    viewIDPtr: UnsafePointer<CChar>?,
    labelPtr: UnsafePointer<CChar>?,
    valuePtr: UnsafePointer<CChar>?,
    isSecure: Bool,
    isMultiline: Bool,
    isNumeric: Bool,
    userData: UnsafeMutableRawPointer?
) {
    let viewID = viewIDPtr.map { String(cString: $0) } ?? "default"
    let label = labelPtr.map { String(cString: $0) } ?? "Web Input"
    let currentVal = valuePtr.map { String(cString: $0) } ?? ""
    let fieldID = "webview:\(viewID):\(label)"
    KindleKeyboardManager.shared.present(
        title: label,
        text: currentVal,
        isSecure: isSecure,
        isMultiline: isMultiline,
        fieldID: fieldID,
        layout: isNumeric ? "123" : "abc",
        onSubmit: {
            viewID.withCString { cId in
                kgtk_webview_submit_input(cId)
            }
        },
        onUpdate: { updated in
            viewID.withCString { cId in
                updated.withCString { cText in
                    kgtk_webview_set_input_text(cId, cText)
                }
            }
        }
    )
}

internal func gtkIdleRebuildTrampoline(userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let renderer = Unmanaged<GTK2Renderer>.fromOpaque(userData).takeUnretainedValue()
    renderer.performScheduledRebuild()
}

internal func gtkLowPriorityPrerenderTrampoline(userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let renderer = Unmanaged<GTK2Renderer>.fromOpaque(userData).takeUnretainedValue()
    renderer.prerenderNextPagerPageIfIdle()
}

internal func gtkScaleDragEndTrampoline(userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    let renderer = Unmanaged<GTK2Renderer>.fromOpaque(userData).takeUnretainedValue()
    renderer.scheduleRebuildAfterDrag()
}

internal func gtkWebViewLoadFinishedTrampoline(userData: UnsafeMutableRawPointer?) {
    if let userData = userData {
        let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
        withExtendedLifetime(target) {
            if case .webViewLoad(let onLoad) = target.handler {
                onLoad?()
            }
        }
    }
    KindleDevice.shared.performAutomaticRefresh()
}

/// Resolved palette, typography, and padding for a button rendered in `GTK2Renderer` or `KindlePreviewServer`.
internal struct ResolvedButtonVisuals {
    let role: KindleButtonStyle
    let controlSize: KindleControlSize
    let isDisabled: Bool
    let effectiveBg: EInkColor?
    let effectiveFg: EInkColor
    let effectiveBorderColor: EInkColor
    let effectiveBorderWidth: Int
    let effectiveRadius: Int
    let effectiveShadow: KindleShadow?
    let effectiveFont: KindleFont
    let innerPad: EdgeInsets
    let outerPad: EdgeInsets?
    let childCtx: RenderContext
}

/// Inherited styling context propagated down the view hierarchy during GTK widget and HTML preview construction.
internal struct RenderContext {
    var font: KindleFont? = .body
    var fg: EInkColor? = nil
    var bg: EInkColor = .white
    var opacity: Double = 1.0
    var buttonStyle: KindleButtonStyle? = nil
    var toggleStyle: KindleToggleStyle? = nil
    var controlSize: KindleControlSize? = nil
    var isDisabled: Bool = false
    var isBehindModal: Bool = false

    func effectiveOpacity(_ localOpacity: Double) -> Double {
        max(0.0, min(1.0, self.opacity * localOpacity))
    }

    func blend(_ color: EInkColor, localOpacity: Double = 1.0, against customBg: EInkColor? = nil) -> EInkColor {
        let alpha = effectiveOpacity(localOpacity)
        guard alpha < 0.999 else { return color }
        let bgGray = Double((customBg ?? self.bg).monochromeGrayLevel)
        let fgGray = Double(color.monochromeGrayLevel)
        let blended = UInt8(max(0.0, min(255.0, (fgGray * alpha + bgGray * (1.0 - alpha)).rounded())))
        return EInkColor(grayLevel: blended)
    }

    func merging(_ style: ViewStyle) -> RenderContext {
        var next = self
        if let f = style.font { next.font = f }
        if let fg = style.foregroundColor { next.fg = fg }
        if let bg = style.backgroundColor {
            next.bg = self.blend(bg, localOpacity: style.opacity)
        }
        next.opacity = self.effectiveOpacity(style.opacity)
        if let bs = style.buttonStyle { next.buttonStyle = bs }
        if let ts = style.toggleStyle { next.toggleStyle = ts }
        if let cs = style.controlSize { next.controlSize = cs }
        if style.isDisabled { next.isDisabled = true }
        return next
    }

    func resolveButtonVisuals(
        style: ViewStyle,
        theme: KindleTheme = .current,
        isDisabledOverride: Bool? = nil
    ) -> ResolvedButtonVisuals {
        let role = style.buttonStyle ?? self.buttonStyle ?? .automatic
        let controlSize = style.controlSize ?? self.controlSize ?? .regular
        let isDisabled = isDisabledOverride ?? (style.isDisabled || self.isDisabled)

        let defaultBg: EInkColor?
        let defaultFg: EInkColor
        let defaultBorderColor: EInkColor
        let defaultBorderWidth: Int
        let defaultRadius: Int
        let defaultShadow: KindleShadow? = nil

        switch role {
        case .automatic, .bordered:
            defaultBg = theme.cardBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = isDisabled ? theme.subtleBorder : theme.border
            defaultBorderWidth = 1
            defaultRadius = 16

        case .unbordered:
            defaultBg = theme.panelBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.panelBackground
            defaultBorderWidth = 0
            defaultRadius = 16

        case .borderedProminent:
            defaultBg = isDisabled ? theme.panelBackground : (style.tintColor ?? theme.foreground)
            defaultFg = isDisabled ? theme.mutedForeground : theme.background
            defaultBorderColor = isDisabled ? theme.subtleBorder : (style.tintColor ?? theme.border)
            defaultBorderWidth = 1
            defaultRadius = 16

        case .capsule:
            defaultBg = theme.panelBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.subtleBorder
            defaultBorderWidth = 1
            defaultRadius = 999

        case .card:
            defaultBg = theme.cardBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.subtleBorder
            defaultBorderWidth = 1
            defaultRadius = 18

        case .plain, .borderless:
            defaultBg = nil
            defaultFg = isDisabled ? theme.mutedForeground : (style.tintColor ?? theme.foreground)
            defaultBorderColor = theme.border
            defaultBorderWidth = 0
            defaultRadius = 14
        }

        let rawBg = style.backgroundColor ?? defaultBg
        let effectiveBg = rawBg.map { self.blend($0, localOpacity: style.opacity) }
        let effectiveFg = self.blend(
            style.foregroundColor ?? defaultFg,
            localOpacity: style.opacity,
            against: effectiveBg ?? self.bg
        )
        let effectiveBorderColor = self.blend(style.borderColor ?? defaultBorderColor, localOpacity: style.opacity)
        let effectiveBorderWidth = style.borderWidth > 0 ? style.borderWidth : defaultBorderWidth
        let effectiveRadius = style.cornerRadius ?? defaultRadius
        let effectiveShadow = style.shadow ?? defaultShadow
        let effectiveFont = style.font ?? self.font ?? KindleFont.system(size: controlSize.defaultFontSize, weight: .bold)

        let innerPad: EdgeInsets
        let outerPad: EdgeInsets?
        if let contentPad = style.contentPadding {
            innerPad = contentPad
            outerPad = style.padding
        } else if let pad = style.padding {
            innerPad = pad
            outerPad = nil
        } else if role == .plain || role == .borderless {
            innerPad = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            outerPad = nil
        } else {
            innerPad = controlSize.defaultPadding
            outerPad = nil
        }

        var childCtx = self.merging(style)
        childCtx.font = effectiveFont
        childCtx.fg = effectiveFg
        if let bg = effectiveBg {
            childCtx.bg = bg
        }

        return ResolvedButtonVisuals(
            role: role,
            controlSize: controlSize,
            isDisabled: isDisabled,
            effectiveBg: effectiveBg,
            effectiveFg: effectiveFg,
            effectiveBorderColor: effectiveBorderColor,
            effectiveBorderWidth: effectiveBorderWidth,
            effectiveRadius: effectiveRadius,
            effectiveShadow: effectiveShadow,
            effectiveFont: effectiveFont,
            innerPad: innerPad,
            outerPad: outerPad,
            childCtx: childCtx
        )
    }
}
