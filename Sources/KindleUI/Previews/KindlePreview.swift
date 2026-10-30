#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation
import CKindleGTK

// MARK: - SwiftUI-Style Preview Registration

/// A named preview entry that can be inspected in the KindleUI Browser Preview Studio (`--preview`).
public struct KindlePreviewItem: Sendable {
    public let id: String
    public let title: String
    public let devicePreset: String?
    internal let builder: @Sendable () -> RenderNode

    public init<V: View>(
        _ title: String,
        devicePreset: String? = nil,
        @ViewBuilder content: @escaping @Sendable () -> V
    ) {
        self.id = title.lowercased().replacingOccurrences(of: " ", with: "-")
        self.title = title
        self.devicePreset = devicePreset
        self.builder = { content().buildRenderTree() }
    }
}

/// Global registry of `KindlePreview` definitions available in the Browser Preview Studio.
public final class KindlePreviewRegistry: @unchecked Sendable {
    public static let shared = KindlePreviewRegistry()

    private let lock = NSLock()
    private var items: [KindlePreviewItem] = []

    private init() {}

    public func register(_ item: KindlePreviewItem) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
    }

    public func register<V: View>(
        _ title: String,
        devicePreset: String? = nil,
        @ViewBuilder content: @escaping @Sendable () -> V
    ) {
        register(KindlePreviewItem(title, devicePreset: devicePreset, content: content))
    }

    public var registeredItems: [KindlePreviewItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }
}

/// Registers a standalone `View` preview and optionally launches the live Browser Preview Server.
public struct KindlePreview<Content: View> {
    public let item: KindlePreviewItem

    @discardableResult
    public init(
        _ title: String = "Preview",
        devicePreset: String? = nil,
        @ViewBuilder content: @escaping @Sendable () -> Content
    ) {
        let previewItem = KindlePreviewItem(title, devicePreset: devicePreset, content: content)
        self.item = previewItem
        KindlePreviewRegistry.shared.register(previewItem)
    }

    /// Starts the interactive Browser Preview Server for this preview.
    public func serve(port: UInt16 = 8080) -> Never {
        let server = KindlePreviewServer(
            defaultConfig: KindleWindowConfig(applicationID: "org.kindlemodding.preview.\(item.id)"),
            rootBuilder: item.builder
        )
        server.run(preferredPort: port)
    }
}

