import Foundation

// MARK: - 7. Declarative Swift Charts (Chart, BarMark, LineMark, PointMark, RuleMark, SectorMark)

/// A labeled data value plotted on a `Chart` axis.
public struct PlottableValue: Equatable, Sendable {
    public let label: String
    public let stringValue: String
    public let numericValue: Double

    public static func value(_ label: String, _ category: String) -> PlottableValue {
        PlottableValue(label: label, stringValue: category, numericValue: Double(category) ?? 0.0)
    }

    public static func value(_ label: String, _ number: Double) -> PlottableValue {
        PlottableValue(label: label, stringValue: String(format: "%.0f", number), numericValue: number)
    }

    public static func value(_ label: String, _ number: Int) -> PlottableValue {
        PlottableValue(label: label, stringValue: "\(number)", numericValue: Double(number))
    }
}

/// Protocol representing a visual mark inside a declarative `Chart`.
public protocol ChartContent: Sendable {
    var _marks: [ChartMarkItem] { get }
}

public struct ChartMarkItem: Sendable {
    public enum Kind: Sendable {
        case bar
        case line
        case point
        case area
        case rule
        case sector
    }

    public let kind: Kind
    public let x: PlottableValue
    public let y: PlottableValue
    public let shade: EInkColor
}

/// A bar mark representing data with rectangular bars in a `Chart`.
public struct BarMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(x: PlottableValue, y: PlottableValue, shade: EInkColor = .black) {
        self._marks = [ChartMarkItem(kind: .bar, x: x, y: y, shade: shade)]
    }
}

/// A line mark connecting data points in a `Chart`.
public struct LineMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(x: PlottableValue, y: PlottableValue, shade: EInkColor = .black) {
        self._marks = [ChartMarkItem(kind: .line, x: x, y: y, shade: shade)]
    }
}

/// A point mark plotting individual data points in a `Chart`.
public struct PointMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(x: PlottableValue, y: PlottableValue, shade: EInkColor = .black) {
        self._marks = [ChartMarkItem(kind: .point, x: x, y: y, shade: shade)]
    }
}

/// An area mark shading the region beneath a line in a `Chart`.
public struct AreaMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(x: PlottableValue, y: PlottableValue, shade: EInkColor = .lightGray) {
        self._marks = [ChartMarkItem(kind: .area, x: x, y: y, shade: shade)]
    }
}

/// A horizontal threshold or reference rule across a `Chart`.
public struct RuleMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(y: PlottableValue, label: String = "Target", shade: EInkColor = .darkGray) {
        self._marks = [
            ChartMarkItem(
                kind: .rule,
                x: .value("Rule", label),
                y: y,
                shade: shade
            )
        ]
    }
}

/// A proportional sector mark in a `Chart`.
public struct SectorMark: ChartContent {
    public let _marks: [ChartMarkItem]

    public init(angle: PlottableValue, label: String, shade: EInkColor = .black) {
        self._marks = [
            ChartMarkItem(
                kind: .sector,
                x: .value("Segment", label),
                y: angle,
                shade: shade
            )
        ]
    }
}

@resultBuilder
public struct ChartContentBuilder {
    public static func buildBlock(_ components: [ChartMarkItem]...) -> [ChartMarkItem] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ mark: some ChartContent) -> [ChartMarkItem] {
        mark._marks
    }

    public static func buildExpression(_ marks: [ChartMarkItem]) -> [ChartMarkItem] {
        marks
    }

    public static func buildArray(_ components: [[ChartMarkItem]]) -> [ChartMarkItem] {
        components.flatMap { $0 }
    }
}

/// A Swift Charts-compatible declarative chart view rendered with crisp E-Ink vector graphics and axis labels.
public struct Chart: View, _PrimitiveView {
    public typealias Body = Never
    public let marks: [ChartMarkItem]
    public let height: Int

