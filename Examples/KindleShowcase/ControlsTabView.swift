import Foundation
import KindleUI

// MARK: - Tab 1: Controls, Inputs & Modals

extension KindleShowcaseRootView {
    internal func controlsTab(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section 1: Buttons & Overlays
            Surface("Buttons & Overlays") {
                HStack(alignment: .center, spacing: 12) {
                    Button("Primary") {
                        statusBanner = "Primary"
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Secondary") {
                        statusBanner = "Secondary"
                    }
                    .buttonStyle(.bordered)

                    Button("Capsule") {
                        statusBanner = "Capsule"
                    }
                    .buttonStyle(.capsule)

                    Menu("Actions", icon: .sliders) {
                        Button("Full E-Ink Refresh") {
                            KindleDevice.shared.refreshScreen(full: true)
                        }
                        Button("Open Reader Cover") {
                            showReaderCover = true
                        }
                        Button("Open Storage Inspector") {
                            showStorageInspector = true
                        }
                    }

                    Spacer()

                    Button("Sheet") { showDisplaySheet = true }
                        .buttonStyle(.bordered)

                    Button("Popover") { showQuickPopover.toggle() }
                        .buttonStyle(showQuickPopover ? .borderedProminent : .bordered)
                        .popover(isPresented: $showQuickPopover, attachmentAnchor: .bounds, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Quick Actions")
                                    .font(.headline)
                                Text("Contextual overlay anchored directly below this button.")
                                    .font(.caption)
                                    .foregroundColor(theme.mutedForeground)
                                HStack(spacing: 10) {
                                    Button("Flash Screen") {
                                        KindleDevice.shared.refreshScreen(full: true)
                                        showQuickPopover = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Dismiss") {
                                        showQuickPopover = false
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                    Button("Dialog") { showExportDialog = true }
                        .buttonStyle(.bordered)

                    Button("Alert") { showResetAlert = true }
                        .buttonStyle(.bordered)
                }
            }

            // Section 2: Toggles & Adjustments
            Surface("Toggles & Adjustments") {
                Toggle("Airplane Mode", isOn: $airplaneMode)
                    .toggleStyle(.switch)

                Toggle("Whispersync Annotations", isOn: $syncAnnotations)
                    .toggleStyle(.checkbox)

                Divider()

                HStack {
                    Text("Frontlight")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(frontlightLevel))%")
                        .font(.headline.monospacedDigit())
                }
                Slider(value: $frontlightLevel, in: 0...100, step: 5)

                Stepper("Warmth Level: \(warmthStep) / 10", value: $warmthStep, in: 0...10, step: 1)
            }

            // Section 3: Inputs & Progress
            Surface("Inputs & Progress") {
                LabeledContent("Reader Name") {
                    TextField("Enter reader name…", text: $readerName)
                        .submitLabel(.done)
                }

                LabeledContent("Passphrase") {
                    SecureField("Enter passphrase…", text: $wifiPassphrase)
                }

                Picker("Refresh Mode", selection: $refreshMode)
                    .pickerStyle(.segmented)

                Gauge("Battery (\(Int(batteryLevel * 100))%)", value: batteryLevel, in: 0...1)
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    // MARK: - Modal Sheet & FullScreenCover Views

    internal func displaySheetContent(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Frontlight")
                    .font(.headline)
                Spacer()
                Text("\(Int(frontlightLevel))%")
                    .font(.headline.monospacedDigit())
            }
            Slider(value: $frontlightLevel, in: 0...100, step: 5)

            Stepper("Warmth Level: \(warmthStep)", value: $warmthStep, in: 0...10)

            Toggle("Dark Mode", isOn: $useDarkTheme)
                .toggleStyle(.switch)

            HStack(spacing: 12) {
                Button("Refresh Screen") {
                    KindleDevice.shared.refreshScreen(full: true)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") {
                    showDisplaySheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    internal func distractionFreeReaderCover(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 16) {
                Text("Meditations — Book IV")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                Spacer()
                Button("Close ✕") {
                    showReaderCover = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                Text("“Men seek retreats for themselves, houses in the country, sea-shores, and mountains; and thou too art wont to desire such things very much. But this is altogether a mark of the most common sort of men, for it is in thy power whenever thou shalt choose to retire into thyself.”")
                    .font(.system(size: 24, weight: .regular, design: .serif))

                Text("“For nowhere either with more quiet or more freedom from trouble does a man retire than into his own soul, particularly when he has within him such thoughts that by looking into them he is immediately in perfect tranquility.”")
                    .font(.system(size: 24, weight: .regular, design: .serif))
            }
            .padding(28)
            .background(theme.cardBackground, in: .rect(cornerRadius: 18))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 18), lineWidth: 1)

            Spacer()

            HStack {
                Text("Marcus Aurelius  •  Page 74 of 254")
                    .font(.caption)
                    .foregroundColor(theme.mutedForeground)
                Spacer()
                Button("Bookmark") {
                    showReaderCover = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(36)
        .background(theme.background)
    }
}
