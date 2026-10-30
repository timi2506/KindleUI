import Foundation

/// The characteristics of a stroke that traces a `Path`.
public struct StrokeStyle: Equatable, Sendable {
    public var lineWidth: Int
    public var dash: [Int]

    public init(lineWidth: Int = 3, dash: [Int] = []) {
        self.lineWidth = max(1, lineWidth)
        self.dash = dash
    }
}

/// The outline of a 2D shape with lines, curves, rectangles, and ellipses.
public struct Path: View, _PrimitiveView, Sendable {
    public typealias Body = Never

    internal enum Element: Sendable {
        case move(to: KindlePoint)
        case line(to: KindlePoint)
        case quadCurve(to: KindlePoint, control: KindlePoint)
        case curve(to: KindlePoint, control1: KindlePoint, control2: KindlePoint)
        case rect(KindleRect)
        case ellipse(KindleRect)
        case closeSubpath
    }

    internal var elements: [Element] = []
    private var strokeColor: EInkColor = .black
    private var fillColor: EInkColor? = nil
    private var strokeStyle: StrokeStyle = StrokeStyle(lineWidth: 3)

    public init() {}

    public init(_ callback: (inout Path) -> Void) {
        var p = Path()
        callback(&p)
        self = p
    }

    public mutating func move(to p: KindlePoint) {
        elements.append(.move(to: p))
    }

    public mutating func addLine(to p: KindlePoint) {
        elements.append(.line(to: p))
    }

    public mutating func addQuadCurve(to end: KindlePoint, control: KindlePoint) {
        elements.append(.quadCurve(to: end, control: control))
    }

    public mutating func addCurve(to end: KindlePoint, control1: KindlePoint, control2: KindlePoint) {
        elements.append(.curve(to: end, control1: control1, control2: control2))
    }

    public mutating func addRect(_ rect: KindleRect) {
        elements.append(.rect(rect))
    }

    public mutating func addEllipse(in rect: KindleRect) {
        elements.append(.ellipse(rect))
    }

    public mutating func closeSubpath() {
        elements.append(.closeSubpath)
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 3) -> Path {
        var copy = self
        copy.strokeColor = color
        copy.strokeStyle = StrokeStyle(lineWidth: lineWidth)
        return copy
    }

    public func stroke(_ color: EInkColor = .black, style: StrokeStyle) -> Path {
        var copy = self
        copy.strokeColor = color
        copy.strokeStyle = style
        return copy
    }

