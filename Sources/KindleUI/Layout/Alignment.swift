import Foundation

public enum HorizontalAlignment: Sendable, Equatable {
    case leading
    case center
    case trailing

    public var gtkAlign: Float {
        switch self {
        case .leading: return 0.0
        case .center: return 0.5
        case .trailing: return 1.0
        }
    }
}

public enum VerticalAlignment: Sendable, Equatable {
    case top
    case center
    case bottom

    public var gtkAlign: Float {
        switch self {
        case .top: return 0.0
        case .center: return 0.5
        case .bottom: return 1.0
        }
    }
}

public struct Alignment: Sendable, Equatable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment

    public init(horizontal: HorizontalAlignment = .center, vertical: VerticalAlignment = .center) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let center        = Alignment(horizontal: .center, vertical: .center)
    public static let leading       = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing      = Alignment(horizontal: .trailing, vertical: .center)
    public static let top           = Alignment(horizontal: .center, vertical: .top)
    public static let bottom        = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading    = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing   = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

public struct EdgeInsets: Sendable, Equatable {
    public var top: Int
    public var leading: Int
    public var bottom: Int
    public var trailing: Int

    public init(top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static func all(_ value: Int) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
}

public struct Edge: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let top      = Edge(rawValue: 1 << 0)
    public static let leading  = Edge(rawValue: 1 << 1)
    public static let bottom   = Edge(rawValue: 1 << 2)
    public static let trailing = Edge(rawValue: 1 << 3)

    public static let horizontal: Edge = [.leading, .trailing]
    public static let vertical: Edge   = [.top, .bottom]
    public static let all: Edge        = [.top, .leading, .bottom, .trailing]
}



// MARK: - 6. Custom Vector Path, StrokeStyle, Gradients & E-Ink Dithering

/// A 2D point with floating-point coordinates for `Path` drawing.
public struct KindlePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = KindlePoint(x: 0, y: 0)
}

/// A normalized 2D coordinate (`0.0 ... 1.0`) used for gradient start/end points.
public struct UnitPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = UnitPoint(x: 0.0, y: 0.0)
    public static let center = UnitPoint(x: 0.5, y: 0.5)
    public static let leading = UnitPoint(x: 0.0, y: 0.5)
    public static let trailing = UnitPoint(x: 1.0, y: 0.5)
    public static let top = UnitPoint(x: 0.5, y: 0.0)
    public static let bottom = UnitPoint(x: 0.5, y: 1.0)
    public static let topLeading = UnitPoint(x: 0.0, y: 0.0)
    public static let topTrailing = UnitPoint(x: 1.0, y: 0.0)
    public static let bottomLeading = UnitPoint(x: 0.0, y: 1.0)
    public static let bottomTrailing = UnitPoint(x: 1.0, y: 1.0)
}



// MARK: - 13. Fine-Grained Layout, Coordinate Transforms & Geometry Modifiers

/// Constants that define how a view's content fills the available space.
public enum ContentMode: String, Sendable, Equatable, CaseIterable {
    case fit
    case fill
}

/// A geometric angle whose value you access in either radians or degrees.
public struct Angle: Equatable, Comparable, Sendable {
    public var radians: Double
    public var degrees: Double {
        get { radians * 180.0 / .pi }
        set { radians = newValue * .pi / 180.0 }
    }

    public init() {
        self.radians = 0.0
    }

    public init(radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.radians = degrees * .pi / 180.0
    }

    public static let zero = Angle(radians: 0.0)

    public static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    public static func < (lhs: Angle, rhs: Angle) -> Bool {
        lhs.radians < rhs.radians
    }
}

/// A view's size and its alignment guides in its own coordinate space.
public struct ViewDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int = 100, height: Int = 44) {
        self.width = width
        self.height = height
    }

    public subscript(guide: HorizontalAlignment) -> Int {
        switch guide {
        case .leading: return 0
        case .center: return width / 2
        case .trailing: return width
        }
    }

    public subscript(guide: VerticalAlignment) -> Int {
        switch guide {
        case .top: return 0
        case .center: return height / 2
        case .bottom: return height
        }
    }
}

/// The horizontal or vertical dimension in a 2D coordinate system.
public enum Axis: Int8, CaseIterable, Sendable, Equatable {
    case horizontal
    case vertical

    public struct Set: OptionSet, Sendable, Equatable, Hashable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }

        public static let horizontal = Axis.Set(rawValue: 1 << 0)
        public static let vertical = Axis.Set(rawValue: 1 << 1)
    }
}

/// A shape that is replaced by an inset version of the current container's shape.
