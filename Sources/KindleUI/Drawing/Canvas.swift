import Foundation

/// Integer rectangle in 2D widget coordinates.
public struct KindleRect: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var maxX: Int { x + w }
    public var maxY: Int { y + h }
    public var isEmpty: Bool { w <= 0 || h <= 0 }

    public func union(_ o: KindleRect) -> KindleRect {
        let nx = min(x, o.x), ny = max(0, min(y, o.y))
        return KindleRect(x: nx, y: ny, w: max(maxX, o.maxX) - nx, h: max(maxY, o.maxY) - ny)
    }

    public func intersection(_ o: KindleRect) -> KindleRect? {
        let nx = max(x, o.x), ny = max(y, o.y)
        let mx = min(maxX, o.maxX), my = min(maxY, o.maxY)
        guard mx > nx, my > ny else { return nil }
        return KindleRect(x: nx, y: ny, w: mx - nx, h: my - ny)
    }
}

/// Generic 8-bit grayscale pixel buffer backing a `KindleCanvas` view (`0 = black`, `255 = white`).
open class KindleCanvasBuffer: @unchecked Sendable {
    public private(set) var width: Int
    public private(set) var height: Int
    public var pixels: [UInt8]
    public var undoPixels: [UInt8] = []
    public var strokeStartX: Int = 0
    public var strokeStartY: Int = 0

    public init(width: Int = 800, height: Int = 600, fill: UInt8 = 255) {
        let w = max(16, width)
        let h = max(16, height)
        self.width = w
        self.height = h
        self.pixels = [UInt8](repeating: fill, count: w * h)
    }

    public func saveUndoSnapshot() {
        undoPixels = pixels
    }

    @discardableResult
    public func restoreUndoSnapshot() -> Bool {
        guard undoPixels.count == pixels.count else { return false }
        pixels = undoPixels
        return true
    }

    public var bounds: KindleRect {
        KindleRect(x: 0, y: 0, w: width, h: height)
    }

    /// Fills the entire buffer with `fill` (`255 = white`, `0 = black`).
    public func clear(fill: UInt8 = 255) {
        for i in pixels.indices {
            pixels[i] = fill
        }
    }

    /// Inverts all grayscale pixels in the buffer (`255 - pixel`).
    public func invert() {
        for i in pixels.indices {
            pixels[i] = 255 &- pixels[i]
        }
    }

    /// Draws a circular brush stamp at `(x, y)` and returns the dirtied rectangle.
    @discardableResult
    public func drawBrush(x: Int, y: Int, radius: Int = 4, gray: UInt8 = 0) -> KindleRect {
        let r = max(1, radius)
        let x0 = max(0, x - r)
        let x1 = min(width - 1, x + r)
        let y0 = max(0, y - r)
        let y1 = min(height - 1, y + r)
        guard x1 >= x0 && y1 >= y0 else { return KindleRect(x: 0, y: 0, w: 0, h: 0) }
        let r2 = r * r
        for py in y0...y1 {
            let dy = py - y
            let rowBase = py * width
            for px in x0...x1 {
                let dx = px - x
                if dx * dx + dy * dy <= r2 {
                    pixels[rowBase + px] = gray
                }
            }
        }
        return KindleRect(x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1)
    }

    /// Draws a line between two points using `drawBrush` and returns the dirtied rectangle.
    @discardableResult
    public func drawLine(fromX x0: Int, fromY y0: Int, toX x1: Int, toY y1: Int, radius: Int = 3, gray: UInt8 = 0) -> KindleRect {
        let steps = max(1, max(abs(x1 - x0), abs(y1 - y0)))
        var dirty = drawBrush(x: x0, y: y0, radius: radius, gray: gray)
        for s in 1...steps {
            let x = x0 + ((x1 - x0) * s) / steps
            let y = y0 + ((y1 - y0) * s) / steps
            dirty = dirty.union(drawBrush(x: x, y: y, radius: radius, gray: gray))
        }
        return dirty
    }

    /// Draws an outlined or filled rectangle between two corners and returns the dirtied rectangle.
    @discardableResult
    public func drawRect(
        fromX x0: Int,
        fromY y0: Int,
        toX x1: Int,
        toY y1: Int,
        radius: Int = 2,
        gray: UInt8 = 0,
        filled: Bool = false
    ) -> KindleRect {
        let minX = max(0, min(x0, x1))
        let maxX = min(width - 1, max(x0, x1))
        let minY = max(0, min(y0, y1))
        let maxY = min(height - 1, max(y0, y1))
        guard maxX >= minX && maxY >= minY else { return KindleRect(x: 0, y: 0, w: 0, h: 0) }
        if filled {
            for py in minY...maxY {
                let rowBase = py * width
                for px in minX...maxX {
                    pixels[rowBase + px] = gray
                }
            }
            return KindleRect(x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1)
        } else {
            var dirty = drawLine(fromX: minX, fromY: minY, toX: maxX, toY: minY, radius: radius, gray: gray)
            dirty = dirty.union(drawLine(fromX: maxX, fromY: minY, toX: maxX, toY: maxY, radius: radius, gray: gray))
            dirty = dirty.union(drawLine(fromX: maxX, fromY: maxY, toX: minX, toY: maxY, radius: radius, gray: gray))
            dirty = dirty.union(drawLine(fromX: minX, fromY: maxY, toX: minX, toY: minY, radius: radius, gray: gray))
            return dirty
        }
    }