    public init(height: Int = 220, @ChartContentBuilder content: () -> [ChartMarkItem]) {
        self.marks = content()
        self.height = height
    }

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        height: Int = 220,
        @ChartContentBuilder content: (Data.Element) -> [ChartMarkItem]
    ) {
        self.marks = data.flatMap { content($0) }
        self.height = height
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let buf = KindleCanvasBuffer(width: 640, height: height, fill: theme.cardBackground.grayLevel)
        let capturedMarks = marks
        let dataMarks = capturedMarks.filter { $0.kind != .rule }
        let ruleMarks = capturedMarks.filter { $0.kind == .rule }
        let maxY = max(1.0, (capturedMarks.map { $0.y.numericValue }.max() ?? 100.0) * 1.12)

        let canvasView = KindleCanvas(
            buffer: buf,
            label: "Chart",
            onPrepare: { w, h in
                let bg = theme.cardBackground.grayLevel
                let fg = theme.foreground.grayLevel
                let subtle = theme.subtleBorder.grayLevel
                buf.resizeIfNeeded(width: w, height: h, defaultFill: bg)
                buf.clear(fill: bg)

                let padL = 24
                let padR = 24
                let padT = 18
                let padB = 22
                let plotW = max(20, w - padL - padR)
                let plotH = max(20, h - padT - padB)

                // Horizontal grid lines (25%, 50%, 75%, 100%)
                for g in 0...4 {
                    let gy = padT + (plotH * g) / 4
                    buf.drawLine(fromX: padL, fromY: gy, toX: padL + plotW, toY: gy, radius: 1, gray: g == 4 ? fg : subtle)
                }

                // Rule marks (dashed horizontal target line)
                for rule in ruleMarks {
                    let frac = min(1.0, max(0.0, rule.y.numericValue / maxY))
                    let ry = padT + plotH - Int((frac * Double(plotH)).rounded())
                    var x = padL
                    while x < padL + plotW {
                        let xEnd = min(padL + plotW, x + 14)
                        buf.drawLine(fromX: x, fromY: ry, toX: xEnd, toY: ry, radius: 2, gray: fg)
                        x += 24
                    }
                }

                let bars = dataMarks.filter { $0.kind == .bar || $0.kind == .sector }
                if !bars.isEmpty {
                    let slotW = max(8, plotW / max(1, bars.count))
                    let barW = max(6, Int(Double(slotW) * 0.56))
                    for (idx, bar) in bars.enumerated() {
                        let frac = min(1.0, max(0.0, bar.y.numericValue / maxY))
                        let bh = max(4, Int((frac * Double(plotH)).rounded()))
                        let cx = padL + idx * slotW + slotW / 2
                        let x0 = cx - barW / 2
                        let x1 = cx + barW / 2
                        let y1 = padT + plotH
                        let y0 = y1 - bh
                        buf.drawRect(fromX: x0, fromY: y0, toX: x1, toY: y1, radius: 2, gray: bar.shade.grayLevel, filled: true)
                        buf.drawRect(fromX: x0, fromY: y0, toX: x1, toY: y1, radius: 2, gray: fg, filled: false)
                    }
                }

                let lines = dataMarks.filter { $0.kind == .line || $0.kind == .point || $0.kind == .area }
                if !lines.isEmpty {
                    let count = lines.count
                    var pts: [(Int, Int)] = []
                    for (idx, item) in lines.enumerated() {
                        let x = count > 1
                            ? (padL + (idx * plotW) / (count - 1))
                            : (padL + plotW / 2)
                        let frac = min(1.0, max(0.0, item.y.numericValue / maxY))
                        let y = padT + plotH - Int((frac * Double(plotH)).rounded())
                        pts.append((x, y))
                    }
                    for i in 0..<(pts.count - 1) {
                        buf.drawLine(
                            fromX: pts[i].0,
                            fromY: pts[i].1,
                            toX: pts[i + 1].0,
                            toY: pts[i + 1].1,
                            radius: 3,
                            gray: fg
                        )
                    }
                    for pt in pts {
                        buf.drawCircle(centerX: pt.0, centerY: pt.1, circleRadius: 7, strokeRadius: 2, gray: fg, filled: true)
                    }
                }
            }
        )
        .frame(height: height)
        .border(theme.border, width: 2, cornerRadius: 12)

        // Category labels & values footer
        var uniqueCategories: [(String, String)] = []
        for m in dataMarks {
            if !uniqueCategories.contains(where: { $0.0 == m.x.stringValue }) {
                uniqueCategories.append((m.x.stringValue, m.y.stringValue))
            }
        }

        return VStack(alignment: .leading, spacing: 8) {
            canvasView

            if !uniqueCategories.isEmpty {
                HStack(alignment: .center, spacing: 4, homogeneous: true) {
                    ForEach(0..<uniqueCategories.count) { idx in
                        let pair = uniqueCategories[idx]
                        VStack(alignment: .center, spacing: 2) {
                            Text(pair.0)
                                .font(.caption)
                                .bold()
                                .multilineTextAlignment(.center)
                            Text(pair.1)
                                .font(.monospaced)
                                .multilineTextAlignment(.center)
                        }
                        .expand(true, fill: true)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .buildRenderTree()
    }
}