    public func fill(_ color: EInkColor) -> Path {
        var copy = self
        copy.fillColor = color
        return copy
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let buf = KindleCanvasBuffer(width: 480, height: 180, fill: theme.cardBackground.grayLevel)
        let capturedElements = elements
        let strokeGray = strokeColor.grayLevel
        let fillGray = fillColor?.grayLevel
        let baseRadius = max(1, strokeStyle.lineWidth / 2)

        return KindleCanvas(
            buffer: buf,
            label: "Path",
            onPrepare: { w, h in
                buf.resizeIfNeeded(width: w, height: h, defaultFill: theme.cardBackground.grayLevel)
                buf.clear(fill: theme.cardBackground.grayLevel)

                // Compute bounding extents of the path so logical coordinates always fit inside physical (w, h)
                var maxX: Double = 1.0
                var maxY: Double = 1.0
                for el in capturedElements {
                    switch el {
                    case .move(let p), .line(let p):
                        maxX = max(maxX, p.x)
                        maxY = max(maxY, p.y)
                    case .quadCurve(let end, let ctrl):
                        maxX = max(maxX, max(end.x, ctrl.x))
                        maxY = max(maxY, max(end.y, ctrl.y))
                    case .curve(let end, let c1, let c2):
                        maxX = max(maxX, max(end.x, max(c1.x, c2.x)))
                        maxY = max(maxY, max(end.y, max(c1.y, c2.y)))
                    case .rect(let r), .ellipse(let r):
                        maxX = max(maxX, Double(r.maxX))
                        maxY = max(maxY, Double(r.maxY))
                    case .closeSubpath:
                        break
                    }
                }

                let margin = Double(baseRadius * 2 + 8)
                let availW = max(16.0, Double(w) - margin * 2.0)
                let availH = max(16.0, Double(h) - margin * 2.0)
                let scaleX = maxX > 40.0 ? (availW / maxX) : 1.0
                let scaleY = maxY > availH ? (availH / maxY) : 1.0
                let scale = min(scaleX, scaleY)
                let radius = max(1, Int((Double(baseRadius) * max(0.65, scale)).rounded()))

                func sx(_ x: Double) -> Double { margin + x * scaleX }
                func sy(_ y: Double) -> Double { margin * 0.5 + y * scaleY }

                var cur = KindlePoint.zero
                var start = KindlePoint.zero
                for el in capturedElements {
                    switch el {
                    case .move(let p):
                        let sp = KindlePoint(x: sx(p.x), y: sy(p.y))
                        cur = sp
                        start = sp
                    case .line(let p):
                        let sp = KindlePoint(x: sx(p.x), y: sy(p.y))
                        buf.drawLine(
                            fromX: Int(cur.x.rounded()),
                            fromY: Int(cur.y.rounded()),
                            toX: Int(sp.x.rounded()),
                            toY: Int(sp.y.rounded()),
                            radius: radius,
                            gray: strokeGray
                        )
                        cur = sp
                    case .quadCurve(let end, let ctrl):
                        let sEnd = KindlePoint(x: sx(end.x), y: sy(end.y))
                        let sCtrl = KindlePoint(x: sx(ctrl.x), y: sy(ctrl.y))
                        let steps = 28
                        var prev = cur
                        for s in 1...steps {
                            let t = Double(s) / Double(steps)
                            let mt = 1.0 - t
                            let x = mt * mt * cur.x + 2.0 * mt * t * sCtrl.x + t * t * sEnd.x
                            let y = mt * mt * cur.y + 2.0 * mt * t * sCtrl.y + t * t * sEnd.y
                            let pt = KindlePoint(x: x, y: y)
                            buf.drawLine(
                                fromX: Int(prev.x.rounded()),
                                fromY: Int(prev.y.rounded()),
                                toX: Int(pt.x.rounded()),
                                toY: Int(pt.y.rounded()),
                                radius: radius,
                                gray: strokeGray
                            )
                            prev = pt
                        }
                        cur = sEnd
                    case .curve(let end, let c1, let c2):
                        let sEnd = KindlePoint(x: sx(end.x), y: sy(end.y))
                        let sC1 = KindlePoint(x: sx(c1.x), y: sy(c1.y))
                        let sC2 = KindlePoint(x: sx(c2.x), y: sy(c2.y))
                        let steps = 32
                        var prev = cur
                        for s in 1...steps {
                            let t = Double(s) / Double(steps)
                            let mt = 1.0 - t
                            let x = mt * mt * mt * cur.x + 3.0 * mt * mt * t * sC1.x + 3.0 * mt * t * t * sC2.x + t * t * t * sEnd.x
                            let y = mt * mt * mt * cur.y + 3.0 * mt * mt * t * sC1.y + 3.0 * mt * t * t * sC2.y + t * t * t * sEnd.y
                            let pt = KindlePoint(x: x, y: y)
                            buf.drawLine(
                                fromX: Int(prev.x.rounded()),
                                fromY: Int(prev.y.rounded()),
                                toX: Int(pt.x.rounded()),
                                toY: Int(pt.y.rounded()),
                                radius: radius,
                                gray: strokeGray
                            )
                            prev = pt
                        }
                        cur = sEnd
                    case .rect(let r):
                        let x0 = Int(sx(Double(r.x)).rounded())
                        let y0 = Int(sy(Double(r.y)).rounded())
                        let x1 = Int(sx(Double(r.maxX)).rounded())
                        let y1 = Int(sy(Double(r.maxY)).rounded())
                        if let fg = fillGray {
                            buf.drawRect(fromX: x0, fromY: y0, toX: x1, toY: y1, radius: radius, gray: fg, filled: true)
                        }
                        buf.drawRect(fromX: x0, fromY: y0, toX: x1, toY: y1, radius: radius, gray: strokeGray, filled: false)
                    case .ellipse(let r):
                        let x0 = Int(sx(Double(r.x)).rounded())
                        let y0 = Int(sy(Double(r.y)).rounded())
                        let x1 = Int(sx(Double(r.maxX)).rounded())
                        let y1 = Int(sy(Double(r.maxY)).rounded())
                        let cx = (x0 + x1) / 2
                        let cy = (y0 + y1) / 2
                        let rad = min(max(2, x1 - x0), max(2, y1 - y0)) / 2
                        if let fg = fillGray {
                            buf.drawCircle(centerX: cx, centerY: cy, circleRadius: rad, strokeRadius: radius, gray: fg, filled: true)
                        }
                        buf.drawCircle(centerX: cx, centerY: cy, circleRadius: rad, strokeRadius: radius, gray: strokeGray, filled: false)
                    case .closeSubpath:
                        buf.drawLine(
                            fromX: Int(cur.x.rounded()),
                            fromY: Int(cur.y.rounded()),
                            toX: Int(start.x.rounded()),
                            toY: Int(start.y.rounded()),
                            radius: radius,
                            gray: strokeGray
                        )
                        cur = start
                    }
                }
            }
        )
        .frame(height: 180)
        .buildRenderTree()
    }
}

/// A color gradient represented as an array of E-Ink grayscale stops.
public struct Gradient: Equatable, Sendable {
    public let colors: [EInkColor]

    public init(colors: [EInkColor]) {
        self.colors = colors.isEmpty ? [.black, .white] : colors
    }

