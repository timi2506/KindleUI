import XCTest
import KindleUI

final class KindleUIComponentsTests: XCTestCase {
    private enum SampleTab: String, CaseIterable {
        case home = "Home"
        case sketch = "Sketch"
    }

    func testAwesomeWindowTitleFormatting() {
        let cfg = KindleWindowConfig(
            applicationID: "org.kindlemodding.KindleShowcase",
            layer: .application,
            role: .application,
            persistentChrome: .none,
            orientations: .portrait,
            width: 1860,
            height: 2480
        )
        XCTAssertEqual(cfg.awesomeWindowTitle, "L:A_N:application_PC:N_O:UD_ID:org.kindlemodding.KindleShowcase")

        let topBarCfg = KindleWindowConfig.app(
            id: "org.kindlemodding.KindleShowcase",
            chrome: .topBar,
            orientations: .portrait
        )
        XCTAssertEqual(topBarCfg.awesomeWindowTitle, "L:A_N:application_PC:T_O:UD_ID:org.kindlemodding.KindleShowcase")
    }

    private func collectAllText(in node: RenderNode) -> String {
        var parts: [String] = []
        func walk(_ n: RenderNode) {
            switch n {
            case .empty:
                break
            case .group(let children),
                 .vstack(_, _, let children, _),
                 .hstack(_, _, let children, _),
                 .zstack(_, let children, _):
                children.forEach(walk)
            case .scrollView(_, let child, _):
                walk(child)
            case .card(let title, let child, _):
                if let title = title { parts.append(title) }
                walk(child)
            case .text(let content, _, _, _):
                parts.append(content)
            case .button(let label, let customChild, _, _):
                if !label.isEmpty { parts.append(label) }
                if let customChild = customChild { walk(customChild) }
            case .toggle(let label, _, _, _):
                parts.append(label)
            case .textField(let placeholder, let text, _, _):
                parts.append(placeholder)
                parts.append(text)
            case .textEditor(let text, _, _, _):
                parts.append(text)
            case .progressBar(_, let text, _):
                if let text = text { parts.append(text) }
            case .image(_, let altText, _):
                parts.append(altText)
            case .canvas(_, let label, _, _, _):
                parts.append(label)
            case .slider, .divider, .spacer, .icon, .webView:
                break
            }
        }
        walk(node)
        return parts.joined(separator: "\n")
    }

    func testGenericCanvasBufferResize() {
        let buffer = KindleCanvasBuffer(width: 200, height: 100, fill: 255)
        XCTAssertEqual(buffer.width, 200)
        XCTAssertEqual(buffer.height, 100)
        buffer.pixels[50 * 200 + 50] = 0

        buffer.resizeIfNeeded(width: 300, height: 150, defaultFill: 255)
        XCTAssertEqual(buffer.width, 300)
        XCTAssertEqual(buffer.height, 150)
        XCTAssertEqual(buffer.pixels[50 * 300 + 50], 0)
    }

    func testSwiftUIComponentsAndPreferredColorScheme() {
        KindleStateRegistry.shared.resetAllState()
        let buffer = KindleCanvasBuffer(width: 300, height: 200)
        var selectedTab: SampleTab = .home
        var counter: Int = 5

        let makeTree: () -> RenderNode = {
            VStack(alignment: .leading, spacing: 10) {
                KindleStatusBar(title: "KindleShowcase", subtitle: "Swift · KindleUI")
                TabView(selection: Binding(get: { selectedTab }, set: { selectedTab = $0 })) {
                    KindleTab("Home", value: .home) {
                        Form {
                            KindlePageHeader("Home", subtitle: "Subtitle")
                            Section("COUNTER") {
                                Stepper(value: Binding(get: { counter }, set: { counter = $0 }), step: 1) {
                                    Text("\(counter)")
                                }
                                LabeledContent("Kernel", value: KindleDevice.shared.kernelDescription)
                            }
                            Picker(selection: Binding(get: { selectedTab }, set: { selectedTab = $0 }))
                        }
                    }
                    KindleTab("Sketch", value: .sketch) {
                        KindleCanvas(buffer: buffer, label: "Sketch Canvas")
                    }
                }
            }
            .preferredColorScheme(.dark)
            .einkRefreshPolicy(.automatic)
            .buildRenderTree()
        }

        let tree = KindleStateRegistry.shared.evaluateTree(makeTree)
        XCTAssertEqual(KindleStateRegistry.shared.colorScheme, .dark)
        XCTAssertEqual(KindleTheme.current, .dark)

        let text = collectAllText(in: tree)
        XCTAssertTrue(text.contains("KindleShowcase"))
        XCTAssertTrue(text.contains("COUNTER"))
        XCTAssertTrue(text.contains("Kernel"))
    }

