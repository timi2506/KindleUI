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
        case toggle((Bool) -> Void)
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
            let kbWasVisible = KindleKeyboardManager.shared.isVisible
            let genBefore = KindleKeyboardManager.shared.interactionGeneration
            action()
            if kbWasVisible && KindleKeyboardManager.shared.isVisible && KindleKeyboardManager.shared.interactionGeneration == genBefore {
                KindleKeyboardManager.shared.dismiss()
            }
        }
    }
}

internal func gtkToggledTrampoline(widget: KWidgetRef?, userData: UnsafeMutableRawPointer?) {
    guard let widget = widget, let userData = userData else { return }
    let target = Unmanaged<GTKSignalTarget>.fromOpaque(userData).takeUnretainedValue()
    withExtendedLifetime(target) {
        if case .toggle(let onToggle) = target.handler {
            let kbWasVisible = KindleKeyboardManager.shared.isVisible
            let genBefore = KindleKeyboardManager.shared.interactionGeneration
            let isActive = kgtk_toggle_button_get_active(widget)
            onToggle(isActive)
            if kbWasVisible && KindleKeyboardManager.shared.isVisible && KindleKeyboardManager.shared.interactionGeneration == genBefore {
                KindleKeyboardManager.shared.dismiss()
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
            let kbWasVisible = KindleKeyboardManager.shared.isVisible
            let genBefore = KindleKeyboardManager.shared.interactionGeneration
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
            if (1...6).contains(gestureType) && kbWasVisible && KindleKeyboardManager.shared.isVisible && KindleKeyboardManager.shared.interactionGeneration == genBefore {
                KindleKeyboardManager.shared.dismiss()
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

/// Inherited styling context propagated down the view hierarchy during GTK widget construction.
internal struct RenderContext {
    var font: KindleFont?
    var fg: EInkColor?
    var bg: EInkColor
    var opacity: Double = 1.0
    var buttonStyle: KindleButtonStyle?
    var toggleStyle: KindleToggleStyle?
    var controlSize: KindleControlSize?
    var isDisabled: Bool = false
    var isBehindModal: Bool = false

    func effectiveOpacity(_ localOpacity: Double) -> Double {
        max(0.0, min(1.0, self.opacity * localOpacity))
    }

    func blend(_ color: EInkColor, localOpacity: Double = 1.0, against customBg: EInkColor? = nil) -> EInkColor {
        let alpha = effectiveOpacity(localOpacity)
        guard alpha < 0.999 else { return color }
        let bgGray = Double((customBg ?? self.bg).grayLevel)
        let fgGray = Double(color.grayLevel)
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
}
