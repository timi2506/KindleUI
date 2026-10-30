import Foundation
import CKindleGTK

// MARK: - Embedded WebKitGTK 1.0 WebView & WebViewController

/// Observable controller for an embedded Kindle `WebView` (`libwebkitgtk-1.0.so.0`).
///
/// Supports direct URI navigation, raw HTML/CSS/JS rendering, JavaScript evaluation,
/// full-content zoom scaling for 300 DPI E-Ink displays, and an optional modern TLS 1.3
/// fetch bridge via `KindleHTTP` (`URLSession`) for HTTPS sites that reject legacy `libsoup` TLS.
@Observable
public final class WebViewController: @unchecked Sendable {
    public let id: String
    public var url: String
    public var html: String?
    public var baseURL: String?
    public var zoomLevel: Double
    public var isLoading: Bool = false
    public var statusText: String = "Ready"
    private var historyStack: [String] = []
    private var historyIndex: Int = -1

    public init(
        id: String = "default",
        url: String = "",
        html: String? = nil,
        baseURL: String? = "https://kindle.local/",
        zoomLevel: Double = 1.6
    ) {
        self.id = id
        self.url = url
        self.html = html
        self.baseURL = baseURL
        self.zoomLevel = zoomLevel
        if !url.isEmpty {
            self.historyStack = [url]
            self.historyIndex = 0
        }
    }

    /// Returns `true` if `libwebkitgtk-1.0.so.0` is available on the current Kindle / host.
    public var isWebKitAvailable: Bool {
        kgtk_webkit_available()
    }

    /// Returns the active unproxied URI currently displayed by the underlying `WebKitWebView`.
    public var currentURL: String {
        id.withCString { cId in
            guard let ptr = kgtk_webview_get_uri(cId) else { return "" }
            return String(cString: ptr)
        }
    }

    internal func recordNavigation(to newURL: String) {
        guard !newURL.isEmpty, !newURL.contains("__local_doc_") else { return }
        if historyIndex >= 0 && historyIndex < historyStack.count && historyStack[historyIndex] == newURL {
            return
        }
        if historyIndex + 1 < historyStack.count {
            historyStack.removeSubrange((historyIndex + 1)..<historyStack.count)
        }
        historyStack.append(newURL)
        historyIndex = historyStack.count - 1
    }

    /// Loads a URL via the built-in TLS 1.3 WebKit proxy so HTML, external CSS stylesheets, and images load cleanly.
    public func load(url newURL: String, viaModernTLS: Bool = false) {
        let trimmed = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = viaModernTLS
        isLoading = true
        statusText = "Loading…"
        html = nil
        url = trimmed
        recordNavigation(to: trimmed)
        id.withCString { cId in
            trimmed.withCString { cUrl in
                kgtk_webview_load_uri(cId, cUrl)
            }
        }
    }

    /// Renders an HTML/CSS/JS string directly inside the embedded `WebKitWebView`.
    public func loadHTML(_ htmlContent: String, baseURL: String = "https://kindle.local/", title: String = "HTML Document") {
        self.isLoading = false
        self.baseURL = baseURL
        self.url = baseURL
        self.html = htmlContent
        self.statusText = title
        id.withCString { cId in
            htmlContent.withCString { cHtml in
                baseURL.withCString { cBase in
                    kgtk_webview_load_html(cId, cHtml, cBase)
                }
            }
        }
    }

    /// Executes JavaScript inside the active `WebKitWebView` page context.
    public func evaluateJavaScript(_ script: String) {
        id.withCString { cId in
            script.withCString { cScript in
                kgtk_webview_execute_script(cId, cScript)
            }
        }
        KindleDevice.shared.performAutomaticRefresh()
    }

    public func reload() {
        id.withCString { kgtk_webview_reload($0) }
    }

    public func stopLoading() {
        isLoading = false
        id.withCString { kgtk_webview_stop_loading($0) }
    }

    public func goBack() {
        if historyIndex > 0 {
            historyIndex -= 1
            let target = historyStack[historyIndex]
            isLoading = true
            statusText = "Loading…"
            html = nil
            url = target
            id.withCString { cId in
                target.withCString { cUrl in
                    kgtk_webview_load_uri(cId, cUrl)
                }
            }
        } else {
            id.withCString { kgtk_webview_go_back($0) }
        }
    }

