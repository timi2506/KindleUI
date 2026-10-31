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
        let role = style.buttonStyle ?? context.buttonStyle ?? .automatic
        let controlSize = style.controlSize ?? context.controlSize ?? .regular
        let isDisabled = style.isDisabled || context.isDisabled

        // Default role palette
        var defaultBg: EInkColor?
        var defaultFg: EInkColor
        var defaultBorderColor: EInkColor
        var defaultBorderWidth: Int
        var defaultRadius: Int
        var defaultShadow: KindleShadow?

        switch role {
        case .automatic, .bordered:
            defaultBg = theme.cardBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = isDisabled ? theme.subtleBorder : theme.border
            defaultBorderWidth = 1
            defaultRadius = 16
            defaultShadow = nil

        case .unbordered:
            defaultBg = theme.panelBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.panelBackground
            defaultBorderWidth = 0
            defaultRadius = 16
            defaultShadow = nil

        case .borderedProminent:
            defaultBg = isDisabled ? theme.panelBackground : (style.tintColor ?? theme.foreground)
            defaultFg = isDisabled ? theme.mutedForeground : theme.background
            defaultBorderColor = isDisabled ? theme.subtleBorder : (style.tintColor ?? theme.border)
            defaultBorderWidth = 1
            defaultRadius = 16
            defaultShadow = nil

        case .capsule:
            defaultBg = theme.panelBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.subtleBorder
            defaultBorderWidth = 1
            defaultRadius = 999
            defaultShadow = nil

        case .card:
            defaultBg = theme.cardBackground
            defaultFg = isDisabled ? theme.mutedForeground : theme.foreground
            defaultBorderColor = theme.subtleBorder
            defaultBorderWidth = 1
            defaultRadius = 18
            defaultShadow = nil

        case .plain, .borderless:
            defaultBg = nil
            defaultFg = isDisabled ? theme.mutedForeground : (style.tintColor ?? theme.foreground)
            defaultBorderColor = theme.border
            defaultBorderWidth = 0
            defaultRadius = 14
            defaultShadow = nil
        }

        let rawBg = style.backgroundColor ?? defaultBg
        let effectiveBg = rawBg.map { context.blend($0, localOpacity: style.opacity) }
        let effectiveFg = context.blend(
            style.foregroundColor ?? defaultFg,
            localOpacity: style.opacity,
            against: effectiveBg ?? context.bg
        )
        let effectiveBorderColor = context.blend(style.borderColor ?? defaultBorderColor, localOpacity: style.opacity)
        let effectiveBorderWidth = style.borderWidth > 0 ? style.borderWidth : defaultBorderWidth
        let effectiveRadius = style.cornerRadius ?? defaultRadius
        let effectiveShadow = style.shadow ?? defaultShadow
        let effectiveFont = style.font ?? context.font ?? KindleFont.system(size: controlSize.defaultFontSize, weight: .bold)

        // Determine inner button padding vs outer margin
        let innerPad: EdgeInsets
        let outerPad: EdgeInsets?
        if let contentPad = style.contentPadding {
            innerPad = contentPad
            outerPad = style.padding
        } else if let pad = style.padding {
            innerPad = pad
            outerPad = nil
        } else {
            innerPad = controlSize.defaultPadding
            outerPad = nil
        }

        var childCtx = context.merging(style)
        childCtx.font = effectiveFont
        childCtx.fg = effectiveFg
        if let bg = effectiveBg { childCtx.bg = bg }

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

        if let width = style.width, let height = style.height {
            kgtk_widget_set_size_request(btn, Int32(width), Int32(height))
        } else if let width = style.width {
            kgtk_widget_set_size_request(btn, Int32(width), -1)
        } else if let height = style.height {
            kgtk_widget_set_size_request(btn, -1, Int32(height))
        }

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
            let fgGray: UInt8
            if hasFg {
                let baseFg = style.foregroundColor ?? context.fg ?? theme.foreground
                let targetBg = style.backgroundColor.map { context.blend($0, localOpacity: style.opacity) } ?? context.bg
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

        if style.hasGestures {
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

        return current
    }

    internal func nodeStyle(_ node: RenderNode) -> ViewStyle? {
        switch node {
        case .vstack(_, _, _, let s),
             .hstack(_, _, _, let s),
             .zstack(_, _, let s),
             .scrollView(_, _, let s),
             .card(_, _, let s),
             .text(_, _, _, let s),
             .button(_, _, _, let s),
             .toggle(_, _, _, let s),
             .textField(_, _, _, let s),
             .textEditor(_, _, _, let s),
             .slider(_, _, _, _, let s),
             .progressBar(_, _, let s),
             .divider(_, let s),
             .spacer(_, let s),
             .image(_, _, let s),
             .icon(_, _, let s),
             .canvas(_, _, _, _, let s),
             .webView(_, _, _, _, _, _, _, let s):
            return s
        case .empty, .group:
            return nil
        }
    }

    internal func nodeWantsFullWidth(_ node: RenderNode) -> Bool {
        if case .spacer = node { return true }
        if let s = nodeStyle(node), (s.expandHorizontally == true || s.fillHorizontally == true || s.expand) {
            return true
        }
        switch node {
        case .vstack(_, _, let children, _),
             .hstack(_, _, let children, _),
             .zstack(_, let children, _),
             .group(let children):
            return children.contains { nodeWantsFullWidth($0) }
        case .card(_, let child, _),
             .scrollView(_, let child, _):
            return nodeWantsFullWidth(child)
        default:
            return false
        }
    }

    internal func alignHorizontallyIfNeeded(widget: KWidgetRef, child: RenderNode, alignment: HorizontalAlignment) -> KWidgetRef {
        if case .text(_, let wrap, let textAlign, let s) = child, s.backgroundColor == nil, s.borderWidth == 0 {
            if alignment != .leading && textAlign == .leading && !wrap && s.fillHorizontally != true && s.expandHorizontally != true && s.width == nil {
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
            let shrinksInCenteredVStack = alignment == .center && s.backgroundColor == nil && s.borderWidth == 0 && !children.contains(where: { nodeWantsFullWidth($0) })
            let fillsH = s.fillHorizontally ?? s.expandHorizontally ?? (shrinksInCenteredVStack ? false : s.fill)
            if (s.width != nil && s.expandHorizontally != true) || !fillsH {
                let hAlign = (s.alignment?.horizontal ?? alignment).gtkAlign
                if let align = kgtk_alignment_new(hAlign, 0.0, 0.0, 1.0) {
                    kgtk_container_add(align, widget)
                    return align
                }
            }
            return widget
        }
        if let s = nodeStyle(child) {
            let fillsH = s.fillHorizontally ?? s.expandHorizontally ?? s.fill
            if (s.width != nil && s.expandHorizontally != true) || !fillsH {
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
        if case .spacer = node { return true }
        if case .divider(let vertical, _) = node, vertical { return true }
        if case .scrollView = node { return true }
        if let s = nodeStyle(node), (s.expandVertically == true || s.fillVertically == true) {
            return true
        }
        switch node {
        case .vstack(_, _, let children, _):
            return children.contains { nodeWantsFullHeight($0) }
        case .zstack(_, let children, _),
             .group(let children):
            return children.contains { nodeWantsFullHeight($0) }
        case .card(_, let child, _):
            return nodeWantsFullHeight(child)
        default:
            return false
        }
    }

    internal func alignVerticallyIfNeeded(widget: KWidgetRef, child: RenderNode, alignment: VerticalAlignment) -> KWidgetRef {
        if nodeWantsFullHeight(child) {
            return widget
        }
        let s = nodeStyle(child)
        let vAlign = (s?.alignment?.vertical ?? alignment).gtkAlign
        if let align = kgtk_alignment_new(0.0, vAlign, 1.0, 0.0) {
            kgtk_container_add(align, widget)
            return align
        }
        return widget
    }

    internal func verticalExpansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        if case .spacer = node { return (true, true) }
        if let s = nodeStyle(node) {
            if let expV = s.expandVertically {
                return (expV, s.fillVertically ?? s.fill)
            }
            if s.expandHorizontally == true {
                return (false, false)
            }
        }
        return expansionFlags(for: node)
    }

    internal func horizontalExpansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        if case .spacer = node { return (true, true) }
        if let s = nodeStyle(node) {
            if let expH = s.expandHorizontally {
                return (expH, s.fillHorizontally ?? s.fill)
            }
            if s.expandVertically == true {
                return (false, false)
            }
        }
        return expansionFlags(for: node)
    }

    internal func expansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        switch node {
        case .spacer:
            return (true, true)
        case .scrollView(_, _, let style),
             .canvas(_, _, _, _, let style),
             .webView(_, _, _, _, _, _, _, let style):
            return (style.expand, style.fill)
        case .vstack(_, _, _, let style),
             .hstack(_, _, _, let style),
             .zstack(_, _, let style),
             .card(_, _, let style),
             .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .textEditor(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .image(_, _, let style),
             .icon(_, _, let style):
            return (style.expand, style.fill)
        case .empty, .group:
            return (false, true)
        }
    }
}
