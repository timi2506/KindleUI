import Foundation

/// 16-shade E-Ink grayscale color representation tailored for Kindle displays.
public struct EInkColor: Sendable, Equatable {
    /// 8-bit grayscale value (`0x00` = pure black ink, `0xFF` = paper white).
    public let grayLevel: UInt8

    public init(grayLevel: UInt8) {
        self.grayLevel = grayLevel
    }

    /// Creates one of the 16 native Kindle E-Ink grayscale levels (`0...15`).
    public static func eInkShade(_ shade: Int) -> EInkColor {
        let clamped = max(0, min(15, shade))
        return EInkColor(grayLevel: UInt8(clamped * 17))
    }

    public static let black       = EInkColor(grayLevel: 0x00)
    public static let charcoal    = EInkColor(grayLevel: 0x22)
    public static let darkGray    = EInkColor(grayLevel: 0x44)
    public static let gray        = EInkColor(grayLevel: 0x77)
    public static let mediumGray  = EInkColor(grayLevel: 0x99)
    public static let silver      = EInkColor(grayLevel: 0xCC)
    public static let lightGray   = EInkColor(grayLevel: 0xEE)
    public static let paperWhite  = EInkColor(grayLevel: 0xFF)

    public var hexString: String {
        String(format: "#%02X%02X%02X", grayLevel, grayLevel, grayLevel)
    }
}

/// Typography definitions mapped to Kindle Pango/GTK2 fonts (e.g., Bookerly, Amazon Ember, Futura, Caecilia, Sans, Monospace).
public struct KindleFont: Sendable, Equatable {
    public let family: String
    public let sizePoints: Int
    public var isBold: Bool
    public var isItalic: Bool

    public init(family: String = "Sans", sizePoints: Int = 12, isBold: Bool = false, isItalic: Bool = false) {
        self.family = family
        self.sizePoints = sizePoints
        self.isBold = isBold
        self.isItalic = isItalic
    }

    public static let largeTitle  = KindleFont(family: "Serif", sizePoints: 22, isBold: true)
    public static let title       = KindleFont(family: "Serif", sizePoints: 18, isBold: true)
    public static let headline    = KindleFont(family: "Sans", sizePoints: 14, isBold: true)
    public static let subheadline = KindleFont(family: "Sans", sizePoints: 12, isBold: false, isItalic: true)
    public static let body        = KindleFont(family: "Serif", sizePoints: 12, isBold: false)
    public static let caption     = KindleFont(family: "Sans", sizePoints: 10, isBold: false)
    public static let monospaced  = KindleFont(family: "Monospace", sizePoints: 11, isBold: false)

    public static func bookerly(size: Int = 13, bold: Bool = false, italic: Bool = false) -> KindleFont {
        KindleFont(family: "Bookerly, Serif", sizePoints: size, isBold: bold, isItalic: italic)
    }

    public static func custom(_ family: String, size: Int, bold: Bool = false, italic: Bool = false) -> KindleFont {
        KindleFont(family: family, sizePoints: size, isBold: bold, isItalic: italic)
    }

    /// Pango font description string used by GTK+-2.0 (e.g. `"Serif Bold 18"`).
    public var pangoDescription: String {
        var parts = [family]
        if isBold { parts.append("Bold") }
        if isItalic { parts.append("Italic") }
        parts.append("\(sizePoints)")
        return parts.joined(separator: " ")
    }
}

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

/// Visual and layout modifiers attached to a `RenderNode`.
public struct ViewStyle: @unchecked Sendable {
    public var font: KindleFont?
    public var foregroundColor: EInkColor?
    public var backgroundColor: EInkColor?
    public var borderColor: EInkColor?
    public var borderWidth: Int = 0
    public var padding: EdgeInsets?
    public var width: Int?
    public var height: Int?
    public var expand: Bool = false
    public var fill: Bool = true
    public var alignment: Alignment?
    public var windowConfig: KindleWindowConfig?
    public var onAppear: (() -> Void)?

