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

/// A type that represents the structure and behavior of a Kindle application.
///
/// Create a KindleUI app by declaring a structure that conforms to `App` and annotating it with `@main`:
/// ```swift
/// import KindleUI
///
/// @main
/// struct MyKindleApp: App {
///     var body: some Scene {
///         WindowGroup(id: "org.kindlemodding.myapp", chrome: .topBar) {
///             ContentView()
///         }
///     }
/// }
/// ```
public protocol App {
    associatedtype Body: Scene
    var body: Self.Body { get }
    init()
}

extension App {
    /// Entry point invoked by Swift's `@main` attribute.
    public static func main() {
        let args = CommandLine.arguments

        // Check for CLI flags passed to the app executable
        if let emitIndex = args.firstIndex(of: "--emit-meson"), emitIndex + 1 < args.count {
            let outDir = args[emitIndex + 1]
            let execName: String
            if let nameIdx = args.firstIndex(of: "--name"), nameIdx + 1 < args.count {
                execName = args[nameIdx + 1]
            } else {
                execName = String(describing: Self.self).lowercased()
            }

            KindleStateRegistry.shared.beginRenderPass()
            let appInstance = Self.init()
            let scene = appInstance.body
            let tree = scene.buildRootNode()
            KindleStateRegistry.shared.endRenderPass()

            let config = tree.extractedWindowConfig ?? scene.windowConfig
            do {
                try MesonCPPGenerator.writeMesonProject(
                    executableName: execName,
                    tree: tree,
                    config: config,
                    outputDirectory: outDir
                )
                print("[KindleUI] Generated Meson + GTK+-2.0 C++17 project in '\(outDir)' (AwesomeWM title: \(config.awesomeWindowTitle))")
                return
            } catch {
                fputs("[KindleUI] Failed to emit Meson project: \(error)\n", stderr)
                exit(1)
            }
        }

        if let htmlIndex = args.firstIndex(of: "--export-html"), htmlIndex + 1 < args.count {
            let outPath = args[htmlIndex + 1]
            KindleStateRegistry.shared.beginRenderPass()
            let appInstance = Self.init()
            let scene = appInstance.body
            let tree = scene.buildRootNode()
            KindleStateRegistry.shared.endRenderPass()

            let config = tree.extractedWindowConfig ?? scene.windowConfig
            let html = EInkSimulatorRenderer.generateHTMLPreview(tree: tree, config: config)
            do {
                try html.write(toFile: outPath, atomically: true, encoding: .utf8)
                print("[KindleUI] Exported E-Ink HTML preview to '\(outPath)'")
                return
            } catch {
                fputs("[KindleUI] Failed to write HTML preview: \(error)\n", stderr)
                exit(1)
            }
        }

        let forceSimulator = args.contains("--sim") || args.contains("--terminal")
        let singleSnapshot = args.contains("--snapshot")

        let defaultScene: () -> (RenderNode, KindleWindowConfig) = {
            let instance = Self.init()
            let scene = instance.body
            let node = scene.buildRootNode()
            let cfg = node.extractedWindowConfig ?? scene.windowConfig
            return (node, cfg)
        }

        KindleStateRegistry.shared.beginRenderPass()
        let (_, initialConfig) = defaultScene()
        KindleStateRegistry.shared.endRenderPass()
        KindleStateRegistry.shared.resetAllState()

        if !forceSimulator && !singleSnapshot {
            let gtkRenderer = GTK2Renderer(defaultConfig: initialConfig) {
                let (node, _) = defaultScene()
                return node
            }
            if gtkRenderer.start() {
                return
            }
            print("[KindleUI] GTK+-2.0 runtime not detected on host; launching interactive E-Ink Terminal Simulator...")
        }

        let sim = EInkSimulatorRenderer(defaultConfig: initialConfig) {
            let (node, _) = defaultScene()
            return node
        }
        sim.runInteractiveTerminal(singleFrameOnly: singleSnapshot)
    }
}