    /// Draws an outlined or filled circle centered at `(centerX, centerY)` with the given `circleRadius`.
    @discardableResult
    public func drawCircle(
        centerX cx: Int,
        centerY cy: Int,
        circleRadius: Int,
        strokeRadius: Int = 2,
        gray: UInt8 = 0,
        filled: Bool = false
    ) -> KindleRect {
        let r = max(2, circleRadius)
        if filled {
            return drawBrush(x: cx, y: cy, radius: r, gray: gray)
        }
        let steps = max(24, r * 3)
        var dirty = KindleRect(x: max(0, cx - r), y: max(0, cy - r), w: 1, h: 1)
        for s in 0..<steps {
            let a0 = (Double(s) / Double(steps)) * 6.2831853
            let a1 = (Double(s + 1) / Double(steps)) * 6.2831853
            let px0 = cx + Int((cos(a0) * Double(r)).rounded())
            let py0 = cy + Int((sin(a0) * Double(r)).rounded())
            let px1 = cx + Int((cos(a1) * Double(r)).rounded())
            let py1 = cy + Int((sin(a1) * Double(r)).rounded())
            dirty = dirty.union(drawLine(fromX: px0, fromY: py0, toX: px1, toY: py1, radius: strokeRadius, gray: gray))
        }
        return dirty
    }

    /// Resizes the backing pixel array if the widget allocation changed.
    /// Subclasses can override `didResize(fromWidth:fromHeight:)` to preserve or re-render content.
    public func resizeIfNeeded(width newW: Int, height newH: Int, defaultFill: UInt8 = 255) {
        let w = max(16, newW)
        let h = max(16, newH)
        guard w != width || h != height else { return }
        let oldW = width
        let oldH = height
        let oldPixels = pixels
        width = w
        height = h
        pixels = [UInt8](repeating: defaultFill, count: w * h)
        let copyW = min(oldW, w)
        let copyH = min(oldH, h)
        for row in 0..<copyH {
            let srcBase = row * oldW
            let dstBase = row * w
            for col in 0..<copyW {
                pixels[dstBase + col] = oldPixels[srcBase + col]
            }
        }
        didResize(fromWidth: oldW, fromHeight: oldH)
    }

    open func didResize(fromWidth oldWidth: Int, fromHeight oldHeight: Int) {}
}

/// A generic 8-bit grayscale drawing area view (`GtkDrawingArea` in GTK+-2.0).
public struct KindleCanvas: View, _PrimitiveView {
    public typealias Body = Never
    public let buffer: KindleCanvasBuffer
    public let label: String
    public let onPrepare: ((Int, Int) -> Void)?
    public let onPointer: ((_ phase: Int, _ x: Int, _ y: Int) -> KindleRect?)?

    public init(
        buffer: KindleCanvasBuffer,
        label: String = "Canvas",
        onPrepare: ((Int, Int) -> Void)? = nil,
        onPointer: ((_ phase: Int, _ x: Int, _ y: Int) -> KindleRect?)? = nil
    ) {
        self.buffer = buffer
        self.label = label
        self.onPrepare = onPrepare
        self.onPointer = onPointer
    }

    /// Convenience initializer that automatically wires freehand brush drawing on pointer press/drag.
    public init(
        buffer: KindleCanvasBuffer,
        brushRadius: Int,
        gray: UInt8 = 0,
        label: String = "Canvas"
    ) {
        self.buffer = buffer
        self.label = label
        self.onPrepare = { w, h in
            buffer.resizeIfNeeded(width: w, height: h)
        }
        var lastPoint: (Int, Int)? = nil
        self.onPointer = { phase, x, y in
            switch phase {
            case 0:
                lastPoint = (x, y)
                return buffer.drawBrush(x: x, y: y, radius: brushRadius, gray: gray)
            case 1:
                let prev = lastPoint ?? (x, y)
                lastPoint = (x, y)
                return buffer.drawLine(fromX: prev.0, fromY: prev.1, toX: x, toY: y, radius: brushRadius, gray: gray)
            default:
                lastPoint = nil
                return nil
            }
        }
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = true
        style.fill = true
        return .canvas(
            buffer: buffer,
            label: label,
            onPrepare: onPrepare,
            onPointer: onPointer,
            style: style
        )
    }
}


