import Foundation

// MARK: - DatePicker (Interactive E-Ink Calendar & Time Picker)

/// Options that determine the components shown in a `DatePicker`.
public struct DatePickerComponents: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let date          = DatePickerComponents(rawValue: 1 << 0)
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 1)
}

/// A high-contrast E-Ink control for selecting an absolute date and/or time.
public struct DatePicker: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let selection: Binding<Date>
    public let displayedComponents: DatePickerComponents
    private let expandedBox: StateBox<Bool>

    public init(
        _ title: String = "",
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column
    ) {
        self.title = title
        self.selection = selection
        self.displayedComponents = displayedComponents
        self.expandedBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "datepicker:\(fileID):\(line):\(column)",
            initialValue: { false }
        )
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let currentDate = selection.wrappedValue
        let binding = selection
        let box = expandedBox
        let isExpanded = box.value
        let cal = Calendar(identifier: .gregorian)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if displayedComponents.contains(.date) && displayedComponents.contains(.hourAndMinute) {
            formatter.dateFormat = "MMM d, yyyy · HH:mm"
        } else if displayedComponents.contains(.date) {
            formatter.dateFormat = "MMM d, yyyy"
        } else {
            formatter.dateFormat = "HH:mm"
        }
        let summaryText = formatter.string(from: currentDate)

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMMM yyyy"
        let monthTitle = monthFormatter.string(from: currentDate)

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: currentDate)
        let currentDay = comps.day ?? 1
        let currentHour = comps.hour ?? 0
        let currentMinute = comps.minute ?? 0

        let daysInMonth: Int = {
            if let range = cal.range(of: .day, in: .month, for: currentDate) {
                return range.count
            }
            return 30
        }()

        let adjustComponent: (Calendar.Component, Int) -> Void = { comp, delta in
            if let updated = cal.date(byAdding: comp, value: delta, to: binding.wrappedValue) {
                binding.wrappedValue = updated
            }
        }

        let selectDay: (Int) -> Void = { targetDay in
            var c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: binding.wrappedValue)
            c.day = targetDay
            if let updated = cal.date(from: c) {
                binding.wrappedValue = updated
            }
        }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                if !title.isEmpty {
                    Text(title)
                        .font(.body)
                        .foregroundColor(theme.foreground)
                    Spacer()
                }
                Button(action: {
                    box.value.toggle()
                }) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(summaryText)
                            .font(.monospaced)
                        Icon(isExpanded ? .chevronUp : .chevronDown, size: 32)
                    }
                }
                .buttonStyle(isExpanded ? .borderedProminent : .bordered)
                .controlSize(.small)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    if displayedComponents.contains(.date) {
                        HStack(alignment: .center, spacing: 12) {
                            Button("← Month") {
                                adjustComponent(.month, -1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Spacer()

                            Text(monthTitle)
                                .font(.headline)

                            Spacer()

                            Button("Month →") {
                                adjustComponent(.month, 1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible, spacing: 8), count: 7),
                            spacing: 8
                        ) {
                            ForEach(1...daysInMonth, id: \.self) { day in
                                Button("\(day)") {
                                    selectDay(day)
                                }
                                .buttonStyle(day == currentDay ? .borderedProminent : .bordered)
                                .controlSize(.mini)
                            }
                        }
                    }

                    if displayedComponents.contains(.hourAndMinute) {
                        if displayedComponents.contains(.date) {
                            Divider(thickness: 1, color: theme.subtleBorder)
                        }
                        HStack(alignment: .center, spacing: 12) {
                            Text(String(format: "Time  %02d:%02d", currentHour, currentMinute))
                                .font(.monospaced)
                            Spacer()
                            Button("-1h") { adjustComponent(.hour, -1) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("+1h") { adjustComponent(.hour, 1) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("-5m") { adjustComponent(.minute, -5) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("+5m") { adjustComponent(.minute, 5) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("Now") { binding.wrappedValue = Date() }
                                .buttonStyle(.capsule)
                                .controlSize(.mini)
                        }
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                .background(theme.panelBackground, cornerRadius: 16)
                .border(theme.subtleBorder, width: 1, cornerRadius: 16)
            }
        }
        .buildRenderTree()
    }
}



// MARK: - 8. MultiDatePicker & Graphical Month Calendar Grid

/// A control for picking multiple dates from an interactive 7-column calendar month grid.
public struct MultiDatePicker: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let selection: Binding<Set<Int>>
    public let monthTitle: String
    public let daysInMonth: Int
    public let firstWeekdayOffset: Int

    public init(
        _ title: String,
        selection: Binding<Set<Int>>,
        monthTitle: String = "October 2026",
        daysInMonth: Int = 31,
        firstWeekdayOffset: Int = 4
    ) {
        self.title = title
        self.selection = selection
        self.monthTitle = monthTitle
        self.daysInMonth = max(28, min(31, daysInMonth))
        self.firstWeekdayOffset = max(0, min(6, firstWeekdayOffset))
    }

    public func _makeNode() -> RenderNode {
        let weekdays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let cols = Array(repeating: GridItem(.flexible()), count: 7)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Icon(.calendar, size: 36)
                Text("\(title) · \(monthTitle)")
                    .font(.headline)
                Spacer()
                Badge("\(selection.wrappedValue.count) selected", prominent: !selection.wrappedValue.isEmpty)
            }

            HStack(alignment: .center, spacing: 6, homogeneous: true) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .bold()
                        .multilineTextAlignment(.center)
                }
            }

            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(1...daysInMonth, id: \.self) { dayNum in
                    let isPicked = selection.wrappedValue.contains(dayNum)
                    Button("\(dayNum)") {
                        var set = selection.wrappedValue
                        if set.contains(dayNum) {
                            set.remove(dayNum)
                        } else {
                            set.insert(dayNum)
                        }
                        selection.wrappedValue = set
                    }
                    .buttonStyle(isPicked ? .borderedProminent : .bordered)
                    .controlSize(.mini)
                }
            }
        }
        .buildRenderTree()
    }
}
