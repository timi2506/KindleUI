import Foundation

/// A part of an app's user interface with a life cycle managed by KindleUI.
public protocol Scene {
    var windowConfig: KindleWindowConfig { get }
    func buildRootNode() -> RenderNode
}

/// A scene that presents a standard Kindle application window managed by Awesome Window Manager.
public struct WindowGroup<Content: View>: Scene {
    public let windowConfig: KindleWindowConfig
    private let contentBuilder: () -> Content

    public init(
        config: KindleWindowConfig = KindleWindowConfig(),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.windowConfig = config
        self.contentBuilder = content
        KindleStateRegistry.shared.configureApplicationID(config.applicationID)
    }

    public init(
        id: String,
        layer: KindleLayer = .application,
        role: KindleWindowRole = .application,
        chrome: KindleChrome = .topBar,
        orientations: KindleOrientation = [],
        width: Int = 600,
        height: Int = 800,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.windowConfig = KindleWindowConfig(
            applicationID: id,
            layer: layer,
            role: role,
            persistentChrome: chrome,
            orientations: orientations,
            width: width,
            height: height
        )
        self.contentBuilder = content
        KindleStateRegistry.shared.configureApplicationID(id)
    }

    public func buildRootNode() -> RenderNode {
        contentBuilder().buildRenderTree()
    }
}

/// A scene that presents a Kindle modal or dismissible dialog on the `D` (Dialog) layer.
public struct KindleDialogScene<Content: View>: Scene {
    public let windowConfig: KindleWindowConfig
    private let contentBuilder: () -> Content

    public init(
        id: String,
        dismissible: Bool = true,
        cornerRadius: Int = 12,
        requiresKeyboard: Bool = false,
        width: Int = 480,
        height: Int = 360,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.windowConfig = .dialog(
            id: id,
            dismissible: dismissible,
            cornerRadius: cornerRadius,
            requiresKeyboard: requiresKeyboard,
            width: width,
            height: height
        )
        self.contentBuilder = content
    }

    public func buildRootNode() -> RenderNode {
        contentBuilder().buildRenderTree()
    }
}
