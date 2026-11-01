import Foundation
import CKindleGTK

extension GTK2Renderer {
    // MARK: - Cairo Styled Button Construction

    internal func buildStyledButton(
        label: String,
        customChild: RenderNode?,
        action: @escaping () -> Void,
        style: ViewStyle,
        context: RenderContext
    ) -> KWidgetRef? {
        let theme = KindleTheme.current
        let visuals = context.resolveButtonVisuals(style: style, theme: theme)
        let isDisabled = visuals.isDisabled
        let effectiveBg = visuals.effectiveBg
        let effectiveFg = visuals.effectiveFg
        let effectiveBorderColor = visuals.effectiveBorderColor
        let effectiveBorderWidth = visuals.effectiveBorderWidth
        let effectiveRadius = visuals.effectiveRadius
        let effectiveShadow = visuals.effectiveShadow
        let effectiveFont = visuals.effectiveFont
        let innerPad = visuals.innerPad
        let outerPad = visuals.outerPad
        let childCtx = visuals.childCtx

        let xAlign = style.alignment?.horizontal.gtkAlign ?? 0.5
        let yAlign = style.alignment?.vertical.gtkAlign ?? 0.5

        let innerWidget: KWidgetRef?
        if let customChild = customChild {
            innerWidget = buildChild(customChild, at: 0, context: childCtx)
        } else {
            if let lbl = label.withCString({ kgtk_label_new($0) }) {
                kgtk_label_set_line_wrap(lbl, false)
                kgtk_misc_set_alignment(lbl, xAlign, yAlign)
                kgtk_label_set_justify(lbl, xAlign < 0.25 ? 0 : (xAlign > 0.75 ? 1 : 2))
                kgtk_label_set_bg_gray(lbl, (effectiveBg ?? context.bg).grayLevel)
                effectiveFont.pangoDescription.withCString { desc in
                    kgtk_widget_set_font_and_fg(lbl, desc, true, effectiveFg.grayLevel)
                }
                innerWidget = lbl
            } else {
                innerWidget = nil
            }
        }
        guard let unwrappedInner = innerWidget else { return nil }

        let target = GTKSignalTarget(.tap(action))
        registerTarget(target)
        let ptr = Unmanaged.passUnretained(target).toOpaque()

        let sx = effectiveShadow?.x ?? 0
        let sy = effectiveShadow?.y ?? 0
        let sGray = (effectiveShadow?.color ?? theme.shadowColor).grayLevel

        let childFills = customChild.map { nodeWantsFullWidth($0) } ?? false

        guard var btn = kgtk_styled_button_new(
            unwrappedInner,
            effectiveBg != nil,
            (effectiveBg ?? theme.panelBackground).grayLevel,
            Int32(effectiveBorderWidth),
            effectiveBorderColor.grayLevel,
            Int32(effectiveRadius),
            Int32(sx),
            Int32(sy),
            sGray,
            Int32(innerPad.top),
            Int32(innerPad.bottom),
            Int32(innerPad.leading),
            Int32(innerPad.trailing),
            xAlign,
            yAlign,
            childFills ? 1.0 : 0.0,
            0.0,
            !isDisabled,
            gtkClickedTrampoline,
            ptr
        ) else { return nil }

        if style.isEllipse {
            kgtk_styled_box_set_shape(btn, 0, 0, 0, 0, true)
        } else if let uc = style.unevenCorners {
            kgtk_styled_box_set_shape(
                btn,
                Int32(uc.topLeading),
                Int32(uc.topTrailing),
                Int32(uc.bottomTrailing),
                Int32(uc.bottomLeading),
                false
            )
        }

        applySizeConstraints(style, to: btn)

        if let outerPad = outerPad, let align = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0) {
            kgtk_alignment_set_padding(
                align,
                Int32(outerPad.top),
                Int32(outerPad.bottom),
                Int32(outerPad.leading),
                Int32(outerPad.trailing)
            )
            kgtk_container_add(align, btn)
            btn = align
        }