    public func goForward() {
        if historyIndex >= 0 && historyIndex + 1 < historyStack.count {
            historyIndex += 1
            let target = historyStack[historyIndex]
            isLoading = true
            statusText = "Loading…"
            html = nil
            url = target
            id.withCString { cId in
                target.withCString { cUrl in
                    kgtk_webview_load_uri(cId, cUrl)
                }
            }
        } else {
            id.withCString { kgtk_webview_go_forward($0) }
        }
    }

    public var canGoBack: Bool {
        historyIndex > 0 || id.withCString { kgtk_webview_can_go_back($0) }
    }

    public var canGoForward: Bool {
        (historyIndex >= 0 && historyIndex + 1 < historyStack.count) || id.withCString { kgtk_webview_can_go_forward($0) }
    }

    public func zoomIn(step: Double = 0.25) {
        zoomLevel = min(4.5, zoomLevel + step)
    }

    public func zoomOut(step: Double = 0.25) {
        zoomLevel = max(0.5, zoomLevel - step)
    }
}

/// An embedded WebKitGTK (`libwebkitgtk-1.0.so.0`) browser view that renders HTML/CSS/JavaScript
/// and web URLs natively inside a KindleUI view hierarchy.
///
/// The underlying `WebKitWebView` widget instance is automatically cached across state rebuilds
/// by its `id` so DOM state, scroll position, and JavaScript variables remain intact.
public struct WebView: View, _PrimitiveView {
    public typealias Body = Never
    public let id: String
    public let url: String
    public let html: String?
    public let baseURL: String?
    public let zoomLevel: Double
    public let minHeight: Int
    public let onLoadFinished: (() -> Void)?

    /// Creates a `WebView` driven by a `WebViewController`.
    public init(
        controller: WebViewController,
        minHeight: Int = 560,
        onLoadFinished: (() -> Void)? = nil
    ) {
        self.id = controller.id
        self.url = controller.url
        self.html = controller.html
        self.baseURL = controller.baseURL
        self.zoomLevel = controller.zoomLevel
        _ = controller.isLoading
        _ = controller.statusText
        self.minHeight = max(160, minHeight)
        self.onLoadFinished = {
            if controller.html == nil {
                let actual = controller.currentURL
                if !actual.isEmpty && !actual.contains("__local_doc_") {
                    if controller.url != actual {
                        controller.url = actual
                    }
                    controller.recordNavigation(to: actual)
                }
            }
            if controller.isLoading {
                controller.isLoading = false
            }
            controller.statusText = "Finished"
            onLoadFinished?()
        }
    }

    /// Creates a `WebView` loading a remote or local URL.
    public init(
        url: String,
        id: String = "default",
        zoomLevel: Double = 1.6,
        minHeight: Int = 560,
        onLoadFinished: (() -> Void)? = nil
    ) {
        self.id = id
        self.url = url
        self.html = nil
        self.baseURL = nil
        self.zoomLevel = zoomLevel
        self.minHeight = max(160, minHeight)
        self.onLoadFinished = onLoadFinished
    }

    /// Creates a `WebView` rendering an inline HTML/CSS/JavaScript document.
    public init(
        html: String,
        baseURL: String = "https://kindle.local/",
        id: String = "default",
        zoomLevel: Double = 1.6,
        minHeight: Int = 560,
        onLoadFinished: (() -> Void)? = nil
    ) {
        self.id = id
        self.url = ""
        self.html = html
        self.baseURL = baseURL
        self.zoomLevel = zoomLevel
        self.minHeight = max(160, minHeight)
        self.onLoadFinished = onLoadFinished
    }

    public func _makeNode() -> RenderNode {
        var style = ViewStyle()
        style.expand = true
        style.fill = true
        return .webView(
            id: id,
            url: url,
            html: html,
            baseURL: baseURL,
            zoomLevel: zoomLevel,
            minHeight: minHeight,
            onLoadFinished: onLoadFinished,
            style: style
        )
    }
}
