import Foundation

// MARK: - Composable Gestures (DragGesture, TapGesture, LongPressGesture, MagnificationGesture)

/// Protocol adopted by composable SwiftUI-style gestures (`DragGesture`, `TapGesture`, `LongPressGesture`, `MagnificationGesture`).
public protocol KindleGesture: Sendable {
    func _apply(to style: inout ViewStyle)
}

/// A dragging motion that invokes an action as the drag-event sequence changes (`value.location`, `value.translation`).
public struct DragGesture: KindleGesture {
    public struct Point: Sendable, Equatable {
        public var x: Double
        public var y: Double
        public init(x: Double = 0, y: Double = 0) {
            self.x = x
            self.y = y
        }
        public static let zero = Point(x: 0, y: 0)
    }

    public struct Translation: Sendable, Equatable {
        public var width: Double
        public var height: Double
        public init(width: Double = 0, height: Double = 0) {
            self.width = width
            self.height = height
        }
        public static let zero = Translation(width: 0, height: 0)
    }

    public struct Value: Sendable, Equatable {
        public var startLocation: Point
        public var location: Point
        public var translation: Translation

        public var predictedEndLocation: Point {
            Point(
                x: location.x + translation.width * 0.25,
                y: location.y + translation.height * 0.25
            )
        }

        public var predictedEndTranslation: Translation {
            Translation(
                width: translation.width * 1.25,
                height: translation.height * 1.25
            )
        }

        public init(startLocation: Point, location: Point, translation: Translation) {
            self.startLocation = startLocation
            self.location = location
            self.translation = translation
        }
    }

    public let minimumDistance: Double
    private var changedHandler: (@Sendable (Value) -> Void)?
    private var endedHandler: (@Sendable (Value) -> Void)?

    public init(minimumDistance: Double = 4.0) {
        self.minimumDistance = minimumDistance
    }

    public func onChanged(_ action: @escaping @Sendable (Value) -> Void) -> DragGesture {
        var copy = self
        copy.changedHandler = action
        return copy
    }

    public func onEnded(_ action: @escaping @Sendable (Value) -> Void) -> DragGesture {
        var copy = self
        copy.endedHandler = action
        return copy
    }

    public func _apply(to style: inout ViewStyle) {
        let minDist = max(0.0, minimumDistance)
        if let onChanged = changedHandler {
            style.onDragChanged = { sx, sy, dx, dy in
                let dist = hypot(Double(dx), Double(dy))
                guard dist >= minDist else { return }
                let val = Value(
                    startLocation: Point(x: Double(sx), y: Double(sy)),
                    location: Point(x: Double(sx + dx), y: Double(sy + dy)),
                    translation: Translation(width: Double(dx), height: Double(dy))
                )
                onChanged(val)
            }
        }
        if let onEnded = endedHandler {
            style.onDragEnded = { sx, sy, dx, dy in
                let dist = hypot(Double(dx), Double(dy))
                guard dist >= minDist else { return }
                let val = Value(
                    startLocation: Point(x: Double(sx), y: Double(sy)),
                    location: Point(x: Double(sx + dx), y: Double(sy + dy)),
                    translation: Translation(width: Double(dx), height: Double(dy))
                )
                onEnded(val)
            }
        }
    }
}

/// A gesture that recognizes one or more taps.
public struct TapGesture: KindleGesture {
    public let count: Int
    private var endedHandler: (@Sendable () -> Void)?

    public init(count: Int = 1) {
        self.count = max(1, count)
    }

    public func onEnded(_ action: @escaping @Sendable () -> Void) -> TapGesture {
        var copy = self
        copy.endedHandler = action
        return copy
    }

    public func _apply(to style: inout ViewStyle) {
        if let onEnded = endedHandler {
            style.onTapGesture = onEnded
        }
    }
}

/// A gesture that succeeds when the user presses and holds for at least `minimumDuration` seconds.
public struct LongPressGesture: KindleGesture {
    public let minimumDuration: Double
    private var endedHandler: (@Sendable (Bool) -> Void)?

    public init(minimumDuration: Double = 0.5) {
        self.minimumDuration = minimumDuration
    }