/// An immediate-mode drawing context passed to SwiftUI's closure-based `Canvas`.
public struct GraphicsContext {
    public let buffer: KindleCanvasBuffer

    public init(buffer: KindleCanvasBuffer) {
        self.buffer = buffer
    }

    public func stroke(_ path: Path, with color: EInkColor = .black, lineWidth: Int = 2) {
        let radius = max(1, lineWidth / 2)
        let gray = color.grayLevel
        var cur = KindlePoint.zero
        var start = KindlePoint.zero
        for el in path.elements {
            switch el {
            case .move(let p):
                cur = p
                start = p
            case .line(let p):
                buffer.drawLine(fromX: Int(cur.x), fromY: Int(cur.y), toX: Int(p.x), toY: Int(p.y), radius: radius, gray: gray)
                cur = p
            case .quadCurve(let end, let ctrl):
                var prev = cur
                for s in 1...20 {
                    let t = Double(s) / 20.0
                    let mt = 1.0 - t
                    let pt = KindlePoint(
                        x: mt * mt * cur.x + 2 * mt * t * ctrl.x + t * t * end.x,
                        y: mt * mt * cur.y + 2 * mt * t * ctrl.y + t * t * end.y
                    )
                    buffer.drawLine(fromX: Int(prev.x), fromY: Int(prev.y), toX: Int(pt.x), toY: Int(pt.y), radius: radius, gray: gray)
                    prev = pt
                }
                cur = end
            case .curve(let end, let c1, let c2):
                var prev = cur
                for s in 1...24 {
                    let t = Double(s) / 24.0
                    let mt = 1.0 - t
                    let pt = KindlePoint(
                        x: mt * mt * mt * cur.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * end.x,
                        y: mt * mt * mt * cur.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * end.y
                    )
                    buffer.drawLine(fromX: Int(prev.x), fromY: Int(prev.y), toX: Int(pt.x), toY: Int(pt.y), radius: radius, gray: gray)
                    prev = pt
                }
                cur = end
            case .rect(let r):
                buffer.drawRect(fromX: r.x, fromY: r.y, toX: r.maxX, toY: r.maxY, radius: radius, gray: gray, filled: false)
            case .ellipse(let r):
                buffer.drawCircle(centerX: r.x + r.w / 2, centerY: r.y + r.h / 2, circleRadius: min(r.w, r.h) / 2, strokeRadius: radius, gray: gray, filled: false)
            case .closeSubpath:
                buffer.drawLine(fromX: Int(cur.x), fromY: Int(cur.y), toX: Int(start.x), toY: Int(start.y), radius: radius, gray: gray)
                cur = start
            }
        }
    }

    public func fill(_ path: Path, with color: EInkColor = .black) {
        let gray = color.grayLevel
        for el in path.elements {
            switch el {
            case .rect(let r):
                buffer.drawRect(fromX: r.x, fromY: r.y, toX: r.maxX, toY: r.maxY, radius: 1, gray: gray, filled: true)
            case .ellipse(let r):
                buffer.drawCircle(centerX: r.x + r.w / 2, centerY: r.y + r.h / 2, circleRadius: min(r.w, r.h) / 2, strokeRadius: 1, gray: gray, filled: true)
            default:
                break
            }
        }
    }
}

/// A SwiftUI closure-based view type that supports immediate-mode 2D drawing via `GraphicsContext`.
public struct Canvas: View, _PrimitiveView {
    public typealias Body = Never
    public let height: Int
    private let renderer: (inout GraphicsContext, GeometrySize) -> Void

    public init(
        height: Int = 180,
        renderer: @escaping (inout GraphicsContext, GeometrySize) -> Void
    ) {
        self.height = height
        self.renderer = renderer
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let buf = KindleCanvasBuffer(width: 600, height: height, fill: theme.cardBackground.grayLevel)
        let drawClosure = renderer

        return KindleCanvas(
            buffer: buf,
            label: "Canvas",
            onPrepare: { w, h in
                buf.resizeIfNeeded(width: w, height: h, defaultFill: theme.cardBackground.grayLevel)
                buf.clear(fill: theme.cardBackground.grayLevel)
                var ctx = GraphicsContext(buffer: buf)
                drawClosure(&ctx, GeometrySize(width: Double(w), height: Double(h)))
            }
        )
        .frame(height: height)
        .border(theme.border, width: 2, cornerRadius: 12)
        .buildRenderTree()
    }
}