        return btn
    }

    // MARK: - Cairo Styled Toggle (Switch / Checkbox / Button)

    internal func buildStyledToggle(
        label: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void,
        style: ViewStyle,
        context: RenderContext
    ) -> KWidgetRef? {
        let theme = KindleTheme.current
        let toggleStyle = style.toggleStyle ?? context.toggleStyle ?? .switch
        let isDisabled = style.isDisabled || context.isDisabled

        if toggleStyle == .button {
            var btnStyle = style
            btnStyle.buttonStyle = isOn ? .borderedProminent : .bordered
            return buildStyledButton(
                label: label,
                customChild: nil,
                action: { onToggle(!isOn) },
                style: btnStyle,
                context: context
            )
        }

        let effectiveFont = style.font ?? context.font ?? .body
        let effectiveFg = style.foregroundColor ?? context.fg ?? (isDisabled ? theme.mutedForeground : theme.foreground)
        let effectiveBg = style.backgroundColor ?? context.bg

        guard let hbox = kgtk_hbox_new(false, 24) else { return nil }

        if let lbl = label.withCString({ kgtk_label_new($0) }) {
            kgtk_label_set_line_wrap(lbl, false)
            kgtk_misc_set_alignment(lbl, 0.0, 0.5)
            kgtk_label_set_bg_gray(lbl, effectiveBg.grayLevel)
            effectiveFont.pangoDescription.withCString { desc in
                kgtk_widget_set_font_and_fg(lbl, desc, true, effectiveFg.grayLevel)
            }
            kgtk_box_pack_start(hbox, lbl, true, true, 0)
        }

        if let sw = buildCairoSwitch(
            isOn: isOn,
            isCheckbox: toggleStyle == .checkbox,
            fgGray: effectiveFg.grayLevel,
            bgGray: effectiveBg.grayLevel,
            trackGray: theme.panelBackground.grayLevel
        ) {
            if let vAlign = kgtk_alignment_new(1.0, 0.5, 0.0, 0.0) {
                kgtk_container_add(vAlign, sw)
                kgtk_box_pack_start(hbox, vAlign, false, false, 0)
            } else {
                kgtk_box_pack_start(hbox, sw, false, false, 0)
            }
        }

        let target = GTKSignalTarget(.tap({
            onToggle(!isOn)
        }))
        registerTarget(target)
        let ptr = Unmanaged.passUnretained(target).toOpaque()

        let innerPad = style.contentPadding ?? EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        guard var rowBtn = kgtk_styled_button_new(
            hbox,
            style.backgroundColor != nil,
            effectiveBg.grayLevel,
            Int32(style.borderWidth),
            (style.borderColor ?? theme.border).grayLevel,
            Int32(style.cornerRadius ?? 10),
            Int32(style.shadow?.x ?? 0),
            Int32(style.shadow?.y ?? 0),
            (style.shadow?.color ?? theme.shadowColor).grayLevel,
            Int32(innerPad.top),
            Int32(innerPad.bottom),
            Int32(innerPad.leading),
            Int32(innerPad.trailing),
            0.0,
            0.5,
            1.0,
            1.0,
            !isDisabled,
            gtkClickedTrampoline,
            ptr
        ) else { return hbox }

        applySizeConstraints(style, to: rowBtn)

        if let outerPad = style.padding, let align = kgtk_alignment_new(0.0, 0.0, 1.0, 1.0) {
            kgtk_alignment_set_padding(
                align,
                Int32(outerPad.top),
                Int32(outerPad.bottom),
                Int32(outerPad.leading),
                Int32(outerPad.trailing)
            )
            kgtk_container_add(align, rowBtn)
            rowBtn = align
        }

        return rowBtn
    }

    // MARK: - General ViewStyle Application

    internal func applySizeConstraints(_ style: ViewStyle, to widget: KWidgetRef) {
        let minW = style.width ?? style.minWidth ?? -1
        let maxW = style.width ?? style.maxWidth ?? -1
        let minH = style.height ?? style.minHeight ?? -1
        let maxH = style.height ?? style.maxHeight ?? -1
        guard minW > 0 || maxW > 0 || minH > 0 || maxH > 0 else { return }
        let xAlign = style.alignment?.horizontal.gtkAlign ?? 0.5
        let yAlign = style.alignment?.vertical.gtkAlign ?? 0.5
        kgtk_widget_set_size_constraints(
            widget,
            Int32(minW),
            Int32(maxW),
            Int32(minH),
            Int32(maxH),
            xAlign,
            yAlign
        )
    }

    internal func applyStyle(
        _ style: ViewStyle,
        to widget: KWidgetRef,
        context: RenderContext,
        applyTextStyle: Bool = false
    ) -> KWidgetRef {
        let theme = KindleTheme.current
        var current = widget

        if applyTextStyle {
            let font = style.font ?? context.font
            let alpha = context.effectiveOpacity(style.opacity)
            let hasFg = (style.foregroundColor != nil || context.fg != nil || alpha < 0.999)
            let targetBg = style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg
            kgtk_label_set_bg_gray(current, targetBg.grayLevel)
            let fgGray: UInt8
            if hasFg {
                let baseFg = style.foregroundColor ?? context.fg ?? theme.foreground
                let blended = context.blend(baseFg, localOpacity: style.opacity, against: targetBg)
                fgGray = blended.grayLevel
            } else {
                fgGray = theme.foreground.grayLevel
            }
            if let font = font {
                font.pangoDescription.withCString { desc in
                    kgtk_widget_set_font_and_fg(current, desc, hasFg, fgGray)
                }
            } else if hasFg {
                kgtk_widget_set_font_and_fg(current, nil, true, fgGray)
            }
        }

        if style.hasGestures && !context.isBehindModal && !context.isDisabled {
            let target = GTKSignalTarget(makeGestureHandler(for: style))
            registerTarget(target)
            let ptr = Unmanaged.passUnretained(target).toOpaque()
            let hasCustomDrag = (style.onDragChanged != nil || style.onDragEnded != nil)
            let rawThresh = max(10, style.swipeThresholdPx)
            let encodedThresh = hasCustomDrag ? -rawThresh : rawThresh
            if let gbox = kgtk_gesture_box_new(
                current,
                Int32(style.longPressDurationMs),
                Int32(encodedThresh),
                gtkGestureTrampoline,
                ptr
            ) {
                current = gbox
            }
        }

        let hasStyledBox = (style.backgroundColor != nil)
            || (style.borderWidth > 0)
            || ((style.cornerRadius ?? 0) > 0)
            || (style.unevenCorners != nil)
            || style.isEllipse
            || (style.shadow != nil)
            || (style.contentPadding != nil)

        if hasStyledBox {
            let innerPad = style.contentPadding ?? EdgeInsets()
            let sx = style.shadow?.x ?? 0
            let sy = style.shadow?.y ?? 0
            let sGray = context.blend(style.shadow?.color ?? theme.shadowColor, localOpacity: style.opacity).grayLevel
            let bgGray = (style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg).grayLevel
            let borderGray = context.blend(style.borderColor ?? theme.border, localOpacity: style.opacity).grayLevel

            if let styledBox = kgtk_styled_container_new(
                current,
                style.backgroundColor != nil,
                bgGray,
                Int32(style.borderWidth),
                borderGray,
                Int32(style.cornerRadius ?? 0),
                Int32(sx),
                Int32(sy),
                sGray,
                Int32(innerPad.top),
                Int32(innerPad.bottom),
                Int32(innerPad.leading),
                Int32(innerPad.trailing),
                0.0,
                0.0,
                1.0,
                1.0
            ) {
                if style.isEllipse {
                    kgtk_styled_box_set_shape(styledBox, 0, 0, 0, 0, true)
                } else if let uc = style.unevenCorners {
                    kgtk_styled_box_set_shape(
                        styledBox,
                        Int32(uc.topLeading),
                        Int32(uc.topTrailing),
                        Int32(uc.bottomTrailing),
                        Int32(uc.bottomLeading),
                        false
                    )
                }
                current = styledBox
            }
        }

        applySizeConstraints(style, to: current)

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

        return current
    }

    internal func nodeStyle(_ node: RenderNode) -> ViewStyle? {
        node.styleSnapshot
    }

    internal func nodeWantsFullWidth(_ node: RenderNode) -> Bool {
        node.wantsFullWidth
    }

    internal func alignHorizontallyIfNeeded(widget: KWidgetRef, child: RenderNode, alignment: HorizontalAlignment) -> KWidgetRef {
        if case .text(_, let wrap, let textAlign, let s) = child, s.backgroundColor == nil, s.borderWidth == 0 {
            let hasExplicitWidthCap = (s.width != nil || s.maxWidth != nil) && s.expandHorizontally != true
            if (alignment != .leading && textAlign == .leading && !wrap && s.fillHorizontally != true && s.expandHorizontally != true && s.width == nil && s.maxWidth == nil) || hasExplicitWidthCap {
                let hAlign = (s.alignment?.horizontal ?? alignment).gtkAlign
                if let align = kgtk_alignment_new(hAlign, 0.0, 0.0, 1.0) {
                    kgtk_container_add(align, widget)
                    return align
                }
            }
            if wrap || (s.fillHorizontally ?? s.fill) {
                return widget
            }
        }
        if case .hstack(_, _, let children, let s) = child {
            let shrinksInCenteredVStack = alignment == .center && s.backgroundColor == nil && s.borderWidth == 0 && !children.contains(where: { $0.wantsFullWidth })
            let fillsH = s.fillHorizontally ?? s.expandHorizontally ?? (shrinksInCenteredVStack ? false : s.fill)
            if ((s.width != nil || s.maxWidth != nil) && s.expandHorizontally != true) || !fillsH {
                let hAlign = (s.alignment?.horizontal ?? alignment).gtkAlign
                if let align = kgtk_alignment_new(hAlign, 0.0, 0.0, 1.0) {
                    kgtk_container_add(align, widget)
                    return align
                }
            }
            return widget
        }
        if let s = child.styleSnapshot {
            let fillsH = s.fillHorizontally ?? s.expandHorizontally ?? s.fill
            if ((s.width != nil || s.maxWidth != nil) && s.expandHorizontally != true) || !fillsH {
                let hAlign = (s.alignment?.horizontal ?? alignment).gtkAlign
                if let align = kgtk_alignment_new(hAlign, 0.0, 0.0, 1.0) {
                    kgtk_container_add(align, widget)
                    return align
                }
            }
        }
        return widget
    }

    internal func nodeWantsFullHeight(_ node: RenderNode) -> Bool {
        node.wantsFullHeight
    }

    internal func alignVerticallyIfNeeded(widget: KWidgetRef, child: RenderNode, alignment: VerticalAlignment) -> KWidgetRef {
        if child.wantsFullHeight {
            return widget
        }
        let s = child.styleSnapshot
        let vAlign = (s?.alignment?.vertical ?? alignment).gtkAlign
        if let align = kgtk_alignment_new(0.0, vAlign, 1.0, 0.0) {
            kgtk_container_add(align, widget)
            return align
        }
        return widget
    }

    internal func verticalExpansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        node.verticalExpansionFlags
    }

    internal func horizontalExpansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        node.horizontalExpansionFlags
    }

    internal func expansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        node.expansionFlags
    }
}
