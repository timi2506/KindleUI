import KindleUI

@main
struct HelloWorldApp: App {
    var body: some Scene {
        WindowGroup(
            id: "org.kindlemodding.helloworld",
            layer: .application,
            role: .application,
            chrome: .topAndSearch,
            orientations: .all,
            width: 600,
            height: 800
        ) {
            ShowcaseContentView()
        }
    }
}

/// Demonstrates a reusable child component bound via `@Binding<Int>`.
struct CounterBindingRow: View {
    @Binding var count: Int

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Bound Counter: \(count)")
                .font(.headline)
            Spacer(minLength: 8)
            Button("+1") {
                count += 1
            }
            Button("-1") {
                count = max(0, count - 1)
            }
            Button(action: { count = 0 }) {
                Text("Reset (Custom Label)")
                    .font(.caption)
                    .bold()
            }
        }
    }
}

struct ShowcaseContentView: View {
    // 1. Reactive @State properties
    @State private var counter: Int = 3
    @State private var frontlight: Double = Double(KindleDevice.shared.frontlightIntensity)
    @State private var preventSleep: Bool = KindleDevice.shared.preventScreenSaver
    @State private var showAdvancedDetails: Bool = true
    @State private var noteInput: String = "Hello, Kindle World!"
    @State private var selectedWindowPreset: Int = 0
    @State private var items: [String] = [
        "1. Declarative @ViewBuilder DSL",
        "2. 16-Shade E-Ink Palette & Bookerly Fonts",
        "3. AwesomeWM Window Title Generator",
        "4. LIPC Hardware Bridge (Frontlight & Battery)"
    ]

    private var activeWindowConfig: KindleWindowConfig {
        switch selectedWindowPreset {
        case 1:
            return .fullScreenApp(id: "org.kindlemodding.helloworld", orientations: .portrait)
        case 2:
            return .dialog(
                id: "org.kindlemodding.helloworld-dialog",
                dismissible: true,
                cornerRadius: 12,
                requiresKeyboard: true,
                width: 480,
                height: 360
            )
        default:
            return KindleWindowConfig(
                applicationID: "org.kindlemodding.helloworld",
                layer: .application,
                role: .application,
                persistentChrome: .topAndSearch,
                orientations: .all,
                hideMode: .visible,
                roundedCorners: .custom(topLeft: true, topRight: true, bottomLeft: false, bottomRight: false),
                modality: .none,
                requireKeyboard: nil,
                width: 600,
                height: 800
            )
        }
    }

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // Header Section (Typography + ZStack + Alignment)
                ZStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("Hello, World! — KindleUI Full Showcase")
                            .font(.largeTitle)
                            .bold()
                            .multilineTextAlignment(.center)