    internal func sampleGray(at t: Double) -> UInt8 {
        let clamped = min(1.0, max(0.0, t))
        guard colors.count > 1 else { return colors.first?.grayLevel ?? 128 }
        let scaled = clamped * Double(colors.count - 1)
        let idx = min(colors.count - 2, max(0, Int(scaled)))
        let frac = scaled - Double(idx)
        let g0 = Double(colors[idx].grayLevel)
        let g1 = Double(colors[idx + 1].grayLevel)
        return UInt8(min(255.0, max(0.0, (g0 + (g1 - g0) * frac).rounded())))
    }
}

/// A linear gradient view with optional 4x4 Bayer ordered dithering for E-Ink displays.
public struct LinearGradient: View, _PrimitiveView {
    public typealias Body = Never
    public let gradient: Gradient
    public let startPoint: UnitPoint
    public let endPoint: UnitPoint
    public let dithered: Bool
    public let height: Int

    private static let bayer4x4: [Double] = [
         0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
        12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
         3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
        15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
    ]

    public init(
        gradient: Gradient,
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing,
        dithered: Bool = false,
        height: Int = 64
    ) {
        self.gradient = gradient
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.dithered = dithered
        self.height = height
    }

    public init(
        colors: [EInkColor],
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing,
        dithered: Bool = false,
        height: Int = 64
    ) {
        self.init(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint, dithered: dithered, height: height)
    }

    public func _makeNode() -> RenderNode {
        let buf = KindleCanvasBuffer(width: 480, height: height, fill: 255)
        let grad = gradient
        let sp = startPoint
        let ep = endPoint
        let useDither = dithered

        return KindleCanvas(
            buffer: buf,
            label: "LinearGradient",
            onPrepare: { w, h in
                buf.resizeIfNeeded(width: w, height: h)
                let dx = ep.x - sp.x
                let dy = ep.y - sp.y
                let lenSq = max(0.0001, dx * dx + dy * dy)
                let fw = Double(max(1, w - 1))
                let fh = Double(max(1, h - 1))
                for y in 0..<h {
                    let ny = Double(y) / fh
                    let rowBase = y * w
                    for x in 0..<w {
                        let nx = Double(x) / fw
                        let t = ((nx - sp.x) * dx + (ny - sp.y) * dy) / lenSq
                        let gray = grad.sampleGray(at: t)
                        if useDither {
                            let threshold = Self.bayer4x4[(y & 3) * 4 + (x & 3)] * 255.0
                            buf.pixels[rowBase + x] = (Double(gray) > threshold) ? 255 : 0
                        } else {
                            buf.pixels[rowBase + x] = gray
                        }
                    }
                }
            }
        )
        .frame(height: height)
        .cornerRadius(12)
        .border(.black, width: 2, cornerRadius: 12)
        .buildRenderTree()
    }
}

/// A radial gradient view for E-Ink displays.
public struct RadialGradient: View, _PrimitiveView {
    public typealias Body = Never
    public let gradient: Gradient
    public let center: UnitPoint
    public let dithered: Bool
    public let height: Int

    private static let bayer4x4: [Double] = [
         0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
        12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
         3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
        15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
    ]

    public init(
        gradient: Gradient,
        center: UnitPoint = .center,
        dithered: Bool = false,
        height: Int = 80
    ) {
        self.gradient = gradient
        self.center = center
        self.dithered = dithered
        self.height = height
    }

    public init(
        colors: [EInkColor],
        center: UnitPoint = .center,
        dithered: Bool = false,
        height: Int = 80
    ) {
        self.init(gradient: Gradient(colors: colors), center: center, dithered: dithered, height: height)
    }

    public func _makeNode() -> RenderNode {
        let buf = KindleCanvasBuffer(width: 480, height: height, fill: 255)
        let grad = gradient
        let ctr = center
        let useDither = dithered

        return KindleCanvas(
            buffer: buf,
            label: "RadialGradient",
            onPrepare: { w, h in
                buf.resizeIfNeeded(width: w, height: h)
                let fw = Double(max(1, w - 1))
                let fh = Double(max(1, h - 1))
                for y in 0..<h {
                    let ny = (Double(y) / fh - ctr.y) * 1.4
                    let rowBase = y * w
                    for x in 0..<w {
                        let nx = (Double(x) / fw - ctr.x) * 1.4
                        let t = min(1.0, max(0.0, hypot(nx, ny)))
                        let gray = grad.sampleGray(at: t)
                        if useDither {
                            let threshold = Self.bayer4x4[(y & 3) * 4 + (x & 3)] * 255.0
                            buf.pixels[rowBase + x] = (Double(gray) > threshold) ? 255 : 0
                        } else {
                            buf.pixels[rowBase + x] = gray
                        }
                    }
                }
            }
        )
        .frame(height: height)
        .cornerRadius(12)
        .border(.black, width: 2, cornerRadius: 12)
        .buildRenderTree()
    }
}
