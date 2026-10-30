import Foundation
import KindleUI

// MARK: - Tab 6: Settings & SplitView

extension KindleShowcaseRootView {
    internal func settingsTab(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section 1: Preferences SplitView (Directly on Page, No Outer Box)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Preferences")
                        .font(.system(size: 19, weight: .bold, design: .serif))
                        .foregroundColor(theme.foreground)

                    Spacer()

                    Button(showStorageInspector ? "Hide Inspector" : "Inspector") {
                        showStorageInspector.toggle()
                    }
                    .buttonStyle(showStorageInspector ? .borderedProminent : .bordered)
                    .controlSize(.small)

                    Button("Reset Defaults") {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                NavigationSplitView(columnVisibility: $splitVisibility, sidebarWidth: 260) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(SettingsSection.allCases, id: \.self) { section in
                            Button(section.rawValue) {
                                selectedSettingsSection = section
                            }
                            .buttonStyle(selectedSettingsSection == section ? .borderedProminent : .card)
                            .expand(false, fill: true)
                        }
                    }
                } detail: {
                    settingsDetailPane(for: selectedSettingsSection, theme: theme)
                }
            }

            // Section 2: System Information
            Surface("System Summary") {
                LabeledContent("Application ID", value: KindleShowcaseApp.applicationID)
                LabeledContent("Display Resolution", value: "\(KindleDevice.shared.screenWidth) × \(KindleDevice.shared.screenHeight) px")
                LabeledContent("Color Scheme", value: useDarkTheme ? "Dark E-Ink" : "Light E-Ink")
                LabeledContent("Refresh Policy", value: refreshMode.rawValue)
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    internal func settingsDetailPane(for section: SettingsSection, theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(section.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Spacer()
                Button("Hide Sidebar") {
                    splitVisibility = .detailOnly
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Divider()

            switch section {
            case .display:
                Toggle("High-Contrast Page Turns", isOn: $boldTypography)
                    .toggleStyle(.switch)

                Picker("Waveform Policy", selection: $refreshMode)
                    .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Button("Flash Full Refresh") {
                        KindleDevice.shared.refreshScreen(full: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Display Sheet") {
                        showDisplaySheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reader View") {
                        showReaderCover = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            case .reading:
                Toggle("Bold Typography", isOn: $boldTypography)
                    .toggleStyle(.checkbox)

                Picker("Refresh Mode", selection: $refreshMode)
                    .pickerStyle(.segmented)

                Button("Open Reader View") {
                    showReaderCover = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            case .storage:
                LabeledContent("Launch Count", value: "\(launchCount)")
                LabeledContent("Data Directory", value: KindleStateRegistry.shared.appDataDirectory)

                HStack(spacing: 12) {
                    Button("Increment (+1)") {
                        launchCount += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Inspect Storage") {
                        showStorageInspector = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            case .device:
                LabeledContent("Viewport", value: "\(KindleDevice.shared.screenWidth) × \(KindleDevice.shared.screenHeight)")
                LabeledContent("Hardware Bridge", value: KindleDevice.shared.isHardwareAvailable ? "Connected" : "Preview")
                Gauge("Battery (\(Int(batteryLevel * 100))%)", value: batteryLevel, in: 0...1)
            }
        }
    }

    internal func storageInspectorDrawer(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved Preferences")
                .font(.headline)

            LabeledContent("Dark Mode", value: useDarkTheme ? "On" : "Off")
            LabeledContent("Refresh Mode", value: refreshMode.rawValue)
            LabeledContent("Frontlight", value: "\(Int(frontlightLevel))%")
            LabeledContent("Warmth", value: "\(warmthStep) / 10")
            LabeledContent("Launches", value: "\(launchCount)")

            Divider()

            Button("Reset Defaults") {
                resetAllState()
                showStorageInspector = false
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
