import Foundation

// MARK: - Structural comparison of render trees

extension ViewStyle {
    /// Names of every stored property of `ViewStyle`. `isStructurallyEqual(to:)` must account for each of
    /// them; `RenderTreeDiffTests` checks this list against reflection so that a newly added style field
    /// can't silently be left out of the comparison.
    internal static let structuralFieldNames: Set<String> = [
        "font", "foregroundColor", "backgroundColor", "borderColor", "borderWidth", "cornerRadius",
        "unevenCorners", "isEllipse", "shadow", "contentPadding", "padding", "width", "height",
        "expand", "fill", "expandHorizontally", "expandVertically", "fillHorizontally",
        "fillVertically", "homogeneous", "isDisabled", "isHidden", "isModalOverlay",
        "isFullScreenModal", "hasModalScrim", "opacity", "buttonStyle", "controlSize", "pickerStyle",
        "toggleStyle", "tabViewStyle", "tintColor", "alignment", "windowConfig", "colorScheme",
        "refreshPolicy", "navigationTitle", "toolbarNodes", "pangoMarkup", "explicitID",
        "onSubmitHandler", "onAppear", "onDisappear", "onTapGesture", "onLongPressGesture",
        "longPressDurationMs", "onSwipeLeft", "onSwipeRight", "onSwipeUp", "onSwipeDown",
        "swipeThresholdPx", "onDragChanged", "onDragEnded",
    ]

    private var handlerPresenceMask: UInt16 {
        var mask: UInt16 = 0
        if onSubmitHandler != nil    { mask |= 1 << 0 }
        if onAppear != nil           { mask |= 1 << 1 }
        if onDisappear != nil        { mask |= 1 << 2 }
        if onTapGesture != nil       { mask |= 1 << 3 }
        if onLongPressGesture != nil { mask |= 1 << 4 }
        if onSwipeLeft != nil        { mask |= 1 << 5 }
        if onSwipeRight != nil       { mask |= 1 << 6 }
        if onSwipeUp != nil          { mask |= 1 << 7 }
        if onSwipeDown != nil        { mask |= 1 << 8 }
        if onDragChanged != nil      { mask |= 1 << 9 }
        if onDragEnded != nil        { mask |= 1 << 10 }
        return mask
    }

    /// Compares everything that influences how a node is rendered. Closures are compared by presence only
    /// (they are re-bound separately), and `pangoMarkup` is ignored because it is live label content.
    internal func isStructurallyEqual(to o: ViewStyle) -> Bool {
        guard font == o.font,
              foregroundColor == o.foregroundColor,
              backgroundColor == o.backgroundColor,
              borderColor == o.borderColor,
              borderWidth == o.borderWidth,
              cornerRadius == o.cornerRadius,
              (unevenCorners == nil) == (o.unevenCorners == nil),
              unevenCorners.map({ a in o.unevenCorners.map { a == $0 } ?? false }) ?? true,
              isEllipse == o.isEllipse,
              shadow == o.shadow,
              contentPadding == o.contentPadding,
              padding == o.padding,
              width == o.width,
              height == o.height,
              expand == o.expand,
              fill == o.fill,
              expandHorizontally == o.expandHorizontally,
              expandVertically == o.expandVertically,
              fillHorizontally == o.fillHorizontally,
              fillVertically == o.fillVertically,
              homogeneous == o.homogeneous,
              isDisabled == o.isDisabled,
              isHidden == o.isHidden,
              isModalOverlay == o.isModalOverlay,
              isFullScreenModal == o.isFullScreenModal,
              hasModalScrim == o.hasModalScrim,
              opacity == o.opacity,
              buttonStyle == o.buttonStyle,
              controlSize == o.controlSize,
              pickerStyle == o.pickerStyle,
              toggleStyle == o.toggleStyle,
              tabViewStyle == o.tabViewStyle,
              tintColor == o.tintColor,
              alignment == o.alignment,
              windowConfig == o.windowConfig,
              colorScheme == o.colorScheme,
              refreshPolicy == o.refreshPolicy,
              navigationTitle == o.navigationTitle,
              explicitID == o.explicitID,
              longPressDurationMs == o.longPressDurationMs,
              swipeThresholdPx == o.swipeThresholdPx,
              handlerPresenceMask == o.handlerPresenceMask
        else { return false }

        return RenderNode.nodesAreStructurallyEqual(toolbarNodes, o.toolbarNodes)
    }
}

extension RenderNode {
    internal static func nodesAreStructurallyEqual(_ a: [RenderNode], _ b: [RenderNode]) -> Bool {
        guard a.count == b.count else { return false }
        for i in 0..<a.count where !a[i].isStructurallyEqual(to: b[i]) {
            return false
        }
        return true
    }

