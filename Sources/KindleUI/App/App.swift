#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation


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
    /// Application identifier used to scope persistent storage on disk (overrides the `App` type name when set;
    /// `WindowGroup(id:)` also sets this automatically before evaluating its root view).
    static var applicationID: String { get }
    var body: Self.Body { get }
    init()
}

extension App {
    public static var applicationID: String {
        String(describing: Self.self)
    }

    /// Entry point invoked by Swift's `@main` attribute.
    public static func main() {
        #if canImport(Glibc) || canImport(Darwin)
        signal(SIGPIPE, SIG_IGN)
        setvbuf(stdout, nil, _IOLBF, 0)
        #endif
        KindleStateRegistry.shared.configureApplicationID(Self.applicationID)

        let appInstance = Self.init()
        let initialConfig = appInstance.body.windowConfig

        let args = CommandLine.arguments
        if args.contains("--preview") || ProcessInfo.processInfo.environment["KINDLEUI_PREVIEW"] == "1" {
            let previewServer = KindlePreviewServer(defaultConfig: initialConfig) {
                appInstance.body.buildRootNode()
            }
            previewServer.run()
        }

        let gtkRenderer = GTK2Renderer(defaultConfig: initialConfig) {
            appInstance.body.buildRootNode()
        }
        if !gtkRenderer.start() {
            fputs("[KindleUI] Error: GTK+-2.0 runtime (libgtk-x11-2.0.so.0) could not be initialized. Pass --preview to launch the browser-based KindleUI Live Preview Studio.\n", stderr)
            exit(1)
        }
    }
}
