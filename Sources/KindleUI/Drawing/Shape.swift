import Foundation

// MARK: - SwiftUI Shapes (Shape, RoundedRectangle, Capsule, Circle, Rectangle)

/// A 2D shape that you can use when drawing a view on E-Ink displays.
public protocol Shape: View {
    func fill(_ color: EInkColor) -> Self
    func stroke(_ color: EInkColor, lineWidth: Int) -> Self
}

/// A rectangular shape with rounded corners, aligned inside the frame of the view containing it.
public struct RoundedRectangle: Shape, _PrimitiveView {
    public typealias Body = Never
    public let cornerRadius: Int
    private var fillColor: EInkColor?
    private var strokeColor: EInkColor?
    private var lineWidth: Int = 0

    public init(cornerRadius: Int) {
        self.cornerRadius = max(0, cornerRadius)
    }

    public func fill(_ color: EInkColor) -> RoundedRectangle {
        var copy = self
        copy.fillColor = color
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> RoundedRectangle {
        var copy = self
        copy.strokeColor = color
        copy.lineWidth = max(1, lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        var style = ViewStyle()
        style.cornerRadius = cornerRadius
        if let fill = fillColor {
            style.backgroundColor = fill
        } else if strokeColor == nil {
            style.backgroundColor = theme.foreground
        }
        if let stroke = strokeColor {
            style.borderColor = stroke
            style.borderWidth = lineWidth
        }
        return .vstack(alignment: .center, spacing: 0, children: [], style: style)
    }
}

/// A capsule shape (rounded rectangle whose corner radius is half the length of its smaller edge).
public struct Capsule: Shape, _PrimitiveView {
    public typealias Body = Never
    private var inner: RoundedRectangle

    public init() {
        self.inner = RoundedRectangle(cornerRadius: 999)
    }

    public func fill(_ color: EInkColor) -> Capsule {
        var copy = self
        copy.inner = copy.inner.fill(color)
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> Capsule {
        var copy = self
        copy.inner = copy.inner.stroke(color, lineWidth: lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        inner._makeNode()
    }
}

/// A circular shape.
public struct Circle: Shape, _PrimitiveView {
    public typealias Body = Never
    private var inner: RoundedRectangle

    public init() {
        self.inner = RoundedRectangle(cornerRadius: 999)
    }

    public func fill(_ color: EInkColor) -> Circle {
        var copy = self
        copy.inner = copy.inner.fill(color)
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> Circle {
        var copy = self
        copy.inner = copy.inner.stroke(color, lineWidth: lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        inner._makeNode()
    }
}

/// A rectangular shape with sharp corners.
public struct Rectangle: Shape, _PrimitiveView {
    public typealias Body = Never
    private var inner: RoundedRectangle

    public init() {
        self.inner = RoundedRectangle(cornerRadius: 0)
    }

    public func fill(_ color: EInkColor) -> Rectangle {
        var copy = self
        copy.inner = copy.inner.fill(color)
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> Rectangle {
        var copy = self
        copy.inner = copy.inner.stroke(color, lineWidth: lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        inner._makeNode()
    }
}



extension Shape where Self == Rectangle {
    /// A rectangular shape with sharp corners (`Rectangle()`).
    public static var rect: Rectangle {
        Rectangle()
    }
}

extension Shape where Self == RoundedRectangle {
    /// A rectangular shape with rounded corners (`RoundedRectangle(cornerRadius:)`).
    public static func rect(cornerRadius: Int) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }
}

extension Shape where Self == Capsule {
    /// A capsule shape (`Capsule()`).
    public static var capsule: Capsule {
        Capsule()
    }
}

extension Shape where Self == Circle {
    /// A circular shape (`Circle()`).
    public static var circle: Circle {
        Circle()
    }
}

extension Shape {
    internal var _resolvedCornerRadius: Int {
        if self is Circle || self is Capsule {
            return 999
        } else if let rr = self as? RoundedRectangle {
            return rr.cornerRadius
        } else if let urr = self as? UnevenRoundedRectangle {
            return (urr.topLeadingRadius + urr.topTrailingRadius + urr.bottomTrailingRadius + urr.bottomLeadingRadius) / 4
        } else if self is Rectangle {
            return 0
        }
        return 12
    }

    internal func _applyShape(to style: inout ViewStyle) {
        if self is Ellipse {
            style.isEllipse = true
        } else if let urr = self as? UnevenRoundedRectangle {
            style.unevenCorners = (
                topLeading: urr.topLeadingRadius,
                topTrailing: urr.topTrailingRadius,
                bottomTrailing: urr.bottomTrailingRadius,
                bottomLeading: urr.bottomLeadingRadius
            )
        } else {
            style.cornerRadius = self._resolvedCornerRadius
        }
    }
}

extension View {
    /// Fills the background of this view with the given E-Ink shade clipped to `shape` (e.g. `.background(.lightGray, in: .rect(cornerRadius: 12))`).
    public func background<S: Shape>(_ style: EInkColor, in shape: S) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { viewStyle in
            viewStyle.latchPaddingIntoContent()
            viewStyle.backgroundColor = style
            shape._applyShape(to: &viewStyle)
        }
    }

    /// Fills the background of this view using the active theme's panel shade clipped to `shape` (e.g. `.background(in: .rect(cornerRadius: 12))`).
    public func background<S: Shape>(in shape: S) -> ModifiedContent<Self> {
        self.background(KindleTheme.current.panelBackground, in: shape)
    }

    /// Strokes the border of this view with `style` along `shape` (e.g. `.overlay(.black, in: .rect(cornerRadius: 12))`).
    public func overlay<S: Shape>(_ style: EInkColor, in shape: S, lineWidth: Int = 2) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { viewStyle in
            viewStyle.latchPaddingIntoContent()
            viewStyle.borderColor = style
            viewStyle.borderWidth = max(1, lineWidth)
            shape._applyShape(to: &viewStyle)
        }
    }

    /// Sets a clipping shape for this view (e.g. `.clipShape(.rect(cornerRadius: 12))` or `.clipShape(.capsule)`).
    public func clipShape<S: Shape>(_ shape: S) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { viewStyle in
            viewStyle.latchPaddingIntoContent()
            shape._applyShape(to: &viewStyle)
        }
    }

    /// Masks this view using the alpha channel of the given view.
    public func mask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> ModifiedContent<Self> {
        _ = mask()
        return self.cornerRadius(14)
    }
}



public struct ContainerRelativeShape: InsettableShape, _PrimitiveView {
    public typealias Body = Never
    private var inner = RoundedRectangle(cornerRadius: 16)

    public init() {}

    public func fill(_ color: EInkColor) -> ContainerRelativeShape {
        var copy = self
        copy.inner = copy.inner.fill(color)
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> ContainerRelativeShape {
        var copy = self
        copy.inner = copy.inner.stroke(color, lineWidth: lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        inner._makeNode()
    }
}



// MARK: - 17. UnevenRoundedRectangle, Ellipse, InsettableShape & Closure-Based Canvas

/// A shape that can be inset to produce another shape, supporting `.strokeBorder(_:lineWidth:)`.
public protocol InsettableShape: Shape {
    func strokeBorder(_ color: EInkColor, lineWidth: Int) -> Self
}

extension InsettableShape {
    public func strokeBorder(_ color: EInkColor = .black, lineWidth: Int = 2) -> Self {
        self.stroke(color, lineWidth: lineWidth)
    }
}

extension RoundedRectangle: InsettableShape {}
extension Capsule: InsettableShape {}
extension Circle: InsettableShape {}
extension Rectangle: InsettableShape {}

/// A rectangular shape with rounded corners of different radii.
public struct UnevenRoundedRectangle: InsettableShape, _PrimitiveView {
    public typealias Body = Never
    public let topLeadingRadius: Int
    public let bottomLeadingRadius: Int
    public let bottomTrailingRadius: Int
    public let topTrailingRadius: Int
    private var fillColor: EInkColor?
    private var strokeColor: EInkColor?
    private var lineWidth: Int = 0

    public init(
        topLeadingRadius: Int = 0,
        bottomLeadingRadius: Int = 0,
        bottomTrailingRadius: Int = 0,
        topTrailingRadius: Int = 0
    ) {
        self.topLeadingRadius = max(0, topLeadingRadius)
        self.bottomLeadingRadius = max(0, bottomLeadingRadius)
        self.bottomTrailingRadius = max(0, bottomTrailingRadius)
        self.topTrailingRadius = max(0, topTrailingRadius)
    }

    public func fill(_ color: EInkColor) -> UnevenRoundedRectangle {
        var copy = self
        copy.fillColor = color
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> UnevenRoundedRectangle {
        var copy = self
        copy.strokeColor = color
        copy.lineWidth = max(1, lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        var style = ViewStyle()
        style.unevenCorners = (
            topLeading: topLeadingRadius,
            topTrailing: topTrailingRadius,
            bottomTrailing: bottomTrailingRadius,
            bottomLeading: bottomLeadingRadius
        )
        if let fill = fillColor {
            style.backgroundColor = fill
        } else if strokeColor == nil {
            style.backgroundColor = theme.foreground
        }
        if let stroke = strokeColor {
            style.borderColor = stroke
            style.borderWidth = lineWidth
        }
        return .vstack(alignment: .center, spacing: 0, children: [], style: style)
    }
}

/// An ellipse aligned inside the frame of the view containing it.
public struct Ellipse: InsettableShape, _PrimitiveView {
    public typealias Body = Never
    private var fillColor: EInkColor?
    private var strokeColor: EInkColor?
    private var lineWidth: Int = 0

    public init() {}

    public func fill(_ color: EInkColor) -> Ellipse {
        var copy = self
        copy.fillColor = color
        return copy
    }

    public func stroke(_ color: EInkColor = .black, lineWidth: Int = 2) -> Ellipse {
        var copy = self
        copy.strokeColor = color
        copy.lineWidth = max(1, lineWidth)
        return copy
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        var style = ViewStyle()
        style.isEllipse = true
        if let fill = fillColor {
            style.backgroundColor = fill
        } else if strokeColor == nil {
            style.backgroundColor = theme.foreground
        }
        if let stroke = strokeColor {
            style.borderColor = stroke
            style.borderWidth = lineWidth
        }
        return .vstack(alignment: .center, spacing: 0, children: [], style: style)
    }
}

extension Shape where Self == UnevenRoundedRectangle {
    /// A rectangular shape with individually configurable corner radii.
    public static func rect(
        topLeadingRadius: Int = 0,
        bottomLeadingRadius: Int = 0,
        bottomTrailingRadius: Int = 0,
        topTrailingRadius: Int = 0
    ) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeadingRadius,
            bottomLeadingRadius: bottomLeadingRadius,
            bottomTrailingRadius: bottomTrailingRadius,
            topTrailingRadius: topTrailingRadius
        )
    }
}

extension Shape where Self == Ellipse {
    /// An elliptical shape (`Ellipse()`).
    public static var ellipse: Ellipse {
        Ellipse()
    }
}