    /// `true` when both trees would mount the exact same widget hierarchy with identical styling.
    ///
    /// Intentionally ignored (patched in place by the renderer instead):
    /// - `.text` content and Pango markup
    /// - `.progressBar` fraction and the header text (only whether a header exists is structural)
    ///
    /// Closures are ignored here; the renderer re-binds them to the mounted widgets.
    internal func isStructurallyEqual(to other: RenderNode) -> Bool {
        let matchesNodeKind: Bool
        switch (self, other) {
        case (.empty, .empty), (.group, .group):
            matchesNodeKind = true
        case let (.vstack(a1, s1, _, _), .vstack(a2, s2, _, _)):
            matchesNodeKind = a1 == a2 && s1 == s2
        case let (.hstack(a1, s1, _, _), .hstack(a2, s2, _, _)):
            matchesNodeKind = a1 == a2 && s1 == s2
        case let (.zstack(a1, _, _), .zstack(a2, _, _)):
            matchesNodeKind = a1 == a2
        case let (.scrollView(i1, _, _), .scrollView(i2, _, _)):
            matchesNodeKind = i1 == i2
        case let (.card(t1, _, _), .card(t2, _, _)):
            matchesNodeKind = t1 == t2
        case let (.text(_, w1, a1, _), .text(_, w2, a2, _)):
            matchesNodeKind = w1 == w2 && a1 == a2
        case let (.button(l1, c1, _, _), .button(l2, c2, _, _)):
            matchesNodeKind = l1 == l2 && ((c1 == nil) == (c2 == nil))
        case let (.toggle(l1, on1, _, _), .toggle(l2, on2, _, _)):
            matchesNodeKind = l1 == l2 && on1 == on2
        case let (.textField(p1, t1, _, _), .textField(p2, t2, _, _)):
            matchesNodeKind = p1 == p2 && t1 == t2
        case let (.textEditor(t1, m1, _, _), .textEditor(t2, m2, _, _)):
            matchesNodeKind = t1 == t2 && m1 == m2
        case let (.slider(v1, r1, s1, _, _), .slider(v2, r2, s2, _, _)):
            matchesNodeKind = v1 == v2 && r1 == r2 && s1 == s2
        case let (.progressBar(_, t1, _), .progressBar(_, t2, _)):
            matchesNodeKind = (t1?.isEmpty ?? true) == (t2?.isEmpty ?? true)
        case let (.divider(v1, _), .divider(v2, _)):
            matchesNodeKind = v1 == v2
        case let (.spacer(m1, _), .spacer(m2, _)):
            matchesNodeKind = m1 == m2
        case let (.image(p1, a1, _), .image(p2, a2, _)):
            matchesNodeKind = p1 == p2 && a1 == a2
        case let (.icon(i1, s1, _), .icon(i2, s2, _)):
            matchesNodeKind = i1 == i2 && s1 == s2
        case let (.canvas(b1, l1, _, _, _), .canvas(b2, l2, _, _, _)):
            matchesNodeKind = b1 === b2 && l1 == l2
        case let (.webView(id1, u1, h1, b1, z1, m1, _, _), .webView(id2, u2, h2, b2, z2, m2, _, _)):
            matchesNodeKind = id1 == id2 && u1 == u2 && h1 == h2 && b1 == b2 && z1 == z2 && m1 == m2
        default:
            return false
        }
        guard matchesNodeKind else { return false }

        if let s1 = styleSnapshot, let s2 = other.styleSnapshot {
            guard s1.isStructurallyEqual(to: s2) else { return false }
        }
        return RenderNode.nodesAreStructurallyEqual(renderChildren, other.renderChildren)
    }

    /// Child nodes in the order `GTK2Renderer` descends into them. A node's position in this list is the
    /// index used in "node paths" that tie mounted signal handlers back to tree nodes.
    internal var renderChildren: [RenderNode] {
        switch self {
        case .group(let children),
             .vstack(_, _, let children, _),
             .hstack(_, _, let children, _),
             .zstack(_, let children, _):
            return children
        case .scrollView(_, let child, _),
             .card(_, let child, _):
            return [child]
        case .button(_, let customChild, _, _):
            return customChild.map { [$0] } ?? []
        default:
            return []
        }
    }

    /// Resolves a path of `renderChildren` indices (as recorded while mounting) to a node.
    internal func node(atPath path: [Int]) -> RenderNode? {
        var current = self
        for index in path {
            let kids = current.renderChildren
            guard kids.indices.contains(index) else { return nil }
            current = kids[index]
        }
        return current
    }

    /// Collects the live (patchable) content of the subtree in exactly the order `GTK2Renderer.buildWidget`
    /// mounts the corresponding widgets, honouring hidden nodes and full-screen modal short-circuiting.
    /// Returns `true` if the subtree contains a node that is redrawn from external mutable state
    /// (currently `.canvas`), in which case an in-place update is not safe.
    internal func collectLiveContent(
        texts: inout [(text: String, markup: String?)],
        progressBars: inout [(fraction: Double, text: String?)]
    ) -> Bool {
        if let style = styleSnapshot, style.isHidden { return false }
        switch self {
        case .text(let content, _, _, let style):
            texts.append((content, style.pangoMarkup))
            return false
        case .progressBar(let fraction, let text, _):
            progressBars.append((fraction, text))
            return false
        case .canvas:
            return true
        case .zstack(_, let children, let style):
            if style.isFullScreenModal, let top = children.last {
                return top.collectLiveContent(texts: &texts, progressBars: &progressBars)
            }
            var volatile = false
            for child in children where child.collectLiveContent(texts: &texts, progressBars: &progressBars) {
                volatile = true
            }
            return volatile
        default:
            var volatile = false
            for child in renderChildren where child.collectLiveContent(texts: &texts, progressBars: &progressBars) {
                volatile = true
            }
            return volatile
        }
    }
}
