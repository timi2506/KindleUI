import Foundation
import KindleUI

// MARK: - Tab 5: Reading Analytics & Charts

extension KindleShowcaseRootView {
    internal func activeChartView() -> some View {
        if chartSeriesMode == 0 {
            return AnyView(
                Chart(height: 230) {
                    BarMark(x: .value("Day", "Mon"), y: .value("Pages", 42), shade: .shade4)
                    BarMark(x: .value("Day", "Tue"), y: .value("Pages", 68), shade: .shade3)
                    BarMark(x: .value("Day", "Wed"), y: .value("Pages", 54), shade: .shade5)
                    BarMark(x: .value("Day", "Thu"), y: .value("Pages", 91), shade: .shade2)
                    BarMark(x: .value("Day", "Fri"), y: .value("Pages", 76), shade: .shade4)
                    BarMark(x: .value("Day", "Sat"), y: .value("Pages", 112), shade: .shade1)
                    BarMark(x: .value("Day", "Sun"), y: .value("Pages", 88), shade: .shade3)
                    RuleMark(y: .value("Goal", 70), label: "Daily Target")
                }
            )
        } else if chartSeriesMode == 1 {
            return AnyView(
                Chart(height: 230) {
                    LineMark(x: .value("Hour", "08:00"), y: .value("Min", 18))
                    LineMark(x: .value("Hour", "11:00"), y: .value("Min", 34))
                    LineMark(x: .value("Hour", "14:00"), y: .value("Min", 29))
                    LineMark(x: .value("Hour", "17:00"), y: .value("Min", 52))
                    LineMark(x: .value("Hour", "20:00"), y: .value("Min", 84))
                    LineMark(x: .value("Hour", "22:00"), y: .value("Min", 64))
                    RuleMark(y: .value("Target", 50), label: "Baseline")
                }
            )
        } else {
            return AnyView(
                Chart(height: 230) {
                    BarMark(x: .value("Genre", "Philosophy"), y: .value("Hours", 19), shade: .shade2)
                    BarMark(x: .value("Genre", "Sci-Fi"), y: .value("Hours", 24), shade: .shade4)
                    BarMark(x: .value("Genre", "Classics"), y: .value("Hours", 14), shade: .shade6)
                    BarMark(x: .value("Genre", "CS"), y: .value("Hours", 12), shade: .shade8)
                }
            )
        }
    }

    internal func chartsTab(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            // Section 1: Overview Metrics Row (Top-Level Cards, No Outer Box)
            VStack(alignment: .leading, spacing: 10) {
                Text("Overview")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)

                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        metricTile(title: "Reading Pace", value: "48 pg/h", detail: "+12% this week", theme: theme)
                        metricTile(title: "Active Streak", value: "19 Days", detail: "Personal best", theme: theme)
                        metricTile(title: "Weekly Total", value: "531 Pages", detail: "68.5 hours total", theme: theme)
                    }
                }
            }

            // Section 2: Reading Activity Chart
            Surface("Reading Activity") {
                HStack(alignment: .center, spacing: 10) {
                    Button("Weekly Pages") { chartSeriesMode = 0 }
                        .buttonStyle(chartSeriesMode == 0 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Button("Hourly Focus") { chartSeriesMode = 1 }
                        .buttonStyle(chartSeriesMode == 1 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Button("By Subject") { chartSeriesMode = 2 }
                        .buttonStyle(chartSeriesMode == 2 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Spacer()
                }

                activeChartView()
            }

            // Section 3: Subject Breakdown Table
            VStack(alignment: .leading, spacing: 10) {
                Text("Subject Breakdown")
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(theme.foreground)

                Table(sampleGenreStats) {
                    TableColumn("Subject") { (item: GenreStat) in Text(item.subject).font(.headline) }
                    TableColumn("Collection") { (item: GenreStat) in Text(item.volumes) }
                    TableColumn("Time Read") { (item: GenreStat) in Text(item.hoursRead).font(.caption.monospacedDigit()) }
                    TableColumn("Completed") { (item: GenreStat) in Text(item.completion).font(.caption.monospacedDigit()) }
                }
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    internal func metricTile(title: String, value: String, detail: String, theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.mutedForeground)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(theme.foreground)
            Text(detail)
                .font(.caption)
                .foregroundColor(theme.mutedForeground)
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .background(theme.cardBackground, in: .rect(cornerRadius: 16))
        .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)
    }
}
