import Foundation

extension KindlePreviewServer {
    // MARK: - 1:1 GTK2Renderer Node-to-HTML Translation

    internal enum LayoutAxis {
        case vertical
        case horizontal
        case zstack
    }

    internal struct RenderContext {
        var font: KindleFont? = .body
        var fg: EInkColor? = nil
        var bg: EInkColor = .white
        var buttonStyle: KindleButtonStyle? = nil
        var toggleStyle: KindleToggleStyle? = nil
        var controlSize: KindleControlSize? = nil
        var opacity: Double = 1.0
        var isDisabled: Bool = false
        var isBehindModal: Bool = false

        func merging(_ style: ViewStyle) -> RenderContext {
            var next = self
            if let f = style.font { next.font = f }
            if let fg = style.foregroundColor { next.fg = fg }
            if let bg = style.backgroundColor {
                next.bg = blend(bg, localOpacity: style.opacity, against: self.bg)
            }
            if let bs = style.buttonStyle { next.buttonStyle = bs }
            if let ts = style.toggleStyle { next.toggleStyle = ts }
            if let cs = style.controlSize { next.controlSize = cs }
            next.opacity = effectiveOpacity(style.opacity)
            if style.isDisabled { next.isDisabled = true }
            return next
        }

        func effectiveOpacity(_ localOpacity: Double) -> Double {
            max(0.0, min(1.0, opacity * localOpacity))
        }

        func blend(_ color: EInkColor, localOpacity: Double = 1.0, against targetBg: EInkColor? = nil) -> EInkColor {
            let alpha = effectiveOpacity(localOpacity)
            guard alpha < 0.999 else { return color }
            let bgRef = targetBg ?? bg
            let blended = Double(bgRef.grayLevel) + (Double(color.grayLevel) - Double(bgRef.grayLevel)) * alpha
            return EInkColor(grayLevel: UInt8(max(0.0, min(255.0, blended.rounded()))))
        }
    }

