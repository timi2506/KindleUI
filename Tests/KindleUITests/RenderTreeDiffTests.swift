import XCTest
@testable import KindleUI

final class RenderTreeDiffTests: XCTestCase {
    private func text(_ s: String, markup: String? = nil, style: ViewStyle = ViewStyle()) -> RenderNode {
        var st = style
        st.pangoMarkup = markup
        return .text(content: s, wrap: false, alignment: .leading, style: st)
    }

    private func column(_ children: [RenderNode], style: ViewStyle = ViewStyle()) -> RenderNode {
        .vstack(alignment: .leading, spacing: 4, children: children, style: style)
    }

    func testViewStyleFieldListMatchesReflection() {
        // If this fails, a stored property was added to / removed from ViewStyle: update both
        // `ViewStyle.structuralFieldNames` and `ViewStyle.isStructurallyEqual(to:)`.
        let labels = Set(Mirror(reflecting: ViewStyle()).children.compactMap { $0.label })
        XCTAssertEqual(labels, ViewStyle.structuralFieldNames)
    }

    func testTextContentAndMarkupAreNotStructural() {
        let a = column([text("Count: 1"), text("x", markup: "<b>x</b>")])
        let b = column([text("Count: 2"), text("y", markup: "<i>y</i>")])
        XCTAssertTrue(a.isStructurallyEqual(to: b))
    }

    func testStyleChangesAreStructural() {
        var bold = ViewStyle()
        bold.font = .headline
        XCTAssertFalse(text("a").isStructurallyEqual(to: text("a", style: bold)))

        var fg = ViewStyle()
        fg.foregroundColor = .black
        XCTAssertFalse(text("a").isStructurallyEqual(to: text("a", style: fg)))

        var hidden = ViewStyle()
        hidden.isHidden = true
        XCTAssertFalse(column([text("a")]).isStructurallyEqual(to: column([text("a")], style: hidden)))

        var uneven1 = ViewStyle(), uneven2 = ViewStyle()
        uneven1.unevenCorners = (1, 2, 3, 4)
        uneven2.unevenCorners = (1, 2, 3, 5)
        XCTAssertFalse(column([], style: uneven1).isStructurallyEqual(to: column([], style: uneven2)))
        XCTAssertTrue(column([], style: uneven1).isStructurallyEqual(to: column([], style: uneven1)))
    }

    func testGesturePresenceIsStructuralButClosureIdentityIsNot() {
        var withTap1 = ViewStyle(), withTap2 = ViewStyle()
        withTap1.onTapGesture = { print("one") }
        withTap2.onTapGesture = { print("two") }
        XCTAssertTrue(text("a", style: withTap1).isStructurallyEqual(to: text("a", style: withTap2)))
        XCTAssertFalse(text("a", style: withTap1).isStructurallyEqual(to: text("a")))
    }

    func testChildCountAndKindAreStructural() {
        XCTAssertFalse(column([text("a")]).isStructurallyEqual(to: column([text("a"), text("b")])))
        XCTAssertFalse(column([text("a")]).isStructurallyEqual(to: column([.spacer(minLength: nil, style: ViewStyle())])))
        XCTAssertFalse(RenderNode.empty.isStructurallyEqual(to: text("a")))
    }

    func testControlStateIsStructuralButClosuresAreNot() {
        let btn1 = RenderNode.button(label: "Go", customChild: nil, action: { print("1") }, style: ViewStyle())
        let btn2 = RenderNode.button(label: "Go", customChild: nil, action: { print("2") }, style: ViewStyle())
        let btn3 = RenderNode.button(label: "Stop", customChild: nil, action: { print("1") }, style: ViewStyle())
        XCTAssertTrue(btn1.isStructurallyEqual(to: btn2))
        XCTAssertFalse(btn1.isStructurallyEqual(to: btn3))

        let t1 = RenderNode.toggle(label: "x", isOn: true, onToggle: { _ in }, style: ViewStyle())
        let t2 = RenderNode.toggle(label: "x", isOn: false, onToggle: { _ in }, style: ViewStyle())
        XCTAssertFalse(t1.isStructurallyEqual(to: t2))

        let s1 = RenderNode.slider(value: 1, range: 0...10, step: 1, onValueChange: { _ in }, style: ViewStyle())
        let s2 = RenderNode.slider(value: 2, range: 0...10, step: 1, onValueChange: { _ in }, style: ViewStyle())
        XCTAssertFalse(s1.isStructurallyEqual(to: s2))
        XCTAssertTrue(s1.isStructurallyEqual(to: s1))
    }

