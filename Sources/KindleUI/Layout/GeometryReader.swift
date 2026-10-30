import Foundation
import CKindleGTK

// MARK: - GeometryReader, ViewThatFits, ScrollViewReader & Menu

/// A 2D size value provided by `GeometryProxy`.
public struct GeometrySize: Sendable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// A proxy for access to the size and coordinate space of the container view.
public struct GeometryProxy: Sendable, Equatable {
    public let size: GeometrySize
    public let safeAreaInsets: EdgeInsets

    public init(size: GeometrySize, safeAreaInsets: EdgeInsets = EdgeInsets()) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }
}

/// A container view that defines its content as a function of its own size and coordinate space.
public struct GeometryReader<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: (GeometryProxy) -> Content

    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        let scale = max(0.28, kgtk_get_ui_scale())
        let logicalWidth = 1860.0
        let logicalHeight = 2480.0
        _ = scale
        let proxy = GeometryProxy(
            size: GeometrySize(width: logicalWidth, height: logicalHeight),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        )
        return content(proxy)
            .expand(true, fill: true)
            .buildRenderTree()
    }
}

/// A view that adapts to the available space by providing the first child view that fits.
public struct ViewThatFits<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        let candidates = content().buildRenderTree().flattenedChildren
        return candidates.first ?? .empty
    }
}



// MARK: - TimelineView & TimelineSchedule

/// A schedule that defines when a `TimelineView` updates its content.
public struct TimelineSchedule: Sendable, Equatable {
    public let intervalSeconds: Double
    public let isPaused: Bool

    public init(intervalSeconds: Double = 1.0, isPaused: Bool = false) {
        self.intervalSeconds = max(0.1, intervalSeconds)
        self.isPaused = isPaused
    }

    public static func periodic(from startDate: Date = Date(), by interval: Double) -> TimelineSchedule {
        _ = startDate
        return TimelineSchedule(intervalSeconds: interval, isPaused: false)
    }

    public static var everyMinute: TimelineSchedule {
        TimelineSchedule(intervalSeconds: 60.0, isPaused: false)
    }

    public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> TimelineSchedule {
        TimelineSchedule(intervalSeconds: minimumInterval ?? 1.0, isPaused: paused)
    }
}

/// Context passed to a `TimelineView` closure containing the scheduled date and cadence.
public struct TimelineViewContext: Sendable, Equatable {
    public enum Cadence: Sendable, Equatable {
        case live
        case seconds
        case minutes
    }
    public let date: Date
    public let cadence: Cadence

    public init(date: Date = Date(), cadence: Cadence = .seconds) {
        self.date = date
        self.cadence = cadence
    }
}

/// A view that updates according to a `TimelineSchedule` (e.g. for live clocks, reading timers, or system monitors).
public struct TimelineView<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public typealias Context = TimelineViewContext

    public let schedule: TimelineSchedule
    private let siteKey: String
    private let dateBox: StateBox<Date>
    private let content: (TimelineViewContext) -> Content

    public init(
        _ schedule: TimelineSchedule = .periodic(by: 1.0),
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @ViewBuilder content: @escaping (TimelineViewContext) -> Content
    ) {
        self.schedule = schedule
        let key = "timeline:\(fileID):\(line):\(column)"
        self.siteKey = key
        self.dateBox = KindleStateRegistry.shared.obtainBox(
            siteKey: key,
            initialValue: { Date() }
        )
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        let interval = schedule.intervalSeconds
        let paused = schedule.isPaused
        let box = dateBox
        if !paused {
            KindleStateRegistry.shared.registerAsyncTask(
                id: siteKey,
                token: AnyHashable(interval)
            ) {
                let ns = UInt64(max(0.1, interval) * 1_000_000_000.0)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: ns)
                    if Task.isCancelled { break }
                    box.value = Date()
                }
            }
        }
        let cadence: Context.Cadence = interval >= 60.0 ? .minutes : (interval < 1.0 ? .live : .seconds)
        return content(Context(date: box.value, cadence: cadence)).buildRenderTree()
    }
}