    public init() {}
}

/// Intermediate node representation of a KindleUI view hierarchy.
public indirect enum RenderNode: @unchecked Sendable {
    case empty
    case group([RenderNode])
    case vstack(alignment: HorizontalAlignment, spacing: Int, children: [RenderNode], style: ViewStyle)
    case hstack(alignment: VerticalAlignment, spacing: Int, children: [RenderNode], style: ViewStyle)
    case zstack(alignment: Alignment, children: [RenderNode], style: ViewStyle)
    case scrollView(showsIndicators: Bool, child: RenderNode, style: ViewStyle)
    case card(title: String?, child: RenderNode, style: ViewStyle)
    case text(content: String, wrap: Bool, alignment: HorizontalAlignment, style: ViewStyle)
    case button(label: String, customChild: RenderNode?, action: () -> Void, style: ViewStyle)
    case toggle(label: String, isOn: Bool, onToggle: (Bool) -> Void, style: ViewStyle)
    case textField(placeholder: String, text: String, onTextChange: (String) -> Void, style: ViewStyle)
    case slider(value: Double, range: ClosedRange<Double>, step: Double, onValueChange: (Double) -> Void, style: ViewStyle)
    case progressBar(fraction: Double, text: String?, style: ViewStyle)
    case divider(vertical: Bool, style: ViewStyle)
    case spacer(minLength: Int?, style: ViewStyle)
    case image(path: String, altText: String, style: ViewStyle)

    /// Returns a copy of this node with a modified `ViewStyle`.
    public func modifyingStyle(_ transform: (inout ViewStyle) -> Void) -> RenderNode {
        switch self {
        case .empty:
            return .empty
        case .group(let nodes):
            return .group(nodes.map { $0.modifyingStyle(transform) })
        case .vstack(let align, let spacing, let children, var style):
            transform(&style)
            return .vstack(alignment: align, spacing: spacing, children: children, style: style)
        case .hstack(let align, let spacing, let children, var style):
            transform(&style)
            return .hstack(alignment: align, spacing: spacing, children: children, style: style)
        case .zstack(let align, let children, var style):
            transform(&style)
            return .zstack(alignment: align, children: children, style: style)
        case .scrollView(let ind, let child, var style):
            transform(&style)
            return .scrollView(showsIndicators: ind, child: child, style: style)
        case .card(let title, let child, var style):
            transform(&style)
            return .card(title: title, child: child, style: style)
        case .text(let content, let wrap, let align, var style):
            transform(&style)
            return .text(content: content, wrap: wrap, alignment: align, style: style)
        case .button(let label, let customChild, let action, var style):
            transform(&style)
            return .button(label: label, customChild: customChild, action: action, style: style)
        case .toggle(let label, let isOn, let onToggle, var style):
            transform(&style)
            return .toggle(label: label, isOn: isOn, onToggle: onToggle, style: style)
        case .textField(let ph, let txt, let onChange, var style):
            transform(&style)
            return .textField(placeholder: ph, text: txt, onTextChange: onChange, style: style)
        case .slider(let val, let range, let step, let onChange, var style):
            transform(&style)
            return .slider(value: val, range: range, step: step, onValueChange: onChange, style: style)
        case .progressBar(let frac, let txt, var style):
            transform(&style)
            return .progressBar(fraction: frac, text: txt, style: style)
        case .divider(let vert, var style):
            transform(&style)
            return .divider(vertical: vert, style: style)
        case .spacer(let minLen, var style):
            transform(&style)
            return .spacer(minLength: minLen, style: style)
        case .image(let path, let alt, var style):
            transform(&style)
            return .image(path: path, altText: alt, style: style)
        }
    }

    /// Flattens `.group` and `.empty` nodes into a clean child array.
    public var flattenedChildren: [RenderNode] {
        switch self {
        case .empty:
            return []
        case .group(let items):
            return items.flatMap { $0.flattenedChildren }
        default:
            return [self]
        }
    }

    /// Extracts any `KindleWindowConfig` attached via `.kindleWindow(...)` in the tree.
    public var extractedWindowConfig: KindleWindowConfig? {
        switch self {
        case .empty:
            return nil
        case .group(let children):
            for c in children {
                if let cfg = c.extractedWindowConfig { return cfg }
            }
            return nil
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            if let cfg = style.windowConfig { return cfg }
            for c in children {
                if let cfg = c.extractedWindowConfig { return cfg }
            }
            return nil
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.windowConfig ?? child.extractedWindowConfig
        case .text(_, _, _, let style),
             .button(_, _, _, let style),
             .toggle(_, _, _, let style),
             .textField(_, _, _, let style),
             .slider(_, _, _, _, let style),
             .progressBar(_, _, let style),
             .divider(_, let style),
             .spacer(_, let style),
             .image(_, _, let style):
            return style.windowConfig
        }
    }
}