    func testProgressFractionIsLiveButHeaderPresenceIsStructural() {
        let a = RenderNode.progressBar(fraction: 0.1, text: "10%", style: ViewStyle())
        let b = RenderNode.progressBar(fraction: 0.9, text: "90%", style: ViewStyle())
        let none = RenderNode.progressBar(fraction: 0.9, text: nil, style: ViewStyle())
        XCTAssertTrue(a.isStructurallyEqual(to: b))
        XCTAssertFalse(a.isStructurallyEqual(to: none))
    }

    func testCanvasIdentityAndWebViewParametersAreStructural() {
        let buf1 = KindleCanvasBuffer(), buf2 = KindleCanvasBuffer()
        func canvas(_ b: KindleCanvasBuffer) -> RenderNode {
            .canvas(buffer: b, label: "pad", onPrepare: nil, onPointer: nil, style: ViewStyle())
        }
        XCTAssertTrue(canvas(buf1).isStructurallyEqual(to: canvas(buf1)))
        XCTAssertFalse(canvas(buf1).isStructurallyEqual(to: canvas(buf2)))

        func web(_ url: String) -> RenderNode {
            .webView(id: "w", url: url, html: nil, baseURL: nil, zoomLevel: 1, minHeight: 100, onLoadFinished: nil, style: ViewStyle())
        }
        XCTAssertTrue(web("a").isStructurallyEqual(to: web("a")))
        XCTAssertFalse(web("a").isStructurallyEqual(to: web("b")))
    }

    func testCollectLiveContentFollowsMountOrder() {
        var hiddenStyle = ViewStyle()
        hiddenStyle.isHidden = true
        let tree = column([
            text("one"),
            column([text("hidden")], style: hiddenStyle),
            .progressBar(fraction: 0.5, text: "half", style: ViewStyle()),
            .button(label: "b", customChild: text("two"), action: {}, style: ViewStyle()),
            .card(title: nil, child: text("three", markup: "<b>three</b>"), style: ViewStyle()),
        ])
        var texts: [(text: String, markup: String?)] = []
        var bars: [(fraction: Double, text: String?)] = []
        let volatile = tree.collectLiveContent(texts: &texts, progressBars: &bars)
        XCTAssertFalse(volatile)
        XCTAssertEqual(texts.map { $0.text }, ["one", "two", "three"])
        XCTAssertEqual(texts.last?.markup, "<b>three</b>")
        XCTAssertEqual(bars.count, 1)
    }

    func testFullScreenModalOnlyMountsTopChild() {
        var modal = ViewStyle()
        modal.isFullScreenModal = true
        let tree = RenderNode.zstack(alignment: .center, children: [text("below"), text("top")], style: modal)
        var texts: [(text: String, markup: String?)] = []
        var bars: [(fraction: Double, text: String?)] = []
        _ = tree.collectLiveContent(texts: &texts, progressBars: &bars)
        XCTAssertEqual(texts.map { $0.text }, ["top"])
    }

    func testCanvasMakesContentVolatile() {
        let tree = column([
            text("a"),
            .canvas(buffer: KindleCanvasBuffer(), label: "pad", onPrepare: nil, onPointer: nil, style: ViewStyle()),
        ])
        var texts: [(text: String, markup: String?)] = []
        var bars: [(fraction: Double, text: String?)] = []
        XCTAssertTrue(tree.collectLiveContent(texts: &texts, progressBars: &bars))
    }

    func testNodePathResolution() {
        let inner = text("leaf")
        let tree = column([
            text("a"),
            .scrollView(showsIndicators: false, child: .card(title: nil, child: inner, style: ViewStyle()), style: ViewStyle()),
            .button(label: "b", customChild: text("in button"), action: {}, style: ViewStyle()),
        ])
        guard case .text(let c1, _, _, _)? = tree.node(atPath: [1, 0, 0]) else { return XCTFail("leaf not found") }
        XCTAssertEqual(c1, "leaf")
        guard case .text(let c2, _, _, _)? = tree.node(atPath: [2, 0]) else { return XCTFail("custom child not found") }
        XCTAssertEqual(c2, "in button")
        XCTAssertNil(tree.node(atPath: [3]))
        XCTAssertNil(tree.node(atPath: [0, 0]))
        XCTAssertNotNil(tree.node(atPath: []))
    }

    func testRealViewTreeIsStableAcrossEvaluationsApartFromText() {
        struct Demo: View {
            let n: Int
            var body: some View {
                VStack {
                    Text("Count: \(n)")
                    Button("Add") { print(n) }
                    ProgressView(value: Double(n) / 10.0)
                }
            }
        }
        let a = Demo(n: 1).buildRenderTree()
        let b = Demo(n: 7).buildRenderTree()
        XCTAssertTrue(a.isStructurallyEqual(to: b))
    }
}