    public func onEnded(_ action: @escaping @Sendable (Bool) -> Void) -> LongPressGesture {
        var copy = self
        copy.endedHandler = action
        return copy
    }

    public func _apply(to style: inout ViewStyle) {
        style.longPressDurationMs = max(150, Int(minimumDuration * 1000.0))
        if let onEnded = endedHandler {
            style.onLongPressGesture = { onEnded(true) }
        }
    }
}

/// A gesture that recognizes a magnification motion and tracks the scale factor.
public struct MagnificationGesture: KindleGesture {
    public typealias Value = Double
    public let minimumScaleDelta: Double
    private var changedHandler: (@Sendable (Double) -> Void)?
    private var endedHandler: (@Sendable (Double) -> Void)?

    public init(minimumScaleDelta: Double = 0.01) {
        self.minimumScaleDelta = minimumScaleDelta
    }

    public func onChanged(_ action: @escaping @Sendable (Double) -> Void) -> MagnificationGesture {
        var copy = self
        copy.changedHandler = action
        return copy
    }

    public func onEnded(_ action: @escaping @Sendable (Double) -> Void) -> MagnificationGesture {
        var copy = self
        copy.endedHandler = action
        return copy
    }

    public func _apply(to style: inout ViewStyle) {
        if let onChanged = changedHandler {
            style.onDragChanged = { _, _, dx, dy in
                let scale = max(0.25, min(4.0, 1.0 + Double(dx - dy) / 240.0))
                onChanged(scale)
            }
        }
        if let onEnded = endedHandler {
            style.onDragEnded = { _, _, dx, dy in
                let scale = max(0.25, min(4.0, 1.0 + Double(dx - dy) / 240.0))
                onEnded(scale)
            }
        }
    }
}

public typealias MagnifyGesture = MagnificationGesture

extension View {
    /// Attaches a composable gesture (`DragGesture`, `TapGesture`, `LongPressGesture`, `MagnificationGesture`) to this view.
    public func gesture<G: KindleGesture>(_ gesture: G) -> ModifiedContent<Self> {
        ModifiedContent(content: self) { style in
            gesture._apply(to: &style)
        }
    }

    /// Attaches a gesture to process simultaneously with gestures defined by the view.
    public func simultaneousGesture<G: KindleGesture>(_ gesture: G) -> ModifiedContent<Self> {
        self.gesture(gesture)
    }

    /// Attaches a gesture with higher priority than gestures defined by the view.
    public func highPriorityGesture<G: KindleGesture>(_ gesture: G) -> ModifiedContent<Self> {
        self.gesture(gesture)
    }
}

// MARK: - .swipeActions Modifier for List / ForEach Rows

/// Horizontal edge for `.swipeActions(edge:allowsFullSwipe:content:)`.
public enum HorizontalEdge: Sendable, Equatable {
    case leading
    case trailing
}

private struct _SwipeActionsRow<Content: View, Actions: View>: View {
    let content: Content
    let edge: HorizontalEdge
    let allowsFullSwipe: Bool
    let actions: () -> Actions

    @State private var isRevealed: Bool = false
    @Environment(\.editMode) private var editMode

    var body: some View {
        let showing = isRevealed || (editMode?.wrappedValue.isEditing ?? false)
        HStack(alignment: .center, spacing: 14) {
            if showing && edge == .leading {
                actions()
            }
            content
                .expand(true, fill: true)
            if showing && edge == .trailing {
                actions()
            }
        }
        .onSwipeGesture(
            threshold: 32,
            onLeft: {
                if edge == .trailing {
                    isRevealed = true
                } else {
                    isRevealed = false
                }
            },
            onRight: {
                if edge == .leading {
                    isRevealed = true
                } else {
                    isRevealed = false
                }
            }
        )
    }
}

extension View {
    /// Adds custom swipe actions to a row in a `List` or `ForEach` (revealed by swiping horizontally or activating `EditMode`).
    public func swipeActions<Actions: View>(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        @ViewBuilder content: @escaping () -> Actions
    ) -> some View {
        _SwipeActionsRow(
            content: self,
            edge: edge,
            allowsFullSwipe: allowsFullSwipe,
            actions: content
        )
    }
}