    internal func renderNodeToHTML(
        _ node: RenderNode,
        path: String,
        ctx: RenderContext,
        parentAxis: LayoutAxis,
        expandInParent: Bool,
        fillInParent: Bool,
        crossFill: Bool,
        parentHAlign: HorizontalAlignment = .center,
        parentVAlign: VerticalAlignment = .center
    ) -> String {
        if let s = node.styleSnapshot, s.isHidden {
            return ""
        }

        let theme = KindleTheme.current

        switch node {
        case .empty:
            return ""

        case .group(let children):
            var parts: [String] = []
            for (idx, child) in children.enumerated() {
                let (expV, fillV) = expansionFlags(for: child)
                parts.append(renderNodeToHTML(
                    child,
                    path: "\(path)_g\(idx)",
                    ctx: ctx,
                    parentAxis: .vertical,
                    expandInParent: expV,
                    fillInParent: fillV,
                    crossFill: true,
                    parentHAlign: .leading,
                    parentVAlign: .center
                ))
            }
            return """
            <div class="k-vbox" style="gap: 6px; align-items: stretch;">\(parts.joined())</div>
            """

        case .vstack(let alignment, let spacing, let children, let style):
            let childCtx = ctx.merging(style)
            let alignItems: String
            switch alignment {
            case .leading: alignItems = "flex-start"
            case .center: alignItems = "center"
            case .trailing: alignItems = "flex-end"
            }
            var parts: [String] = []
            for (idx, child) in children.enumerated() {
                let (expV, fillV) = verticalExpansionFlags(for: child)
                let childFillsH = childFillsHorizontallyInVStack(child, defaultAlignment: alignment)
                parts.append(renderNodeToHTML(
                    child,
                    path: "\(path)_v\(idx)",
                    ctx: childCtx,
                    parentAxis: .vertical,
                    expandInParent: style.homogeneous ? true : expV,
                    fillInParent: style.homogeneous ? true : fillV,
                    crossFill: childFillsH,
                    parentHAlign: alignment,
                    parentVAlign: .center
                ))
            }
            let flexGrow = (expandInParent && fillInParent) ? "flex: 1 1 0; min-height: 0;" : "flex: 0 0 auto;"
            let coreHTML = """
            <div class="k-vbox" style="gap: \(max(0, spacing))px; align-items: \(alignItems); \(flexGrow)">\(parts.joined())</div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .hstack(let alignment, let spacing, let children, let style):
            let childCtx = ctx.merging(style)
            let alignItems: String
            switch alignment {
            case .top: alignItems = "flex-start"
            case .center: alignItems = "center"
            case .bottom: alignItems = "flex-end"
            }
            var parts: [String] = []
            for (idx, child) in children.enumerated() {
                let (expH, fillH) = horizontalExpansionFlags(for: child)
                let childFillsV = childFillsVerticallyInHStack(child, defaultAlignment: alignment)
                parts.append(renderNodeToHTML(
                    child,
                    path: "\(path)_h\(idx)",
                    ctx: childCtx,
                    parentAxis: .horizontal,
                    expandInParent: style.homogeneous ? true : expH,
                    fillInParent: style.homogeneous ? true : fillH,
                    crossFill: childFillsV,
                    parentHAlign: .center,
                    parentVAlign: alignment
                ))
            }
            let widthStyle = (parentAxis == .vertical && crossFill) || (parentAxis == .horizontal && expandInParent && fillInParent) ? "width: 100%;" : ""
            let coreHTML = """
            <div class="k-hbox" style="gap: \(max(0, spacing))px; align-items: \(alignItems); \(widthStyle)">\(parts.joined())</div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .zstack(let alignment, let children, let style):
            let childCtx = ctx.merging(style)
            if style.isFullScreenModal, let topModal = children.last {
                let modalHTML = renderNodeToHTML(
                    topModal,
                    path: "\(path)_zm",
                    ctx: childCtx,
                    parentAxis: .vertical,
                    expandInParent: true,
                    fillInParent: true,
                    crossFill: true,
                    parentHAlign: alignment.horizontal,
                    parentVAlign: alignment.vertical
                )
                return applyViewStyleHTML(
                    coreHTML: modalHTML,
                    node: node,
                    style: style,
                    ctx: ctx,
                    path: path,
                    parentAxis: parentAxis,
                    expandInParent: expandInParent,
                    fillInParent: fillInParent,
                    crossFill: crossFill,
                    parentHAlign: parentHAlign,
                    parentVAlign: parentVAlign
                )
            }

            var parts: [String] = []
            for (idx, child) in children.enumerated() {
                var itemCtx = childCtx
                if style.isModalOverlay && style.hasModalScrim && idx == 0 && children.count >= 2 {
                    itemCtx.isBehindModal = true
                    itemCtx.isDisabled = true
                }
                var childHTML = renderNodeToHTML(
                    child,
                    path: "\(path)_z\(idx)",
                    ctx: itemCtx,
                    parentAxis: .zstack,
                    expandInParent: true,
                    fillInParent: true,
                    crossFill: true,
                    parentHAlign: alignment.horizontal,
                    parentVAlign: alignment.vertical
                )
                let cs = child.styleSnapshot
                let hAlign = cs?.alignment?.horizontal ?? alignment.horizontal
                let vAlign = cs?.alignment?.vertical ?? alignment.vertical
                let justifyItems: String
                switch hAlign {
                case .leading: justifyItems = "flex-start"
                case .center: justifyItems = "center"
                case .trailing: justifyItems = "flex-end"
                }
                let alignLayer: String
                switch vAlign {
                case .top: alignLayer = "flex-start"
                case .center: alignLayer = "center"
                case .bottom: alignLayer = "flex-end"
                }
                if style.isModalOverlay && style.hasModalScrim && idx == 1 && children.count >= 2 {
                    let g = theme.background.grayLevel
                    childHTML = """
                    <div class="k-modal-scrim" style="background-color: rgba(\(g), \(g), \(g), 0.78); display: flex; flex-direction: column; align-items: \(justifyItems); justify-content: \(alignLayer); width: 100%; height: 100%; flex: 1;">
                        \(childHTML)
                    </div>
                    """
                }
                let zLayerClass = idx == 0 ? "k-zlayer k-zbase" : "k-zlayer k-zoverlay"
                parts.append("<div class=\"\(zLayerClass)\" style=\"align-items: \(justifyItems); justify-content: \(alignLayer);\">\(childHTML)</div>")
            }
            let coreHTML = """
            <div class="k-zstack">\(parts.joined())</div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .scrollView(let showsIndicators, let child, let style):
            let childCtx = ctx.merging(style)
            let scrollBg = style.backgroundColor ?? ctx.bg
            let (expV, fillV) = verticalExpansionFlags(for: child)
            let (expH, fillH) = horizontalExpansionFlags(for: child)
            let innerHTML = renderNodeToHTML(
                child,
                path: "\(path)_sv",
                ctx: childCtx,
                parentAxis: .vertical,
                expandInParent: expV,
                fillInParent: fillV,
                crossFill: fillH || expH || true,
                parentHAlign: .leading,
                parentVAlign: .top
            )
            let indicatorClass = showsIndicators ? "k-scroll-indicators" : "k-scroll-no-indicators"
            let coreHTML = """
            <div class="k-scroll-view \(indicatorClass)" data-scroll-id="\(path)" style="overflow-x: hidden; overflow-y: auto; background-color: \(scrollBg.hexString);">
                <div class="k-scroll-content">\(innerHTML)</div>
            </div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

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
            let childCtx = ctx.merging(cardStyle)
            let (expV, fillV) = verticalExpansionFlags(for: child)
            let (expH, fillH) = horizontalExpansionFlags(for: child)
            let innerHTML = renderNodeToHTML(
                child,
                path: "\(path)_cd",
                ctx: childCtx,
                parentAxis: .vertical,
                expandInParent: expV,
                fillInParent: fillV,
                crossFill: fillH || expH || true,
                parentHAlign: .leading,
                parentVAlign: .top
            )
            let coreHTML: String
            if let title = title, !title.isEmpty {
                let headerFont = KindleFont.system(size: 14, weight: .bold)
                coreHTML = """
                <div class="k-vbox" style="gap: 10px; align-items: stretch;">
                    <div class="k-label" style="\(Self.fontCSS(for: headerFont)) color: \(theme.mutedForeground.hexString); text-align: left;">\(Self.escapeHTML(title.uppercased()))</div>
                    \(innerHTML)
                </div>
                """
            } else {
                coreHTML = innerHTML
            }
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: cardStyle,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .text(let content, let wrap, let alignment, let style):
            let f = style.font ?? ctx.font ?? .body
            let baseFg = style.foregroundColor ?? ctx.fg ?? theme.foreground
            let targetBg = style.backgroundColor.map { ctx.blend($0, localOpacity: style.opacity) } ?? ctx.bg
            let fg = ctx.blend(baseFg, localOpacity: style.opacity, against: targetBg)
            let textAlign: String
            switch alignment {
            case .leading: textAlign = "left"
            case .center: textAlign = "center"
            case .trailing: textAlign = "right"
            }
            let wrapCSS = wrap
                ? "white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word;"
                : "white-space: pre; overflow: hidden; text-overflow: ellipsis;"
            let renderedText: String
            if let markup = style.pangoMarkup, !markup.isEmpty {
                renderedText = Self.pangoMarkupToHTML(markup)
            } else {
                renderedText = Self.escapeHTML(content)
            }
            let coreHTML = """
            <div class="k-label" style="\(Self.fontCSS(for: f)) color: \(fg.hexString); text-align: \(textAlign); \(wrapCSS)">\(renderedText)</div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .button(let label, let customChild, let action, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let actionID = "btn_\(path)"
            if isEnabled {
                tapActions[actionID] = action
            }
            return buildStyledButtonHTML(
                actionID: actionID,
                label: label,
                customChild: customChild,
                style: style,
                ctx: ctx,
                isEnabled: isEnabled,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .toggle(let label, let isOn, let onToggle, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let actionID = "tgl_\(path)"
            if isEnabled {
                toggleActions[actionID] = onToggle
            }
            return buildStyledToggleHTML(
                actionID: actionID,
                label: label,
                isOn: isOn,
                onToggle: onToggle,
                style: style,
                ctx: ctx,
                isEnabled: isEnabled,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .slider(let value, let range, let step, let onValueChange, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let actionID = "sld_\(path)"
            if isEnabled {
                sliderActions[actionID] = { newVal, _ in
                    onValueChange(newVal)
                }
            }
            let minV = range.lowerBound
            let maxV = max(minV + 0.0001, range.upperBound)
            let clamped = max(minV, min(maxV, value))
            let pct = ((clamped - minV) / (maxV - minV)) * 100.0
            let fg = (style.tintColor ?? style.foregroundColor ?? ctx.fg ?? theme.foreground)
            let bg = (style.backgroundColor ?? ctx.bg)
            let track = theme.panelBackground
            let disabledAttr = isEnabled ? "" : "disabled"
            let coreHTML = """
            <div class="k-slider-wrap" style="--slider-fg: \(fg.hexString); --slider-bg: \(bg.hexString); --slider-track: \(track.hexString); --slider-pct: \(String(format: "%.2f%%", pct));">
                <input type="range" class="k-slider" data-action-id="\(actionID)" min="\(minV)" max="\(maxV)" step="\(step)" value="\(clamped)" \(disabledAttr)
                    oninput="window.kindleSliderInput(this, false)" onchange="window.kindleSliderInput(this, true)" />
            </div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .progressBar(let fraction, let text, var style):
            let clamped = max(0.0, min(1.0, fraction))
            let pct = clamped * 100.0
            let barHeight = style.height ?? 16
            style.height = nil
            let fg = (style.tintColor ?? style.foregroundColor ?? ctx.fg ?? theme.foreground)
            let track = theme.panelBackground
            var headerHTML = ""
            if let text = text, !text.isEmpty {
                let f = style.font ?? ctx.font ?? .caption
                headerHTML = """
                <div class="k-label" style="\(Self.fontCSS(for: f)) color: \(fg.hexString); text-align: left;">\(Self.escapeHTML(text))</div>
                """
            }
            let coreHTML = """
            <div class="k-vbox" style="gap: 10px; align-items: stretch; width: 100%;">
                \(headerHTML)
                <div class="k-progress-track" style="height: \(barHeight)px; background-color: \(track.hexString); border: 2px solid \(fg.hexString); border-radius: \(barHeight / 2)px;">
                    <div class="k-progress-fill" style="width: \(String(format: "%.2f%%", pct)); background-color: \(fg.hexString);"></div>
                </div>
            </div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .textField(let placeholder, let text, let onTextChange, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let actionID = "txt_\(path)"
            if isEnabled {
                textActions[actionID] = onTextChange
            }
            let f = style.font ?? ctx.font ?? .body
            let fg = style.foregroundColor ?? ctx.fg ?? theme.foreground
            let bg = style.backgroundColor ?? theme.cardBackground
            let disabledAttr = isEnabled ? "" : "disabled"
            let coreHTML = """
            <input type="text" class="k-textfield" data-action-id="\(actionID)"
                placeholder="\(Self.escapeHTML(placeholder))" value="\(Self.escapeHTML(text))" \(disabledAttr)
                style="\(Self.fontCSS(for: f)) color: \(fg.hexString); background-color: \(bg.hexString); border: 1px solid \(theme.subtleBorder.hexString); border-radius: 14px; padding: 10px 14px; width: 100%;"
                oninput="window.kindleTextInput(this)" />
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .textEditor(let text, let minHeight, let onTextChange, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let actionID = "edt_\(path)"
            if isEnabled {
                textActions[actionID] = onTextChange
            }
            var editorStyle = style
            if editorStyle.backgroundColor == nil { editorStyle.backgroundColor = theme.cardBackground }
            if editorStyle.borderWidth == 0 {
                editorStyle.borderWidth = 1
                editorStyle.borderColor = theme.subtleBorder
            }
            if editorStyle.cornerRadius == nil { editorStyle.cornerRadius = 16 }
            let effectiveMinHeight = KindleKeyboardManager.shared.isVisible ? min(minHeight, 260) : minHeight
            let f = style.font ?? ctx.font ?? .body
            let fg = style.foregroundColor ?? ctx.fg ?? theme.foreground
            let bg = editorStyle.backgroundColor ?? theme.cardBackground
            let disabledAttr = isEnabled ? "" : "disabled"
            let coreHTML = """
            <textarea class="k-texteditor" data-action-id="\(actionID)" \(disabledAttr)
                style="\(Self.fontCSS(for: f)) color: \(fg.hexString); background-color: \(bg.hexString); min-height: \(max(60, effectiveMinHeight))px; width: 100%; border: none;"
                oninput="window.kindleTextInput(this)">\(Self.escapeHTML(text))</textarea>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: editorStyle,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .webView(let id, let url, let html, _, let zoomLevel, let minHeight, _, let style):
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
            let effectiveMinHeight = KindleKeyboardManager.shared.isVisible ? min(minHeight, 260) : minHeight
            let h = max(120, effectiveMinHeight)
            let fg = style.foregroundColor ?? ctx.fg ?? theme.foreground
            let bg = wvStyle.backgroundColor ?? theme.cardBackground
            let coreHTML: String
            if let htmlContent = html, !htmlContent.isEmpty {
                let escapedSrcDoc = Self.escapeHTML(htmlContent)
                coreHTML = """
                <iframe class="k-webview" id="wv_\(Self.escapeHTML(id))" srcdoc="\(escapedSrcDoc)"
                    style="min-height: \(h)px; width: 100%; border: none; background: \(bg.hexString); zoom: \(zoomLevel);"></iframe>
                """
            } else if !url.isEmpty {
                coreHTML = """
                <div class="k-vbox" style="min-height: \(h)px; width: 100%; background: \(bg.hexString);">
                    <div class="k-hbox" style="padding: 8px 14px; border-bottom: 1px solid \(fg.hexString); justify-content: space-between; align-items: center;">
                        <span style="font-family: monospace; font-size: 26px; color: \(fg.hexString);">\(Self.escapeHTML(url))</span>
                        <a href="\(Self.escapeHTML(url))" target="_blank" style="font-size: 26px; color: \(fg.hexString);">Open ↗</a>
                    </div>
                    <iframe class="k-webview" src="\(Self.escapeHTML(url))" style="flex: 1; width: 100%; min-height: \(max(80, h - 48))px; border: none;"></iframe>
                </div>
                """
            } else {
                coreHTML = """
                <div class="k-webview-empty" style="min-height: \(h)px;">WebView (\(Self.escapeHTML(id)))</div>
                """
            }
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: wvStyle,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .divider(let vertical, let style):
            let thickness = vertical ? (style.width ?? 2) : (style.height ?? 2)
            let resolvedColor = ctx.blend(style.foregroundColor ?? theme.subtleBorder, localOpacity: style.opacity)
            let px = max(1, thickness)
            let coreHTML: String
            if vertical {
                coreHTML = """
                <div class="k-divider-v" style="width: \(px)px; min-width: \(px)px; height: 100%; align-self: stretch; background-color: \(resolvedColor.hexString);"></div>
                """
            } else {
                coreHTML = """
                <div class="k-divider-h" style="height: \(px)px; min-height: \(px)px; width: 100%; align-self: stretch; background-color: \(resolvedColor.hexString);"></div>
                """
            }
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .spacer(let minLength, let style):
            let minPx = max(0, minLength ?? 0)
            let coreHTML: String
            if parentAxis == .horizontal {
                coreHTML = """
                <div class="k-spacer" style="min-width: \(minPx)px; flex: 1 1 auto;"></div>
                """
            } else {
                coreHTML = """
                <div class="k-spacer" style="min-height: \(minPx)px; flex: 1 1 auto;"></div>
                """
            }
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: true,
                fillInParent: true,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .image(let filePath, let altText, var style):
            let maxW = style.width
            let maxH = style.height
            style.width = nil
            style.height = nil
            let wStyle = maxW.map { "max-width: \($0)px; width: 100%;" } ?? "max-width: 100%;"
            let hStyle = maxH.map { "max-height: \($0)px; height: auto;" } ?? "height: auto;"
            let coreHTML: String
            if !filePath.isEmpty && FileManager.default.fileExists(atPath: filePath) {
                var comps = URLComponents()
                comps.queryItems = [URLQueryItem(name: "path", value: filePath)]
                let queryStr = comps.percentEncodedQuery ?? ""
                coreHTML = """
                <img class="k-image" src="/file?\(queryStr)" alt="\(Self.escapeHTML(altText))"
                    style="\(wStyle) \(hStyle) object-fit: contain; filter: grayscale(100%) contrast(1.06); display: block; margin: 0 auto;" />
                """
            } else {
                let icon = KindleIconName(systemName: filePath.isEmpty ? altText : filePath)
                let size = max(24, min(maxW ?? 36, maxH ?? 36))
                let fg = ctx.blend(style.foregroundColor ?? ctx.fg ?? theme.foreground, localOpacity: style.opacity)
                coreHTML = Self.renderSVGIcon(icon, size: size, fg: fg, bg: style.backgroundColor)
            }
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .icon(let icon, let size, let style):
            let fg = ctx.blend(style.foregroundColor ?? ctx.fg ?? theme.foreground, localOpacity: style.opacity)
            let bg = style.backgroundColor.map { ctx.blend($0, localOpacity: style.opacity) }
            let coreHTML = Self.renderSVGIcon(icon, size: max(9, size), fg: fg, bg: bg)
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )

        case .canvas(let buffer, let label, let onPrepare, let onPointer, let style):
            let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
            let w = max(32, style.width ?? 400)
            let h = max(32, style.height ?? 320)
            onPrepare?(w, h)
            let canvasID = "cvs_\(path)"
            if isEnabled {
                canvasNodes[canvasID] = (buffer: buffer, onPointer: onPointer)
            }
            let interactiveAttr = (isEnabled && onPointer != nil) ? "data-interactive=\"1\"" : ""
            let coreHTML = """
            <div class="k-canvas-wrap" style="width: \(w)px; height: \(h)px;">
                <img class="k-canvas-img" id="\(canvasID)" data-canvas-id="\(canvasID)" data-width="\(buffer.width)" data-height="\(buffer.height)" \(interactiveAttr)
                    src="/canvas?id=\(canvasID)&v=\(refreshGeneration)" alt="\(Self.escapeHTML(label))"
                    draggable="false"
                    style="width: \(w)px; height: \(h)px; display: block; image-rendering: pixelated; user-select: none;" />
            </div>
            """
            return applyViewStyleHTML(
                coreHTML: coreHTML,
                node: node,
                style: style,
                ctx: ctx,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )
        }
    }

    // MARK: - Styled Button & Toggle Construction (1:1 with GTK2Renderer.swift lines 1257–1537)

    internal func buildStyledButtonHTML(
        actionID: String,
        label: String,
        customChild: RenderNode?,
        style: ViewStyle,
        ctx: RenderContext,
        isEnabled: Bool,
        path: String,
        parentAxis: LayoutAxis,
        expandInParent: Bool,
        fillInParent: Bool,
        crossFill: Bool,
        parentHAlign: HorizontalAlignment,
        parentVAlign: VerticalAlignment
    ) -> String {
        let theme = KindleTheme.current
        let role = style.buttonStyle ?? ctx.buttonStyle ?? .automatic
        let controlSize = style.controlSize ?? ctx.controlSize ?? .regular
        let isDisabled = !isEnabled

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
        let effectiveBg = rawBg.map { ctx.blend($0, localOpacity: style.opacity) }
        let effectiveFg = ctx.blend(
            style.foregroundColor ?? defaultFg,
            localOpacity: style.opacity,
            against: effectiveBg ?? ctx.bg
        )
        let effectiveBorderColor = ctx.blend(style.borderColor ?? defaultBorderColor, localOpacity: style.opacity)
        let effectiveBorderWidth = style.borderWidth > 0 ? style.borderWidth : defaultBorderWidth
        let effectiveRadius = style.cornerRadius ?? defaultRadius
        let effectiveShadow = style.shadow ?? defaultShadow
        let effectiveFont = style.font ?? ctx.font ?? KindleFont.system(size: controlSize.defaultFontSize, weight: .bold)

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

        var childCtx = ctx.merging(style)
        childCtx.font = effectiveFont
        childCtx.fg = effectiveFg
        if let bg = effectiveBg { childCtx.bg = bg }

        let hAlign = style.alignment?.horizontal ?? .center
        let textAlign: String
        let flexAlign: String
        switch hAlign {
        case .leading:
            textAlign = "left"
            flexAlign = "flex-start"
        case .center:
            textAlign = "center"
            flexAlign = "center"
        case .trailing:
            textAlign = "right"
            flexAlign = "flex-end"
        }

        let childFills = customChild.map { nodeWantsFullWidth($0) } ?? false

        let innerHTML: String
        if let customChild = customChild {
            let (expV, fillV) = verticalExpansionFlags(for: customChild)
            innerHTML = renderNodeToHTML(
                customChild,
                path: "\(path)_bc",
                ctx: childCtx,
                parentAxis: .vertical,
                expandInParent: expV,
                fillInParent: fillV,
                crossFill: childFills,
                parentHAlign: hAlign,
                parentVAlign: style.alignment?.vertical ?? .center
            )
        } else {
            innerHTML = """
            <span class="k-btn-label" style="\(Self.fontCSS(for: effectiveFont)) color: \(effectiveFg.hexString); text-align: \(textAlign); white-space: pre;">\(Self.escapeHTML(label))</span>
            """
        }

        let bgCSS = effectiveBg.map { "background-color: \($0.hexString);" } ?? "background-color: transparent;"
        let borderCSS = effectiveBorderWidth > 0 ? "border: \(effectiveBorderWidth)px solid \(effectiveBorderColor.hexString);" : "border: none;"
        let radiusCSS = style.isEllipse ? "border-radius: 9999px;" : "border-radius: \(effectiveRadius)px;"
        let shadowCSS: String
        if let sh = effectiveShadow, (sh.x != 0 || sh.y != 0 || sh.radius > 0) {
            shadowCSS = "box-shadow: \(sh.x)px \(sh.y)px 0px \(sh.color.hexString);"
        } else {
            shadowCSS = ""
        }
        let disabledAttr = isEnabled ? "" : "disabled"
        let buttonSpansWidth = (style.width != nil)
            || (parentAxis == .vertical && crossFill)
            || (parentAxis == .horizontal && expandInParent && fillInParent)
            || childFills
        let widthCSS: String
        if let w = style.width {
            widthCSS = "width: \(w)px; min-width: \(w)px; max-width: \(w)px;"
        } else if buttonSpansWidth {
            widthCSS = "width: 100%;"
        } else {
            widthCSS = "width: auto;"
        }
        let heightCSS: String
        if let h = style.height {
            heightCSS = "height: \(h)px; min-height: \(h)px; max-height: \(h)px;"
        } else {
            heightCSS = ""
        }
        let alignItemsCSS = (customChild != nil && childFills) ? "stretch" : flexAlign

        let btnHTML = """
        <button type="button" class="k-btn" data-action-id="\(actionID)" \(disabledAttr)
            onclick="window.kindleTap('\(actionID)', event)"
            style="\(bgCSS) \(borderCSS) \(radiusCSS) \(shadowCSS) \(widthCSS) \(heightCSS) padding: \(innerPad.top)px \(innerPad.trailing)px \(innerPad.bottom)px \(innerPad.leading)px; align-items: \(alignItemsCSS);">
            \(innerHTML)
        </button>
        """

        var wrapperStyle = ViewStyle()
        wrapperStyle.padding = outerPad
        wrapperStyle.expand = style.expand
        wrapperStyle.fill = style.fill
        wrapperStyle.expandHorizontally = style.expandHorizontally
        wrapperStyle.expandVertically = style.expandVertically
        wrapperStyle.fillHorizontally = style.fillHorizontally
        wrapperStyle.fillVertically = style.fillVertically
        wrapperStyle.alignment = style.alignment

        return applyOuterLayoutWrapperHTML(
            innerHTML: btnHTML,
            style: wrapperStyle,
            path: path,
            parentAxis: parentAxis,
            expandInParent: expandInParent,
            fillInParent: fillInParent,
            crossFill: crossFill,
            parentHAlign: parentHAlign,
            parentVAlign: parentVAlign,
            isEnabled: isEnabled
        )
    }

    internal func buildStyledToggleHTML(
        actionID: String,
        label: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void,
        style: ViewStyle,
        ctx: RenderContext,
        isEnabled: Bool,
        path: String,
        parentAxis: LayoutAxis,
        expandInParent: Bool,
        fillInParent: Bool,
        crossFill: Bool,
        parentHAlign: HorizontalAlignment,
        parentVAlign: VerticalAlignment
    ) -> String {
        let theme = KindleTheme.current
        let toggleStyle = style.toggleStyle ?? ctx.toggleStyle ?? .switch
        let isDisabled = !isEnabled

        if toggleStyle == .button {
            var btnStyle = style
            btnStyle.buttonStyle = isOn ? .borderedProminent : .bordered
            let tapID = "tglbtn_\(path)"
            if isEnabled {
                tapActions[tapID] = { onToggle(!isOn) }
            }
            return buildStyledButtonHTML(
                actionID: tapID,
                label: label,
                customChild: nil,
                style: btnStyle,
                ctx: ctx,
                isEnabled: isEnabled,
                path: path,
                parentAxis: parentAxis,
                expandInParent: expandInParent,
                fillInParent: fillInParent,
                crossFill: crossFill,
                parentHAlign: parentHAlign,
                parentVAlign: parentVAlign
            )
        }

        let effectiveFont = style.font ?? ctx.font ?? .body
        let effectiveFg = style.foregroundColor ?? ctx.fg ?? (isDisabled ? theme.mutedForeground : theme.foreground)
        let effectiveBg = style.backgroundColor ?? ctx.bg
        let nextVal = isOn ? "false" : "true"
        let clickAttr = isEnabled ? "onclick=\"window.kindleToggle('\(actionID)', \(nextVal), event)\"" : ""

        let indicatorHTML: String
        if toggleStyle == .checkbox {
            let boxBg = isOn ? effectiveFg.hexString : effectiveBg.hexString
            let checkColor = effectiveFg.grayLevel < 128 ? "#FFFFFF" : "#000000"
            let checkSVG = isOn ? """
            <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="\(checkColor)" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 12 10 18 20 6"/></svg>
            """ : ""
            indicatorHTML = """
            <div class="k-checkbox" style="width: 52px; height: 52px; border: 3px solid \(effectiveFg.hexString); border-radius: 12px; background: \(boxBg); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">\(checkSVG)</div>
            """
        } else {
            let trackBg = isOn ? effectiveFg.hexString : theme.panelBackground.hexString
            let knobColor = isOn ? (effectiveFg.grayLevel < 128 ? "#FFFFFF" : "#000000") : effectiveFg.hexString
            let knobLeft = isOn ? "54px" : "6px"
            indicatorHTML = """
            <div class="k-switch" style="width: 104px; height: 56px; border-radius: 28px; border: 3px solid \(effectiveFg.hexString); background: \(trackBg); position: relative; flex-shrink: 0;">
                <div style="width: 38px; height: 38px; border-radius: 50%; background: \(knobColor); position: absolute; top: 6px; left: \(knobLeft);"></div>
            </div>
            """
        }

        let innerPad = style.contentPadding ?? EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        let bgCSS = style.backgroundColor != nil ? "background-color: \(effectiveBg.hexString);" : "background-color: transparent;"
        let borderCSS = style.borderWidth > 0 ? "border: \(style.borderWidth)px solid \((style.borderColor ?? theme.border).hexString);" : ""
        let radiusCSS = "border-radius: \(style.cornerRadius ?? 10)px;"

        let rowHTML = """
        <div class="k-hbox k-toggle-row" style="gap: 24px; align-items: center; justify-content: space-between; width: 100%; padding: \(innerPad.top)px \(innerPad.trailing)px \(innerPad.bottom)px \(innerPad.leading)px; \(bgCSS) \(borderCSS) \(radiusCSS) cursor: \(isEnabled ? "pointer" : "default");" \(clickAttr)>
            <div class="k-label" style="\(Self.fontCSS(for: effectiveFont)) color: \(effectiveFg.hexString); flex: 1; text-align: left; white-space: pre;">\(Self.escapeHTML(label))</div>
            \(indicatorHTML)
        </div>
        """

        var wrapperStyle = ViewStyle()
        wrapperStyle.padding = style.padding
        wrapperStyle.width = style.width
        wrapperStyle.height = style.height
        return applyOuterLayoutWrapperHTML(
            innerHTML: rowHTML,
            style: wrapperStyle,
            path: path,
            parentAxis: parentAxis,
            expandInParent: expandInParent,
            fillInParent: fillInParent,
            crossFill: crossFill,
            parentHAlign: parentHAlign,
            parentVAlign: parentVAlign,
            isEnabled: isEnabled
        )
    }

    // MARK: - General ViewStyle Application (`applyStyle` 1:1 with `GTK2Renderer.swift` lines 1541–1655)

    internal func applyViewStyleHTML(
        coreHTML: String,
        node: RenderNode,
        style: ViewStyle,
        ctx: RenderContext,
        path: String,
        parentAxis: LayoutAxis,
        expandInParent: Bool,
        fillInParent: Bool,
        crossFill: Bool,
        parentHAlign: HorizontalAlignment,
        parentVAlign: VerticalAlignment
    ) -> String {
        let theme = KindleTheme.current
        let isEnabled = !style.isDisabled && !ctx.isDisabled && !ctx.isBehindModal
        var current = coreHTML

        let isScrollView: Bool = {
            if case .scrollView = node { return true }
            return false
        }()

        let hasStyledBox = (!isScrollView && style.backgroundColor != nil)
            || (style.borderWidth > 0)
            || ((style.cornerRadius ?? 0) > 0)
            || (style.unevenCorners != nil)
            || style.isEllipse
            || (style.shadow != nil)
            || (style.contentPadding != nil)
            || (style.width != nil)
            || (style.height != nil)

        if hasStyledBox {
            let innerPad = style.contentPadding ?? EdgeInsets()
            var css: [String] = [
                "display: flex",
                "flex-direction: column",
                "box-sizing: border-box",
                "min-width: 0"
            ]
            if isScrollView || (expandInParent && fillInParent) {
                css.append("flex: 1 1 0")
                css.append("min-height: 0")
            }
            if let w = style.width {
                css.append("width: \(w)px")
                css.append("min-width: \(w)px")
                css.append("max-width: \(w)px")
            } else if (parentAxis == .vertical && crossFill) || (parentAxis == .horizontal && expandInParent && fillInParent) {
                css.append("width: 100%")
            }
            if let h = style.height {
                css.append("height: \(h)px")
                css.append("min-height: \(h)px")
                css.append("max-height: \(h)px")
                css.append("justify-content: center")
            }
            if !isScrollView, let bg = style.backgroundColor {
                let blendedBg = ctx.blend(bg, localOpacity: style.opacity)
                css.append("background-color: \(blendedBg.hexString)")
            }
            if style.borderWidth > 0 {
                let borderCol = ctx.blend(style.borderColor ?? theme.border, localOpacity: style.opacity)
                css.append("border: \(style.borderWidth)px solid \(borderCol.hexString)")
            }
            if style.isEllipse {
                css.append("border-radius: 9999px")
                css.append("overflow: hidden")
            } else if let uc = style.unevenCorners {
                css.append("border-radius: \(uc.topLeading)px \(uc.topTrailing)px \(uc.bottomTrailing)px \(uc.bottomLeading)px")
                css.append("overflow: hidden")
            } else if let cr = style.cornerRadius, cr > 0 {
                css.append("border-radius: \(cr)px")
                css.append("overflow: hidden")
            }
            if let sh = style.shadow, (sh.x != 0 || sh.y != 0 || sh.radius > 0) {
                let sCol = ctx.blend(sh.color, localOpacity: style.opacity)
                css.append("box-shadow: \(sh.x)px \(sh.y)px 0px \(sCol.hexString)")
            }
            if innerPad.top != 0 || innerPad.bottom != 0 || innerPad.leading != 0 || innerPad.trailing != 0 {
                css.append("padding: \(innerPad.top)px \(innerPad.trailing)px \(innerPad.bottom)px \(innerPad.leading)px")
            }
            css.append("align-items: stretch")

            current = """
            <div class="k-styled-box" style="\(css.joined(separator: "; "));">\(current)</div>
            """
        }

        var outerStyle = style
        if hasStyledBox {
            outerStyle.width = nil
            outerStyle.height = nil
        }

        return applyOuterLayoutWrapperHTML(
            innerHTML: current,
            style: outerStyle,
            path: path,
            parentAxis: parentAxis,
            expandInParent: expandInParent,
            fillInParent: fillInParent,
            crossFill: crossFill,
            parentHAlign: parentHAlign,
            parentVAlign: parentVAlign,
            isEnabled: isEnabled
        )
    }

    internal func applyOuterLayoutWrapperHTML(
        innerHTML: String,
        style: ViewStyle,
        path: String,
        parentAxis: LayoutAxis,
        expandInParent: Bool,
        fillInParent: Bool,
        crossFill: Bool,
        parentHAlign: HorizontalAlignment,
        parentVAlign: VerticalAlignment,
        isEnabled: Bool
    ) -> String {
        var outerCSS: [String] = [
            "display: flex",
            "flex-direction: column",
            "box-sizing: border-box",
            "min-width: 0"
        ]

        switch parentAxis {
        case .vertical:
            if expandInParent {
                outerCSS.append("flex: 1 1 0")
                outerCSS.append("min-height: 0")
                if !fillInParent {
                    outerCSS.append("justify-content: center")
                }
            } else {
                outerCSS.append("flex: 0 0 auto")
            }
            if crossFill && style.width == nil {
                outerCSS.append("align-self: stretch")
                outerCSS.append("width: 100%")
                outerCSS.append("align-items: stretch")
            } else {
                let hAlign = style.alignment?.horizontal ?? parentHAlign
                switch hAlign {
                case .leading:
                    outerCSS.append("align-self: flex-start")
                    outerCSS.append("align-items: flex-start")
                case .center:
                    outerCSS.append("align-self: center")
                    outerCSS.append("align-items: center")
                case .trailing:
                    outerCSS.append("align-self: flex-end")
                    outerCSS.append("align-items: flex-end")
                }
            }

        case .horizontal:
            if expandInParent {
                outerCSS.append("flex: 1 1 0")
                outerCSS.append("min-width: 0")
                if fillInParent {
                    outerCSS.append("align-items: stretch")
                } else {
                    outerCSS.append("align-items: center")
                }
            } else {
                outerCSS.append("flex: 0 0 auto")
                outerCSS.append("align-items: stretch")
            }
            if crossFill && style.height == nil {
                outerCSS.append("align-self: stretch")
            } else {
                let vAlign = style.alignment?.vertical ?? parentVAlign
                switch vAlign {
                case .top: outerCSS.append("align-self: flex-start")
                case .center: outerCSS.append("align-self: center")
                case .bottom: outerCSS.append("align-self: flex-end")
                }
            }

        case .zstack:
            if style.width == nil && (style.fillHorizontally ?? style.expandHorizontally ?? style.fill) {
                outerCSS.append("width: 100%")
                outerCSS.append("align-items: stretch")
            }
            if style.height == nil && (style.fillVertically ?? style.expandVertically ?? style.expand) {
                outerCSS.append("height: 100%")
                outerCSS.append("flex: 1 1 0")
                outerCSS.append("min-height: 0")
            }
        }

        if let w = style.width {
            outerCSS.append("width: \(w)px")
            outerCSS.append("min-width: \(w)px")
            outerCSS.append("max-width: \(w)px")
        }
        if let h = style.height {
            outerCSS.append("height: \(h)px")
            outerCSS.append("min-height: \(h)px")
            outerCSS.append("max-height: \(h)px")
        }

        if let pad = style.padding,
           (pad.top != 0 || pad.bottom != 0 || pad.leading != 0 || pad.trailing != 0) {
            outerCSS.append("padding: \(pad.top)px \(pad.trailing)px \(pad.bottom)px \(pad.leading)px")
        }

        var gestureAttrs: [String] = []
        if isEnabled {
            if let onTap = style.onTapGesture {
                let tapID = "gtap_\(path)"
                tapActions[tapID] = onTap
                gestureAttrs.append("data-tap-id=\"\(tapID)\"")
                outerCSS.append("cursor: pointer")
            }
            if let onLP = style.onLongPressGesture {
                let lpID = "glp_\(path)"
                longPressActions[lpID] = onLP
                gestureAttrs.append("data-lp-id=\"\(lpID)\"")
                outerCSS.append("cursor: pointer")
            }
            if let onSL = style.onSwipeLeft {
                let slID = "gsl_\(path)"
                swipeLeftActions[slID] = onSL
                gestureAttrs.append("data-swipe-left-id=\"\(slID)\"")
            }
            if let onSR = style.onSwipeRight {
                let srID = "gsr_\(path)"
                swipeRightActions[srID] = onSR
                gestureAttrs.append("data-swipe-right-id=\"\(srID)\"")
            }
            if let onSU = style.onSwipeUp {
                let suID = "gsu_\(path)"
                swipeUpActions[suID] = onSU
                gestureAttrs.append("data-swipe-up-id=\"\(suID)\"")
            }
            if let onSD = style.onSwipeDown {
                let sdID = "gsd_\(path)"
                swipeDownActions[sdID] = onSD
                gestureAttrs.append("data-swipe-down-id=\"\(sdID)\"")
            }
        }

        let attrStr = gestureAttrs.isEmpty ? "" : " " + gestureAttrs.joined(separator: " ")
        return """
        <div class="k-node"\(attrStr) style="\(outerCSS.joined(separator: "; "));">\(innerHTML)</div>
        """
    }

    // MARK: - Expansion & Alignment Flag Calculation (1:1 with GTK2Renderer.swift lines 1683–1798)

    internal func nodeWantsFullWidth(_ node: RenderNode) -> Bool {
        if case .spacer = node { return true }
        if let s = node.styleSnapshot, (s.expandHorizontally == true || s.fillHorizontally == true || s.expand) {
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

    internal func childFillsHorizontallyInVStack(_ child: RenderNode, defaultAlignment: HorizontalAlignment) -> Bool {
        if case .text(_, let wrap, let textAlign, let s) = child, s.backgroundColor == nil, s.borderWidth == 0 {
            if s.width != nil && s.expandHorizontally != true {
                return false
            }
            if defaultAlignment != .leading && textAlign == .leading && !wrap && s.fillHorizontally != true && s.expandHorizontally != true {
                return false
            }
            return wrap || (s.fillHorizontally ?? s.fill)
        }
        if case .icon = child {
            return false
        }
        if case .hstack(_, _, let children, let s) = child {
            if s.width != nil && s.expandHorizontally != true {
                return false
            }
            if let fillH = s.fillHorizontally { return fillH }
            if let expH = s.expandHorizontally { return expH }
            if !s.fill { return false }
            // Inside a centered VStack, an HStack without a Spacer or expanding child
            // (e.g. a centered pair of action buttons) shrinks to fit so it centers cleanly.
            if defaultAlignment == .center && s.backgroundColor == nil && s.borderWidth == 0 && !children.contains(where: { nodeWantsFullWidth($0) }) {
                return false
            }
            return true
        }
        if case .vstack(_, _, _, let s) = child {
            if s.width != nil && s.expandHorizontally != true {
                return false
            }
            if let fillH = s.fillHorizontally { return fillH }
            if s.expand && !s.fill {
                // .expand(true, fill: false) on a VStack inside a VStack means vertical centering,
                // while still spanning the horizontal width.
                return true
            }
            return s.fill
        }
        if let s = child.styleSnapshot {
            if s.width != nil && s.expandHorizontally != true {
                return false
            }
            return s.fillHorizontally ?? s.expandHorizontally ?? s.fill
        }
        return true
    }

    internal func childFillsVerticallyInHStack(_ child: RenderNode, defaultAlignment: VerticalAlignment) -> Bool {
        let s = child.styleSnapshot
        switch child {
        case .button, .toggle, .slider, .progressBar, .icon, .text:
            return s?.fillVertically == true || s?.expandVertically == true
        default:
            if let s = s {
                let fillsV = s.fillVertically ?? s.fill
                let expandsV = s.expandVertically ?? s.expand
                if s.height != nil || !fillsV || (s.backgroundColor != nil && !expandsV) {
                    return false
                }
                return true
            }
            return false
        }
    }

    internal func verticalExpansionFlags(for node: RenderNode) -> (expand: Bool, fill: Bool) {
        if case .spacer = node { return (true, true) }
        if let s = node.styleSnapshot {
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
        if let s = node.styleSnapshot {
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
             .webView(_, _, _, _, _, _, _, let style),
             .vstack(_, _, _, let style),
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

    // MARK: - Typography, Pango Markup, and Cairo Vector Icons

    internal static func fontCSS(for font: KindleFont) -> String {
        let px = Int((Double(font.sizePoints) * 2.75).rounded())
        let familyLower = font.family.lowercased()
        let fontStack: String
        if familyLower.contains("mono") || familyLower.contains("courier") {
            fontStack = "'JetBrains Mono', 'SF Mono', 'Menlo', 'Consolas', monospace"
        } else if familyLower.contains("sans") || familyLower.contains("helvetica") || familyLower.contains("ember") {
            fontStack = "'Amazon Ember', 'Helvetica Neue', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
        } else {
            fontStack = "'Bookerly', 'Charter', 'Georgia', 'Noto Serif', 'Times New Roman', serif"
        }
        let weight = font.isBold ? "700" : "400"
        let style = font.isItalic ? "italic" : "normal"
        return "font-family: \(fontStack); font-size: \(px)px; font-weight: \(weight); font-style: \(style); line-height: 1.28;"
    }

    internal static func escapeHTML(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&#39;")
            default: out.append(ch)
            }
        }
        return out
    }

    internal static func pangoMarkupToHTML(_ markup: String) -> String {
        var s = markup
        s = s.replacingOccurrences(of: "<tt>", with: "<code class=\"k-tt\">")
        s = s.replacingOccurrences(of: "</tt>", with: "</code>")
        while let range = s.range(of: "<span foreground=\"") {
            let afterStart = range.upperBound
            if let endQuote = s[afterStart...].firstIndex(of: "\"") {
                let colorVal = String(s[afterStart..<endQuote])
                let fullMatch = s.index(after: endQuote)
                if fullMatch <= s.endIndex && s[endQuote] == "\"" {
                    s.replaceSubrange(range.lowerBound..<fullMatch, with: "<span style=\"color:\(colorVal)\"")
                    continue
                }
            }
            break
        }
        return s
    }

    internal static func renderSVGIcon(_ icon: KindleIconName, size: Int, fg: EInkColor, bg: EInkColor?) -> String {
        let px = Int((Double(max(9, size)) * 1.35).rounded())
        let stroke = fg.hexString
        let bgStyle = bg.map { "background-color: \($0.hexString); border-radius: 6px;" } ?? ""
        let sw = "2.2"
        let paths: String
        switch icon {
        case .wifi:
            paths = """
            <path d="M2 8.82a15 15 0 0 1 20 0"/><path d="M5 12.859a10 10 0 0 1 14 0"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><circle cx="12" cy="20" r="1.4" fill="\(stroke)"/>
            """
        case .battery:
            paths = """
            <rect x="2" y="6" width="18" height="12" rx="2"/><line x1="22" y1="10" x2="22" y2="14" stroke-width="2.5"/><rect x="4.5" y="8.5" width="11" height="7" fill="\(stroke)" stroke="none"/>
            """
        case .sun:
            paths = """
            <circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>
            """
        case .moon:
            paths = """
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
            """
        case .refresh:
            paths = """
            <path d="M21 12a9 9 0 1 1-2.64-6.36"/><polyline points="21 3 21 9 15 9"/>
            """
        case .chevronLeft:
            paths = "<polyline points=\"15 18 9 12 15 6\"/>"
        case .chevronRight:
            paths = "<polyline points=\"9 18 15 12 9 6\"/>"
        case .chevronDown:
            paths = "<polyline points=\"6 9 12 15 18 9\"/>"
        case .chevronUp:
            paths = "<polyline points=\"18 15 12 9 6 15\"/>"
        case .search:
            paths = "<circle cx=\"11\" cy=\"11\" r=\"7\"/><line x1=\"21\" y1=\"21\" x2=\"16.05\" y2=\"16.05\"/>"
        case .bookmark:
            paths = "<path d=\"M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z\"/>"
        case .bookmarkFill:
            paths = "<path d=\"M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z\" fill=\"\(stroke)\"/>"
        case .check:
            paths = "<polyline points=\"20 6 9 17 4 12\"/>"
        case .warning:
            paths = "<path d=\"M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z\"/><line x1=\"12\" y1=\"9\" x2=\"12\" y2=\"13\"/><circle cx=\"12\" cy=\"17\" r=\"1\" fill=\"\(stroke)\"/>"
        case .info:
            paths = "<circle cx=\"12\" cy=\"12\" r=\"9\"/><line x1=\"12\" y1=\"16\" x2=\"12\" y2=\"11\"/><circle cx=\"12\" cy=\"8\" r=\"1\" fill=\"\(stroke)\"/>"
        case .book:
            paths = "<path d=\"M2 4h7a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H2z\"/><path d=\"M22 4h-7a3 3 0 0 0-3 3v13a2 2 0 0 1 2-2h8z\"/>"
        case .globe:
            paths = "<circle cx=\"12\" cy=\"12\" r=\"9\"/><line x1=\"3\" y1=\"12\" x2=\"21\" y2=\"12\"/><path d=\"M12 3a14 14 0 0 1 0 18\"/><path d=\"M12 3a14 14 0 0 0 0 18\"/>"
        case .cloud:
            paths = "<path d=\"M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z\"/>"
        case .gear:
            paths = "<circle cx=\"12\" cy=\"12\" r=\"3.5\"/><path d=\"M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1\"/>"
        case .sliders:
            paths = "<line x1=\"4\" y1=\"6\" x2=\"20\" y2=\"6\"/><line x1=\"4\" y1=\"12\" x2=\"20\" y2=\"12\"/><line x1=\"4\" y1=\"18\" x2=\"20\" y2=\"18\"/><circle cx=\"9\" cy=\"6\" r=\"2.2\" fill=\"\(stroke)\"/><circle cx=\"15\" cy=\"12\" r=\"2.2\" fill=\"\(stroke)\"/><circle cx=\"11\" cy=\"18\" r=\"2.2\" fill=\"\(stroke)\"/>"
        case .plus:
            paths = "<line x1=\"12\" y1=\"5\" x2=\"12\" y2=\"19\"/><line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"/>"
        case .minus:
            paths = "<line x1=\"5\" y1=\"12\" x2=\"19\" y2=\"12\"/>"
        case .close:
            paths = "<line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\"/><line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\"/>"
        case .star:
            paths = "<polygon points=\"12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2\"/>"
        case .bolt:
            paths = "<polygon points=\"13 2 3 14 12 14 11 22 21 10 12 10 13 2\"/>"
        case .pencil:
            paths = "<path d=\"M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z\"/>"
        case .share:
            paths = "<path d=\"M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8\"/><polyline points=\"16 6 12 2 8 6\"/><line x1=\"12\" y1=\"2\" x2=\"12\" y2=\"15\"/>"
        case .folder:
            paths = "<path d=\"M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z\"/>"
        case .document:
            paths = "<path d=\"M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z\"/><polyline points=\"14 2 14 8 20 8\"/><line x1=\"8\" y1=\"13\" x2=\"16\" y2=\"13\"/><line x1=\"8\" y1=\"17\" x2=\"14\" y2=\"17\"/>"
        case .calendar:
            paths = "<rect x=\"3\" y=\"4\" width=\"18\" height=\"18\" rx=\"2\"/><line x1=\"16\" y1=\"2\" x2=\"16\" y2=\"6\"/><line x1=\"8\" y1=\"2\" x2=\"8\" y2=\"6\"/><line x1=\"3\" y1=\"10\" x2=\"21\" y2=\"10\"/>"
        }
        return """
        <div class="k-icon" style="width: \(px)px; height: \(px)px; min-width: \(px)px; min-height: \(px)px; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; \(bgStyle)">
            <svg viewBox="0 0 24 24" width="\(px)" height="\(px)" fill="none" stroke="\(stroke)" stroke-width="\(sw)" stroke-linecap="round" stroke-linejoin="round">\(paths)</svg>
        </div>
        """
    }

    // MARK: - 24-bit Uncompressed BMP Encoder for KindleCanvasBuffer

    internal static func encodeGrayscaleBMP(width: Int, height: Int, pixels: [UInt8]) -> Data {
        let w = max(1, width)
        let h = max(1, height)
        let rowStride = (w * 3 + 3) & ~3
        let imageSize = rowStride * h
        let fileSize = 54 + imageSize
        var data = Data(count: fileSize)
        data.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            ptr[0] = 0x42 // 'B'
            ptr[1] = 0x4D // 'M'
            writeUInt32LE(ptr, offset: 2, value: UInt32(fileSize))
            writeUInt32LE(ptr, offset: 10, value: 54)
            writeUInt32LE(ptr, offset: 14, value: 40)
            writeInt32LE(ptr, offset: 18, value: Int32(w))
            writeInt32LE(ptr, offset: 22, value: -Int32(h)) // top-down DIB
            ptr[26] = 1
            ptr[27] = 0
            ptr[28] = 24
            ptr[29] = 0
            writeUInt32LE(ptr, offset: 34, value: UInt32(imageSize))

            let count = pixels.count
            for y in 0..<h {
                let dstRow = 54 + y * rowStride
                let srcRow = y * w
                for x in 0..<w {
                    let idx = srcRow + x
                    let g: UInt8 = idx < count ? pixels[idx] : 255
                    let pxOffset = dstRow + x * 3
                    ptr[pxOffset] = g
                    ptr[pxOffset + 1] = g
                    ptr[pxOffset + 2] = g
                }
            }
        }
        return data
    }

    internal static func writeUInt32LE(_ ptr: UnsafeMutablePointer<UInt8>, offset: Int, value: UInt32) {
        ptr[offset] = UInt8(truncatingIfNeeded: value)
        ptr[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        ptr[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        ptr[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    internal static func writeInt32LE(_ ptr: UnsafeMutablePointer<UInt8>, offset: Int, value: Int32) {
        writeUInt32LE(ptr, offset: offset, value: UInt32(bitPattern: value))
    }


}
