import Foundation
import KindleUI

@main
struct KindleNotesApp: App {
    var body: some Scene {
        WindowGroup(
            id: "org.kindlemodding.kindlenotes",
            layer: .application,
            role: .application,
            chrome: .topBar,
            orientations: .portrait,
            width: 600,
            height: 800
        ) {
            KindleNotesHomeView()
        }
    }
}

struct KindleNotesHomeView: View {
    @State private var notes: [String] = [
        "1. Read chapter 4 of Dune on Paperwhite",
        "2. Test AwesomeWM window title flags (L:A_N:application_PC:T)",
        "3. Package KUAL extension with kindle-swift"
    ]
    @State private var draftNote: String = ""
    @State private var frontlight: Double = Double(KindleDevice.shared.frontlightIntensity)
    @State private var preventSleep: Bool = KindleDevice.shared.preventScreenSaver
    @State private var readingGoalPages: Int = 25

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("KindleNotes")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Text("SwiftUI for E-Ink")
                    .font(.caption)
            }

            Divider()

            KindleCard("Add Reading Note") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Type a new note...", text: $draftNote)
                    HStack(spacing: 8) {
                        Button("+ Add Note") {
                            let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                notes.append("\(notes.count + 1). \(trimmed)")
                                draftNote = ""
                            } else {
                                notes.append("\(notes.count + 1). Quick bookmark #\(notes.count + 1)")
                            }
                        }
                        Button("Clear Last") {
                            if !notes.isEmpty {
                                notes.removeLast()
                            }
                        }
                    }
                }
            }

            KindleCard("Saved Notes (\(notes.count))") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(notes) { item in
                        Text(item)
                            .font(.bookerly(size: 12))
                    }
                }
            }

            KindleCard("Reading Progress & Hardware") {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(
                        value: Double(min(readingGoalPages, 50)),
                        total: 50.0,
                        label: "Daily Goal: \(readingGoalPages) / 50 pages"
                    )

                    HStack(spacing: 8) {
                        Button("+5 Pages") {
                            readingGoalPages = min(50, readingGoalPages + 5)
                        }
                        Button("-5 Pages") {
                            readingGoalPages = max(0, readingGoalPages - 5)
                        }
                    }

                    Divider()

                    Toggle("Prevent Kindle Sleep (LIPC powerd)", isOn: Binding(
                        get: { preventSleep },
                        set: { newValue in
                            preventSleep = newValue
                            KindleDevice.shared.preventScreenSaver = newValue
                        }
                    ))

                    Text("Frontlight Brightness: \(Int(frontlight)) / 24")
                        .font(.caption)

                    Slider(
                        value: Binding(
                            get: { frontlight },
                            set: { newVal in
                                frontlight = newVal
                                KindleDevice.shared.frontlightIntensity = Int(newVal)
                            }
                        ),
                        in: 0...24,
                        step: 1
                    )
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.paperWhite)
        .foregroundColor(.black)
    }
}