    func testSwiftUIStyleModifiersAndPaddingOrder() {
        let styledCard = VStack(alignment: .leading, spacing: 12) {
            Badge("NEW", prominent: true)
            Button("Save", role: .borderedProminent) {}
                .controlSize(.large)
                .shadow(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 12)
                .fill(.lightGray)
                .stroke(.black, lineWidth: 2)
                .frame(height: 40)
            Capsule()
                .fill(.black)
                .frame(width: 80, height: 28)
        }
        .padding(20)
        .background(.paperWhite, cornerRadius: 16)
        .border(.black, width: 2, cornerRadius: 16)
        .shadow(x: 3, y: 3)
        .padding(.horizontal, 16)
        .buildRenderTree()

        guard case .vstack(_, _, _, let style) = styledCard else {
            XCTFail("Expected VStack node")
            return
        }
        XCTAssertEqual(style.contentPadding, EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
        XCTAssertEqual(style.padding, EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        XCTAssertEqual(style.cornerRadius, 16)
        XCTAssertEqual(style.borderWidth, 2)
        XCTAssertEqual(style.shadow, KindleShadow(color: .black, radius: 0, x: 3, y: 3))
    }

    @Observable
    fileprivate final class SampleViewModel {
        var count: Int = 10
    }

    func testNavigationOverlaysGridReaderAndObservableState() {
        KindleStateRegistry.shared.resetAllState()
        let vm = SampleViewModel()
        var showAlert = true
        var showSheet = false
        var expanded = true
        var editorText = "Kindle Notes"
        var page = 0
        var tapped = false

        let makeTree: () -> RenderNode = {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Reading Hub", icon: .book)
                    NavigationLink("Open Details") {
                        Text("Detail Destination")
                    }
                    DisclosureGroup("Hardware Info", isExpanded: Binding(get: { expanded }, set: { expanded = $0 })) {
                        LabeledContent("Network", value: KindleDevice.shared.wifiSSID)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Badge("Col 1")
                        Badge("Col 2")
                        Badge("Col 3")
                        Badge("Col 4")
                    }
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            Text("R1C1")
                            Text("R1C2")
                        }
                    }
                    TextEditor(text: Binding(get: { editorText }, set: { editorText = $0 }), minHeight: 120)
                    BookReaderView(
                        title: "E-Ink Architecture",
                        text: "Electrophoretic displays reflect ambient light like paper.\n\nEach microcapsule contains charged black and white pigments.",
                        fontSize: 14,
                        wordsPerPage: 8,
                        currentPage: Binding(get: { page }, set: { page = $0 })
                    )
                    Text("Count: \(vm.count)")
                        .onTapGesture { tapped = true }
                        .onSwipeGesture(onLeft: { page += 1 }, onRight: { page = max(0, page - 1) })
                }
                .navigationTitle("Library")
            }
            .alert(
                "Pillow Alert",
                isPresented: Binding(get: { showAlert }, set: { showAlert = $0 }),
                message: "Alert body text"
            )
            .sheet(
                isPresented: Binding(get: { showSheet }, set: { showSheet = $0 }),
                title: "Sheet"
            ) {
                Text("Sheet Body")
            }
            .buildRenderTree()
        }

        let tree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let text = collectAllText(in: tree)
        XCTAssertTrue(text.contains("Reading Hub"))
        XCTAssertTrue(text.contains("Pillow Alert"))
        XCTAssertTrue(text.contains("Kindle Notes"))
        XCTAssertTrue(text.contains("Page 1 of"))
        XCTAssertFalse(tapped)

        vm.count = 42
        let updatedTree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let updatedText = collectAllText(in: updatedTree)
        XCTAssertTrue(updatedText.contains("Count: 42"))
    }

    fileprivate struct CustomGreetingKey: EnvironmentKey {
        static let defaultValue: String = "DefaultGreeting"
    }

    fileprivate struct CardFrameModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(12)
                .border(.black, width: 2, cornerRadius: 10)
        }
    }

    fileprivate struct StatefulChildView: View {
        let label: String
        @State var tapCount: Int = 0
        @Environment(SampleViewModel.self) private var vm

        var body: some View {
            Text("\(label)=\(tapCount),vm=\(vm.count)")
        }
    }

    func testStructuralIdentityEnvironmentFocusAndModernSwiftUIFeatures() {
        KindleStateRegistry.shared.resetAllState()
        let vm = SampleViewModel()
        vm.count = 99
        var showOptionalPrefix = false
        var activeIdentity = "first"
        var searchQuery = "Kindle"
        var showCover = false

        let makeTree: () -> RenderNode = {
            NavigationStack {
                VStack(alignment: .leading, spacing: 10) {
                    if showOptionalPrefix {
                        StatefulChildView(label: "Prefix")
                    }
                    StatefulChildView(label: "Main")
                    StatefulChildView(label: "Identified")
                        .id(activeIdentity)
                    GeometryReader { proxy in
                        Text("Geo:\(Int(proxy.size.width))x\(Int(proxy.size.height))")
                            .frame(maxWidth: .infinity)
                    }
                    ViewThatFits {
                        Text("FitsFirst")
                        Text("FitsSecond")
                    }
                    ScrollViewReader { _ in
                        Menu("Actions") {
                            Button("Action 1") {}
                        }
                    }
                }
                .modifier(CardFrameModifier())
                .searchable(text: Binding(get: { searchQuery }, set: { searchQuery = $0 }), prompt: "Find books…")
                .refreshable {}
                .safeAreaInset(edge: .bottom) {
                    Text("BottomInsetBar")
                }
                .navigationTitle("ModernSwiftUI")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Badge("ToolbarBadge")
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { showCover }, set: { showCover = $0 }), title: "CoverTitle") {
                Text("CoverBody")
            }
            .environment(vm)
            .buildRenderTree()
        }

        let tree1 = KindleStateRegistry.shared.evaluateTree(makeTree)
        let text1 = collectAllText(in: tree1)
        XCTAssertTrue(text1.contains("Main=0,vm=99"))
        XCTAssertTrue(text1.contains("Identified=0,vm=99"))
        XCTAssertTrue(text1.contains("Geo:1860x2480"))
        XCTAssertTrue(text1.contains("FitsFirst"))
        XCTAssertTrue(text1.contains("BottomInsetBar"))
        XCTAssertTrue(text1.contains("ToolbarBadge"))

        // Toggling an earlier conditional view must NOT shift or corrupt Main's @State slot
        showOptionalPrefix = true
        activeIdentity = "second"
        showCover = true
        let tree2 = KindleStateRegistry.shared.evaluateTree(makeTree)
        let text2 = collectAllText(in: tree2)
        XCTAssertTrue(text2.contains("Prefix=0,vm=99"))
        XCTAssertTrue(text2.contains("Main=0,vm=99"))
        XCTAssertTrue(text2.contains("CoverBody"))
    }

    private struct SumPreferenceKey: PreferenceKey {
        static var defaultValue: Int { 0 }
        static func reduce(value: inout Int, nextValue: () -> Int) {
            value += nextValue()
        }
    }

    private struct SampleNoteModel: PersistentModel {
        let id: String
        var title: String
        var orderIndex: Int
    }

    private struct QueryReaderView: View {
        @Query(sort: \SampleNoteModel.orderIndex, order: .forward) private var notes: [SampleNoteModel]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes) { note in
                    Text("Note:\(note.title)")
                        .preference(key: SumPreferenceKey.self, value: note.orderIndex)
                }
                .onDelete { _ in }
                .onMove { _, _ in }
            }
        }
    }

    func testMarkdownTextPreferenceKeyDatePickerTimelineFlowLayoutGesturesAndQuery() {
        KindleStateRegistry.shared.resetAllState()
        let tempPath = "/tmp/kindleui_test_models_\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        let container = ModelContainer(storagePath: tempPath)
        container.mainContext.insert(SampleNoteModel(id: "n1", title: "FirstChapter", orderIndex: 10))
        container.mainContext.insert(SampleNoteModel(id: "n2", title: "SecondChapter", orderIndex: 25))

        var observedPrefSum: Int = 0
        var selectedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let combinedText = Text("Hello ").bold() + Text("**Kindle** *Reader* `v2`").underline()
        let node = combinedText.buildRenderTree()
        if case .text(let plain, _, _, let style) = node {
            XCTAssertEqual(plain, "Hello Kindle Reader v2")
            XCTAssertNotNil(style.pangoMarkup)
            XCTAssertTrue(style.pangoMarkup?.contains("<b>Kindle</b>") == true)
            XCTAssertTrue(style.pangoMarkup?.contains("<i>Reader</i>") == true)
            XCTAssertTrue(style.pangoMarkup?.contains("<tt>v2</tt>") == true)
        } else {
            XCTFail("Expected .text RenderNode")
        }

        let makeTree: () -> RenderNode = {
            VStack(alignment: .leading, spacing: 12) {
                EditButton()
                Text(0.75, format: .percent)
                Text(42.5, format: .currency(code: "USD"))
                DatePicker("Reminder", selection: Binding(get: { selectedDate }, set: { selectedDate = $0 }))
                TimelineView(.periodic(by: 60.0)) { context in
                    Text(context.date, style: .date)
                }
                FlowLayout(spacing: 12, lineSpacing: 12, maxRowWidth: 400) {
                    Badge("ChipOne")
                    Badge("ChipTwo")
                    Badge("ChipThree")
                }
                QueryReaderView()
                    .swipeActions {
                        Button("Archive") {}
                    }
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { _ in }
                            .onEnded { _ in }
                    )
            }
            .onPreferenceChange(SumPreferenceKey.self) { total in
                observedPrefSum = total
            }
            .modelContainer(container)
            .buildRenderTree()
        }

        let tree = KindleStateRegistry.shared.evaluateTree(makeTree)
        let text = collectAllText(in: tree)
        XCTAssertEqual(observedPrefSum, 35)
        XCTAssertTrue(text.contains("75%"))
        XCTAssertTrue(text.contains("$42.50"))
        XCTAssertTrue(text.contains("Note:FirstChapter"))
        XCTAssertTrue(text.contains("Note:SecondChapter"))
        XCTAssertTrue(text.contains("ChipOne"))
    }

    func testUnevenRoundedRectangleAndEllipseShapes() {
        let unevenNode = UnevenRoundedRectangle(
            topLeadingRadius: 36,
            bottomLeadingRadius: 8,
            bottomTrailingRadius: 42,
            topTrailingRadius: 12
        )
        .fill(.gray4Bit(4))
        .stroke(.black, lineWidth: 3)
        .buildRenderTree()

        if case .vstack(_, _, _, let style) = unevenNode {
            XCTAssertEqual(style.unevenCorners?.topLeading, 36)
            XCTAssertEqual(style.unevenCorners?.bottomLeading, 8)
            XCTAssertEqual(style.unevenCorners?.bottomTrailing, 42)
            XCTAssertEqual(style.unevenCorners?.topTrailing, 12)
            XCTAssertEqual(style.borderWidth, 3)
            XCTAssertFalse(style.isEllipse)
        } else {
            XCTFail("Expected vstack node for UnevenRoundedRectangle")
        }

        let ellipseNode = Ellipse()
            .fill(.gray4Bit(10))
            .stroke(.black, lineWidth: 2)
            .buildRenderTree()

        if case .vstack(_, _, _, let style) = ellipseNode {
            XCTAssertTrue(style.isEllipse)
            XCTAssertEqual(style.borderWidth, 2)
        } else {
            XCTFail("Expected vstack node for Ellipse")
        }

        let styledTextNode = Text("Asymmetric")
            .padding(10)
            .background(
                .gray4Bit(13),
                in: .rect(topLeadingRadius: 28, bottomLeadingRadius: 4, bottomTrailingRadius: 28, topTrailingRadius: 4)
            )
            .buildRenderTree()

        if case .text(_, _, _, let style) = styledTextNode {
            XCTAssertEqual(style.unevenCorners?.topLeading, 28)
            XCTAssertEqual(style.unevenCorners?.bottomLeading, 4)
            XCTAssertEqual(style.unevenCorners?.bottomTrailing, 28)
            XCTAssertEqual(style.unevenCorners?.topTrailing, 4)
        } else {
            XCTFail("Expected text node with unevenCorners")
        }
    }

    func testKindlePreviewRegistryAndSimulatedScreenSize() {
        XCTAssertEqual(KindleDevice.shared.screenWidth, 1236)
        XCTAssertEqual(KindleDevice.shared.screenHeight, 1648)

        KindlePreview("Unit Test Card") {
            KindleCard("Preview Title") {
                Text("Preview Body")
            }
        }
        XCTAssertTrue(KindlePreviewRegistry.shared.registeredItems.contains { $0.id == "unit-test-card" })
    }
}