/// Internal protocol allowing primitives to build a `RenderNode` directly without infinite recursion.
public protocol _PrimitiveView {
    func _makeNode() -> RenderNode
}

/// A type that represents part of your Kindle application's user interface
/// and provides modifiers that you use to configure views.
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never {
        fatalError("Never.body should never be called.")
    }
}

extension View where Body == Never {
    public var body: Never {
        fatalError("\(Self.self) is a primitive view; its body should not be evaluated directly.")
    }
}

extension View {
    /// Evaluates the view hierarchy into a concrete `RenderNode` tree.
    public func buildRenderTree() -> RenderNode {
        if let primitive = self as? _PrimitiveView {
            return primitive._makeNode()
        }
        return self.body.buildRenderTree()
    }
}

/// A custom parameter attribute that constructs KindleUI views from closures, matching SwiftUI's `@ViewBuilder`.
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }

    public static func buildBlock<Content: View>(_ content: Content) -> Content {
        content
    }

    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<[RenderNode]> {
        TupleView([c0.buildRenderTree(), c1.buildRenderTree()])
    }

    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<[RenderNode]> {
        TupleView([c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree()])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<[RenderNode]> {
        TupleView([c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(), c3.buildRenderTree()])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<[RenderNode]> {
        TupleView([c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(), c3.buildRenderTree(), c4.buildRenderTree()])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<[RenderNode]> {
        TupleView([
            c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(),
            c3.buildRenderTree(), c4.buildRenderTree(), c5.buildRenderTree()
        ])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<[RenderNode]> {
        TupleView([
            c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(),
            c3.buildRenderTree(), c4.buildRenderTree(), c5.buildRenderTree(),
            c6.buildRenderTree()
        ])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<[RenderNode]> {
        TupleView([
            c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(),
            c3.buildRenderTree(), c4.buildRenderTree(), c5.buildRenderTree(),
            c6.buildRenderTree(), c7.buildRenderTree()
        ])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<[RenderNode]> {
        TupleView([
            c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(),
            c3.buildRenderTree(), c4.buildRenderTree(), c5.buildRenderTree(),
            c6.buildRenderTree(), c7.buildRenderTree(), c8.buildRenderTree()
        ])
    }

    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<[RenderNode]> {
        TupleView([
            c0.buildRenderTree(), c1.buildRenderTree(), c2.buildRenderTree(),
            c3.buildRenderTree(), c4.buildRenderTree(), c5.buildRenderTree(),
            c6.buildRenderTree(), c7.buildRenderTree(), c8.buildRenderTree(),
            c9.buildRenderTree()
        ])
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> AnyView {
        if let content = content {
            return AnyView(content)
        }
        return AnyView(EmptyView())
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(first component: TrueContent) -> AnyView {
        AnyView(component)
    }

    public static func buildEither<TrueContent: View, FalseContent: View>(second component: FalseContent) -> AnyView {
        AnyView(component)
    }

    public static func buildArray<Content: View>(_ components: [Content]) -> TupleView<[RenderNode]> {
        TupleView(components.map { $0.buildRenderTree() })
    }
}