                        Text("Every view, control, modifier, font, E-Ink shade, AwesomeWM rule & LIPC bridge")
                            .font(.subheadline)
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.darkGray)
                    }
                    .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .background(.lightGray)
                    .border(.black, width: 2)
                }

                Divider()

                // 2. AwesomeWM Window Configuration Showcase
                KindleCard("1. AwesomeWM Window Manager Engine") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Title: \(activeWindowConfig.awesomeWindowTitle)")
                            .font(.monospaced)
                            .lineWrap(true)

                        HStack(spacing: 8) {
                            Button("App (Top+Search)") {
                                selectedWindowPreset = 0
                            }
                            Button("Full-Screen App") {
                                selectedWindowPreset = 1
                            }
                            Button("Modal RKB Dialog") {
                                selectedWindowPreset = 2
                            }
                        }
                    }
                }

                // 3. Reactive @State, @Binding, Buttons & Conditional @ViewBuilder
                KindleCard("2. Reactive @State, @Binding & Controls") {
                    VStack(alignment: .leading, spacing: 8) {
                        CounterBindingRow(count: $counter)

                        Divider()

                        Toggle("Show Advanced Typography & Palette Details", isOn: $showAdvancedDetails)

                        if showAdvancedDetails {
                            Text("Conditional branch: True (rendered via ViewBuilder.buildEither)")
                                .font(.caption)
                                .foregroundColor(.charcoal)
                        } else {
                            Text("Conditional branch: False (compact mode active)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        HStack(spacing: 8) {
                            TextField("Enter a note...", text: $noteInput)
                                .expand(true)
                            Button("Add to List") {
                                if !noteInput.isEmpty {
                                    items.append("\(items.count + 1). \(noteInput)")
                                }
                            }
                        }
                        Text("Live TextField Value: \"\(noteInput)\"")
                            .font(.caption)
                    }
                }

                // 4. Kindle Hardware LIPC Bridge (Frontlight, Battery, Screensaver)
                KindleCard("3. Kindle LIPC Hardware Bridge (com.lab126.powerd)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Prevent Screensaver Sleep (preventScreenSaver)", isOn: $preventSleep)

                        Text("Frontlight Intensity (flIntensity): \(Int(frontlight)) / 24")
                            .font(.headline)

                        Slider(value: $frontlight, in: 0...24, step: 1)

                        HStack(spacing: 12) {
                            Button("Dim (0)") {
                                frontlight = 0
                                KindleDevice.shared.frontlightIntensity = 0
                            }
                            Button("Medium (12)") {
                                frontlight = 12
                                KindleDevice.shared.frontlightIntensity = 12
                            }
                            Button("Max (24)") {
                                frontlight = 24
                                KindleDevice.shared.frontlightIntensity = 24
                            }
                        }

                        ProgressView(
                            value: Double(KindleDevice.shared.batteryLevel),
                            total: 100.0,
                            label: "Kindle Battery Level: \(KindleDevice.shared.batteryLevel)%"
                        )
                    }
                }

                // 5. Typography & 16-Shade E-Ink Grayscale Palette
                if showAdvancedDetails {
                    KindleCard("4. Kindle Pango Typography & 16-Shade E-Ink Palette") {
                        VStack(alignment: .leading, spacing: 6) {
                            Group {
                                Text("• .title — Serif Bold 18pt").font(.title)
                                Text("• .headline — Sans Bold 14pt").font(.headline)
                                Text("• .bookerly(size: 14, italic: true) — Native Kindle Bookerly")
                                    .font(.bookerly(size: 14, bold: false, italic: true))
                                Text("• .body — Serif Regular 12pt").font(.body)
                                Text("• .caption — Sans Regular 10pt").font(.caption)
                                Text("• .monospaced — Monospace 11pt").font(.monospaced)
                                Text("• .custom(\"Futura\", size: 13, bold: true)")
                                    .font(.custom("Futura", size: 13, bold: true))
                            }

                            Divider()

                            Text("16-Level E-Ink Grayscale Swatches (0 = Black Ink .. 15 = Paper White):")
                                .font(.caption)
                                .bold()

                            HStack(spacing: 4) {
                                ForEach([0, 3, 6, 9, 12, 15]) { shade in
                                    Text("S\(shade)")
                                        .font(.caption)
                                        .padding(6)
                                        .foregroundColor(shade < 8 ? .paperWhite : .black)
                                        .background(.eInkShade(shade))
                                        .border(.black, width: 1)
                                }
                            }
                        }
                    }
                }

                // 6. List, ForEach, Vertical Divider, Frame, Image & EmptyView
                KindleCard("5. List, ForEach, Image & Layout Modifiers") {
                    VStack(alignment: .leading, spacing: 8) {
                        List {
                            ForEach(items) { item in
                                HStack(spacing: 8) {
                                    Text(item)
                                        .font(.body)
                                    Spacer()
                                    Divider(vertical: true)
                                    Text("OK")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                        }
                        .frame(height: 140)

                        HStack(spacing: 10) {
                            Image("/mnt/us/extensions/HelloWorld/icon.png", altText: "Kindle App Icon")
                                .frame(width: 180, height: 36, alignment: .center)
                            EmptyView()
                            AnyView(
                                Text("Wrapped in AnyView")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .background(.silver)
                                    .border(.charcoal, width: 1)
                            )
                        }
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(16)
        }
        .kindleWindow(activeWindowConfig)
        .onAppear {
            KindleDevice.shared.preventScreenSaver = preventSleep
        }
    }
}