import Foundation

// MARK: - Structural comparison of render trees
//
// `GTK2Renderer` used to destroy and recreate every GTK widget on each state change. On an e-ink
// device that is by far the most expensive thing KindleUI does. The helpers below let the renderer
// decide whether a freshly evaluated tree differs from the mounted one *structurally* (anything that
// needs a different widget or different widget styling) or only in *live content* (label text,
// progress fractions) that can be patched in place, and re-bind closures without rebuilding.
//
// Everything that is not explicitly ignored is compared, and unknown/new node kinds compare as
// "different", so the failure mode of a missed case is an unnecessary (but correct) rebuild.

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

    /// Compares everything that influences how a node is rendered. Closures are compared by presence only
    /// (they are re-bound separately), and `pangoMarkup` is ignored because it is live label content.
    internal func isStructurallyEqual(to o: ViewStyle) -> Bool {
        guard font == o.font,
              foregroundColor == o.foregroundColor,
              backgroundColor == o.backgroundColor,
              borderColor == o.borderColor,
              borderWidth == o.borderWidth,
              cornerRadius == o.cornerRadius,
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
              swipeThresholdPx == o.swipeThresholdPx
        else { return false }

        switch (unevenCorners, o.unevenCorners) {
        case (nil, nil): break
        case let (a?, b?):
            guard a.topLeading == b.topLeading, a.topTrailing == b.topTrailing,
                  a.bottomTrailing == b.bottomTrailing, a.bottomLeading == b.bottomLeading
            else { return false }
        default: return false
        }

        guard (onSubmitHandler == nil) == (o.onSubmitHandler == nil),
              (onAppear == nil) == (o.onAppear == nil),
              (onDisappear == nil) == (o.onDisappear == nil),
              (onTapGesture == nil) == (o.onTapGesture == nil),
              (onLongPressGesture == nil) == (o.onLongPressGesture == nil),
              (onSwipeLeft == nil) == (o.onSwipeLeft == nil),
              (onSwipeRight == nil) == (o.onSwipeRight == nil),
              (onSwipeUp == nil) == (o.onSwipeUp == nil),
              (onSwipeDown == nil) == (o.onSwipeDown == nil),
              (onDragChanged == nil) == (o.onDragChanged == nil),
              (onDragEnded == nil) == (o.onDragEnded == nil)
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
        switch (self, other) {
        case (.empty, .empty):
            return true
        case let (.group(a), .group(b)):
            return RenderNode.nodesAreStructurallyEqual(a, b)
        case let (.vstack(a1, s1, c1, st1), .vstack(a2, s2, c2, st2)):
            return a1 == a2 && s1 == s2 && st1.isStructurallyEqual(to: st2)
                && RenderNode.nodesAreStructurallyEqual(c1, c2)
        case let (.hstack(a1, s1, c1, st1), .hstack(a2, s2, c2, st2)):
            return a1 == a2 && s1 == s2 && st1.isStructurallyEqual(to: st2)
                && RenderNode.nodesAreStructurallyEqual(c1, c2)
        case let (.zstack(a1, c1, st1), .zstack(a2, c2, st2)):
            return a1 == a2 && st1.isStructurallyEqual(to: st2)
                && RenderNode.nodesAreStructurallyEqual(c1, c2)
        case let (.scrollView(i1, c1, st1), .scrollView(i2, c2, st2)):
            return i1 == i2 && st1.isStructurallyEqual(to: st2) && c1.isStructurallyEqual(to: c2)
        case let (.card(t1, c1, st1), .card(t2, c2, st2)):
            return t1 == t2 && st1.isStructurallyEqual(to: st2) && c1.isStructurallyEqual(to: c2)
        case let (.text(_, w1, a1, st1), .text(_, w2, a2, st2)):
            return w1 == w2 && a1 == a2 && st1.isStructurallyEqual(to: st2)
        case let (.button(l1, c1, _, st1), .button(l2, c2, _, st2)):
            guard l1 == l2, st1.isStructurallyEqual(to: st2) else { return false }
            switch (c1, c2) {
            case (nil, nil): return true
            case let (x?, y?): return x.isStructurallyEqual(to: y)
            default: return false
            }
        case let (.toggle(l1, on1, _, st1), .toggle(l2, on2, _, st2)):
            return l1 == l2 && on1 == on2 && st1.isStructurallyEqual(to: st2)
        case let (.textField(p1, t1, _, st1), .textField(p2, t2, _, st2)):
            return p1 == p2 && t1 == t2 && st1.isStructurallyEqual(to: st2)
        case let (.textEditor(t1, m1, _, st1), .textEditor(t2, m2, _, st2)):
            return t1 == t2 && m1 == m2 && st1.isStructurallyEqual(to: st2)
        case let (.slider(v1, r1, s1, _, st1), .slider(v2, r2, s2, _, st2)):
            return v1 == v2 && r1 == r2 && s1 == s2 && st1.isStructurallyEqual(to: st2)
        case let (.progressBar(_, t1, st1), .progressBar(_, t2, st2)):
            return (t1?.isEmpty ?? true) == (t2?.isEmpty ?? true) && st1.isStructurallyEqual(to: st2)
        case let (.divider(v1, st1), .divider(v2, st2)):
            return v1 == v2 && st1.isStructurallyEqual(to: st2)
        case let (.spacer(m1, st1), .spacer(m2, st2)):
            return m1 == m2 && st1.isStructurallyEqual(to: st2)
        case let (.image(p1, a1, st1), .image(p2, a2, st2)):
            return p1 == p2 && a1 == a2 && st1.isStructurallyEqual(to: st2)
        case let (.icon(i1, s1, st1), .icon(i2, s2, st2)):
            return i1 == i2 && s1 == s2 && st1.isStructurallyEqual(to: st2)
        case let (.canvas(b1, l1, _, _, st1), .canvas(b2, l2, _, _, st2)):
            return b1 === b2 && l1 == l2 && st1.isStructurallyEqual(to: st2)
        case let (.webView(id1, u1, h1, b1, z1, m1, _, st1), .webView(id2, u2, h2, b2, z2, m2, _, st2)):
            return id1 == id2 && u1 == u2 && h1 == h2 && b1 == b2 && z1 == z2 && m1 == m2
                && st1.isStructurallyEqual(to: st2)
        default:
            return false
        }
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
