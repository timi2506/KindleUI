#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation
import CKindleGTK


// MARK: - Live Browser-Based E-Ink Preview Server (macOS & Linux)

/// Interactive, 1:1 accurate browser-based preview server for `KindleUI` applications.
///
/// Mirrors `GTK2Renderer`'s exact `1860×2480` logical coordinate grid, `sizePoints * 2.75` Pango font scaling,
/// `RenderContext` inheritance, `verticalExpansionFlags` / `horizontalExpansionFlags` flex packing,
/// Cairo button/toggle/container styling, and live `@State` / `KindleHTTP` / `AsyncImage` reactivity over SSE.
public final class KindlePreviewServer: @unchecked Sendable {
    internal let defaultConfig: KindleWindowConfig
    internal let mainRootBuilder: () -> RenderNode

    internal let renderLock = NSRecursiveLock()
    internal var activeSceneID: String = "__main__"
    internal var currentTree: RenderNode = .empty
    internal var currentWindowConfig: KindleWindowConfig

    // Registered interactive callbacks for the current render pass
    internal var tapActions: [String: () -> Void] = [:]
    internal var longPressActions: [String: () -> Void] = [:]
    internal var swipeLeftActions: [String: () -> Void] = [:]
    internal var swipeRightActions: [String: () -> Void] = [:]
    internal var swipeUpActions: [String: () -> Void] = [:]
    internal var swipeDownActions: [String: () -> Void] = [:]
    internal var toggleActions: [String: (Bool) -> Void] = [:]
    internal var sliderActions: [String: (Double, Bool) -> Void] = [:]
    internal var textActions: [String: (String) -> Void] = [:]
    internal var canvasNodes: [String: (buffer: KindleCanvasBuffer, onPointer: ((Int, Int, Int) -> KindleRect?)?)] = [:]

    // Device & display simulation state
    internal var deviceModel: String = "pw5"
    internal var isLandscape: Bool = false
    internal var simulatedScreenW: Int = 1236
    internal var simulatedScreenH: Int = 1648
    internal var refreshGeneration: UInt64 = 0
    internal var pendingFullFlash: Bool = false

    // Connected SSE client file descriptors
    internal let clientsLock = NSLock()
    internal var sseClientFDs: [Int32] = []
    internal var broadcastScheduled: Bool = false

    public init(
        defaultConfig: KindleWindowConfig = KindleWindowConfig(),
        rootBuilder: @escaping () -> RenderNode
    ) {
        self.defaultConfig = defaultConfig
        self.currentWindowConfig = defaultConfig
        self.mainRootBuilder = rootBuilder
    }

    // MARK: - Server Lifecycle

    /// Starts the HTTP + SSE preview server on `preferredPort` (or the next free port) and blocks forever.
    public func run(preferredPort: UInt16 = 8080) -> Never {
        let port = Self.resolvePortFromCLI(defaultPort: preferredPort)
        kgtk_set_simulated_screen_size(Int32(simulatedScreenW), Int32(simulatedScreenH))
        KindleDevice.shared.activeApplicationID = defaultConfig.applicationID

        // Initial render pass
        _ = rebuildAndRenderLocked()

        // Hook state changes (including async KindleHTTP / URLSession / AsyncImage completions)
        KindleStateRegistry.shared.onStateDidChange = { [weak self] in
            self?.scheduleBroadcast()
        }

        // Hook explicit full E-Ink refreshes (e.g. page turns)
        let previousFullRefresh = KindleDevice.shared.onFullRefresh
        KindleDevice.shared.onFullRefresh = { [weak self] in
            previousFullRefresh?()
            self?.markFullFlashAndBroadcast()
        }

        let (serverFD, boundPort) = Self.bindServerSocket(startingAt: port)
        guard serverFD >= 0 else {
            fputs("[KindleUI Preview] Failed to bind preview HTTP socket starting at port \(port).\n", stderr)
            exit(1)
        }

        let url = "http://127.0.0.1:\(boundPort)"
        print("==================================================================")
        print("  KindleUI Live Preview Studio")
        print("  App ID : \(KindleStateRegistry.shared.applicationID)")
        print("  URL    : \(url)")
        print("  Device : Kindle Paperwhite 5 (\(simulatedScreenW)x\(simulatedScreenH), scale \(String(format: "%.3f", kgtk_get_ui_scale())))")
        print("==================================================================")
        fflush(stdout)

        if CommandLine.arguments.contains("--open") {
            Self.openBrowserIfPossible(url: url)
        }

        while true {
            var clientAddr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverFD, $0, &addrLen)
                }
            }
            guard clientFD >= 0 else { continue }
            #if canImport(Darwin)
            var noSigPipe: Int32 = 1
            setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            #endif
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.handleClientConnection(clientFD)
            }
        }
    }

    private static func resolvePortFromCLI(defaultPort: UInt16) -> UInt16 {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--port"), idx + 1 < args.count,
           let parsed = UInt16(args[idx + 1]), parsed > 0 {
            return parsed
        }
        for arg in args where arg.hasPrefix("--port=") {
            let val = String(arg.dropFirst("--port=".count))
            if let parsed = UInt16(val), parsed > 0 {
                return parsed
            }
        }
        if let envPort = ProcessInfo.processInfo.environment["KINDLEUI_PREVIEW_PORT"],
           let parsed = UInt16(envPort), parsed > 0 {
            return parsed
        }
        return defaultPort
    }

    private static func bindServerSocket(startingAt basePort: UInt16) -> (Int32, UInt16) {
        for offset in 0..<30 {
            let candidatePort = basePort &+ UInt16(offset)
            #if canImport(Glibc)
            let sockType = Int32(SOCK_STREAM.rawValue)
            #else
            let sockType = SOCK_STREAM
            #endif
            let fd = socket(AF_INET, sockType, 0)
            guard fd >= 0 else { continue }

            var reuse: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            #if canImport(Darwin)
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            #endif
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = candidatePort.bigEndian
            addr.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

            let bindRes = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindRes == 0 && listen(fd, 64) == 0 {
                return (fd, candidatePort)
            }
            close(fd)
        }
        return (-1, basePort)
    }

    private static func openBrowserIfPossible(url: String) {
        let proc = Process()
        #if os(macOS)
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [url]
        #else
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
        proc.arguments = [url]
        #endif
        try? proc.run()
    }

    // MARK: - Broadcast & State Synchronization

    internal func markFullFlashAndBroadcast() {
        renderLock.lock()
        pendingFullFlash = true
        renderLock.unlock()
        scheduleBroadcast()
    }

    internal func scheduleBroadcast() {
        clientsLock.lock()
        if broadcastScheduled {
            clientsLock.unlock()
            return
        }
        broadcastScheduled = true
        clientsLock.unlock()

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self = self else { return }
            self.clientsLock.lock()
            self.broadcastScheduled = false
            self.clientsLock.unlock()
            let frameJSON = self.rebuildAndRenderLocked()
            self.broadcastSSEFrame(frameJSON)
        }
    }

    internal func broadcastSSEFrame(_ jsonPayload: String) {
        let message = "data: \(jsonPayload)\n\n"
        clientsLock.lock()
        let fds = sseClientFDs
        clientsLock.unlock()
        guard !fds.isEmpty else { return }

        var deadFDs: [Int32] = []
        for fd in fds {
            if !Self.writeAll(fd: fd, string: message) {
                deadFDs.append(fd)
            }
        }
        if !deadFDs.isEmpty {
            clientsLock.lock()
            sseClientFDs.removeAll { deadFDs.contains($0) }
            clientsLock.unlock()
            for fd in deadFDs {
                close(fd)
            }
        }
    }

    // MARK: - HTTP Connection Handling

    internal func handleClientConnection(_ fd: Int32) {
        guard let request = Self.readHTTPRequest(fd: fd) else {
            close(fd)
            return
        }

        let method = request.method
        let pathOnly = request.path
        let query = request.queryParams

        let isGetOrHead = (method == "GET" || method == "HEAD")

        if isGetOrHead && pathOnly == "/" {
            let html = buildStudioIndexHTML()
            Self.sendHTTPResponse(fd: fd, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(html.utf8), headOnly: method == "HEAD")
            close(fd)
            return
        }

        if isGetOrHead && pathOnly == "/state" {
            let json = rebuildAndRenderLocked()
            Self.sendHTTPResponse(fd: fd, status: "200 OK", contentType: "application/json; charset=utf-8", body: Data(json.utf8), headOnly: method == "HEAD")
            close(fd)
            return
        }

        if method == "GET" && pathOnly == "/events" {
            let headers = [
                "HTTP/1.1 200 OK",
                "Content-Type: text/event-stream; charset=utf-8",
                "Cache-Control: no-cache, no-transform",
                "Connection: keep-alive",
                "Access-Control-Allow-Origin: *",
                "\r\n"
            ].joined(separator: "\r\n")
            guard Self.writeAll(fd: fd, string: headers) else {
                close(fd)
                return
            }
            let initialJSON = rebuildAndRenderLocked()
            guard Self.writeAll(fd: fd, string: "data: \(initialJSON)\n\n") else {
                close(fd)
                return
            }
            clientsLock.lock()
            sseClientFDs.append(fd)
            clientsLock.unlock()
            return
        }

        if method == "POST" && pathOnly == "/action" {
            let responseJSON = handleInteractiveAction(body: request.body)
            Self.sendHTTPResponse(fd: fd, status: "200 OK", contentType: "application/json; charset=utf-8", body: Data(responseJSON.utf8))
            close(fd)
            return
        }

        if isGetOrHead && pathOnly == "/file" {
            if let filePath = query["path"], !filePath.isEmpty {
                serveLocalImageFile(fd: fd, path: filePath, headOnly: method == "HEAD")
            } else {
                Self.sendHTTPResponse(fd: fd, status: "400 Bad Request", contentType: "text/plain", body: Data("Missing path".utf8), headOnly: method == "HEAD")
            }
            close(fd)
            return
        }

        if isGetOrHead && pathOnly == "/canvas" {
            if let id = query["id"] {
                serveCanvasBMP(fd: fd, id: id, headOnly: method == "HEAD")
            } else {
                Self.sendHTTPResponse(fd: fd, status: "400 Bad Request", contentType: "text/plain", body: Data("Missing canvas id".utf8), headOnly: method == "HEAD")
            }
            close(fd)
            return
        }

        Self.sendHTTPResponse(fd: fd, status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8), headOnly: method == "HEAD")
        close(fd)
    }

    internal func serveLocalImageFile(fd: Int32, path: String, headOnly: Bool = false) {
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              !data.isEmpty else {
            Self.sendHTTPResponse(fd: fd, status: "404 Not Found", contentType: "text/plain", body: Data("Image not found".utf8), headOnly: headOnly)
            return
        }
        let lower = path.lowercased()
        let mime: String
        if lower.hasSuffix(".svg") {
            mime = "image/svg+xml"
        } else if lower.hasSuffix(".png") {
            mime = "image/png"
        } else if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
            mime = "image/jpeg"
        } else if lower.hasSuffix(".gif") {
            mime = "image/gif"
        } else if lower.hasSuffix(".webp") {
            mime = "image/webp"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            mime = "image/png"
        } else if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            mime = "image/jpeg"
        } else if let str = String(data: data.prefix(128), encoding: .utf8), str.contains("<svg") {
            mime = "image/svg+xml"
        } else {
            mime = "application/octet-stream"
        }
        Self.sendHTTPResponse(fd: fd, status: "200 OK", contentType: mime, body: data, headOnly: headOnly)
    }

    internal func serveCanvasBMP(fd: Int32, id: String, headOnly: Bool = false) {
        renderLock.lock()
        let entry = canvasNodes[id]
        renderLock.unlock()
        guard let buffer = entry?.buffer else {
            Self.sendHTTPResponse(fd: fd, status: "404 Not Found", contentType: "text/plain", body: Data("Canvas not found".utf8), headOnly: headOnly)
            return
        }
        let bmpData = Self.encodeGrayscaleBMP(width: buffer.width, height: buffer.height, pixels: buffer.pixels)
        Self.sendHTTPResponse(fd: fd, status: "200 OK", contentType: "image/bmp", body: bmpData, headOnly: headOnly)
    }

    // MARK: - Action Execution

    internal func handleInteractiveAction(body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return rebuildAndRenderLocked()
        }

        renderLock.lock()
        let id = (json["id"] as? String) ?? ""

        switch type {
        case "tap":
            if let action = tapActions[id] {
                let kbWasVisible = KindleKeyboardManager.shared.isVisible
                let genBefore = KindleKeyboardManager.shared.interactionGeneration
                action()
                if kbWasVisible && KindleKeyboardManager.shared.isVisible && KindleKeyboardManager.shared.interactionGeneration == genBefore {
                    KindleKeyboardManager.shared.dismiss()
                }
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "longPress":
            if let action = longPressActions[id] {
                action()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "swipeLeft":
            if let action = swipeLeftActions[id] {
                action()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            } else if let firstSwipe = swipeLeftActions.values.first {
                firstSwipe()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "swipeRight":
            if let action = swipeRightActions[id] {
                action()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            } else if let firstSwipe = swipeRightActions.values.first {
                firstSwipe()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "swipeUp":
            if let action = swipeUpActions[id] {
                action()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "swipeDown":
            if let action = swipeDownActions[id] {
                action()
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "toggle":
            let value = (json["value"] as? Bool) ?? false
            if let action = toggleActions[id] {
                let kbWasVisible = KindleKeyboardManager.shared.isVisible
                let genBefore = KindleKeyboardManager.shared.interactionGeneration
                action(value)
                if kbWasVisible && KindleKeyboardManager.shared.isVisible && KindleKeyboardManager.shared.interactionGeneration == genBefore {
                    KindleKeyboardManager.shared.dismiss()
                }
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "slider":
            let value = (json["value"] as? Double) ?? 0.0
            let ended = (json["ended"] as? Bool) ?? true
            if let action = sliderActions[id] {
                action(value, ended)
                if ended {
                    KindleDevice.shared.performAutomaticRefresh(forceFull: false)
                }
            }

        case "text":
            let text = (json["value"] as? String) ?? ""
            if let action = textActions[id] {
                action(text)
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "hardwareKey":
            if let keyval = json["keyval"] as? UInt32 {
                _ = KindleKeyboardManager.shared.handleHardwareKey(keyval)
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            } else if let keyInt = json["keyval"] as? Int, keyInt >= 0 {
                _ = KindleKeyboardManager.shared.handleHardwareKey(UInt32(keyInt))
                KindleDevice.shared.performAutomaticRefresh(forceFull: false)
            }

        case "canvasPointer":
            let phase = (json["phase"] as? Int) ?? 0
            let x = (json["x"] as? Int) ?? 0
            let y = (json["y"] as? Int) ?? 0
            if let entry = canvasNodes[id], let onPointer = entry.onPointer {
                _ = onPointer(phase, x, y)
                if phase == 2 {
                    KindleDevice.shared.performAutomaticRefresh(forceFull: false)
                }
            }

        case "device":
            if let model = json["model"] as? String {
                applyDevicePresetLocked(model: model, landscape: isLandscape)
            }
            if let landscape = json["landscape"] as? Bool {
                applyDevicePresetLocked(model: deviceModel, landscape: landscape)
            }
            if let scheme = json["colorScheme"] as? String {
                KindleStateRegistry.shared.colorScheme = (scheme == "dark") ? .dark : .light
            }
            if let fl = json["frontlight"] as? Int {
                KindleDevice.shared.frontlightIntensity = fl
            }
            if let warmth = json["warmth"] as? Int {
                KindleDevice.shared.frontlightWarmth = warmth
            }
            if let battery = json["battery"] as? Int {
                KindleDevice.shared.batteryPercentage = battery
            }
            if let sceneID = json["sceneID"] as? String {
                activeSceneID = sceneID
                kgtk_reset_scroll_position()
            }
            if (json["fullRefresh"] as? Bool) == true {
                pendingFullFlash = true
                KindleDevice.shared.refreshScreen(full: true)
            }

        default:
            break
        }

        let payload = rebuildAndRenderLocked()
        renderLock.unlock()
        broadcastSSEFrame(payload)
        return payload
    }

    internal func applyDevicePresetLocked(model: String, landscape: Bool) {
        deviceModel = model
        isLandscape = landscape
        let baseW: Int
        let baseH: Int
        switch model {
        case "scribe":
            baseW = 1860
            baseH = 2480
        case "basic", "pw4":
            baseW = 1072
            baseH = 1448
        case "oasis":
            baseW = 1264
            baseH = 1680
        case "touch":
            baseW = 758
            baseH = 1024
        default: // "pw5"
            baseW = 1236
            baseH = 1648
        }
        simulatedScreenW = landscape ? baseH : baseW
        simulatedScreenH = landscape ? baseW : baseH
        kgtk_set_simulated_screen_size(Int32(simulatedScreenW), Int32(simulatedScreenH))
    }

    // MARK: - Tree Evaluation & HTML Generation

    internal func evaluateActiveTreeLocked() -> RenderNode {
        let rawTree = KindleStateRegistry.shared.evaluateTree {
            if activeSceneID != "__main__",
               let item = KindlePreviewRegistry.shared.registeredItems.first(where: { $0.id == activeSceneID }) {
                return item.builder()
            }
            return mainRootBuilder()
        }
        if let scheme = rawTree.extractedColorScheme {
            KindleStateRegistry.shared.colorScheme = scheme
        }
        if let policy = rawTree.extractedRefreshPolicy {
            KindleDevice.shared.refreshPolicy = policy
        }
        return KindleKeyboardManager.shared.wrapWithKeyboardOverlayIfNeeded(rawTree)
    }

    internal func extractRootBackground(from node: RenderNode) -> EInkColor? {
        switch node {
        case .vstack(_, _, let children, let style),
             .hstack(_, _, let children, let style),
             .zstack(_, let children, let style):
            return style.backgroundColor ?? children.first.flatMap { extractRootBackground(from: $0) }
        case .scrollView(_, let child, let style),
             .card(_, let child, let style):
            return style.backgroundColor ?? extractRootBackground(from: child)
        default:
            return node.styleSnapshot?.backgroundColor
        }
    }

    internal func rebuildAndRenderLocked() -> String {
        renderLock.lock()
        defer { renderLock.unlock() }

        tapActions.removeAll(keepingCapacity: true)
        longPressActions.removeAll(keepingCapacity: true)
        swipeLeftActions.removeAll(keepingCapacity: true)
        swipeRightActions.removeAll(keepingCapacity: true)
        swipeUpActions.removeAll(keepingCapacity: true)
        swipeDownActions.removeAll(keepingCapacity: true)
        toggleActions.removeAll(keepingCapacity: true)
        sliderActions.removeAll(keepingCapacity: true)
        textActions.removeAll(keepingCapacity: true)
        canvasNodes.removeAll(keepingCapacity: true)

        let tree = evaluateActiveTreeLocked()
        currentTree = tree
        currentWindowConfig = tree.extractedWindowConfig ?? defaultConfig
        refreshGeneration &+= 1

        let rootBg = extractRootBackground(from: tree) ?? KindleTheme.current.background
        let rootCtx = RenderContext(
            font: .body,
            fg: KindleTheme.current.foreground,
            bg: rootBg,
            buttonStyle: nil,
            toggleStyle: nil,
            controlSize: nil,
            opacity: 1.0,
            isDisabled: false,
            isBehindModal: false
        )

        let (expV, fillV) = verticalExpansionFlags(for: tree)
        let (expH, fillH) = horizontalExpansionFlags(for: tree)
        let appHTML = renderNodeToHTML(
            tree,
            path: "r",
            ctx: rootCtx,
            parentAxis: .vertical,
            expandInParent: expV,
            fillInParent: fillV,
            crossFill: fillH || expH
        )

        let hasTopBarChrome = currentWindowConfig.layer == .application && currentWindowConfig.persistentChrome.contains(.topBar)
        let topChromeHTML = hasTopBarChrome ? buildKindleSystemStatusBarHTML(bg: rootBg) : ""
        let combinedHTML = topChromeHTML + appHTML

        let fullFlash = pendingFullFlash
        pendingFullFlash = false
        let scrollResetPos = kgtk_get_scroll_position()

        var scenesList: [[String: String]] = [
            ["id": "__main__", "title": "\(KindleStateRegistry.shared.applicationID) (App)"]
        ]
        for item in KindlePreviewRegistry.shared.registeredItems {
            scenesList.append(["id": item.id, "title": item.title])
        }

        let payload: [String: Any] = [
            "html": combinedHTML,
            "bgHex": rootBg.hexString,
            "windowTitle": currentWindowConfig.awesomeWindowTitle,
            "appID": KindleStateRegistry.shared.applicationID,
            "activeSceneID": activeSceneID,
            "scenes": scenesList,
            "deviceModel": deviceModel,
            "isLandscape": isLandscape,
            "logicalWidth": isLandscape ? 2480 : 1860,
            "logicalHeight": isLandscape ? 1860 : 2480,
            "physicalWidth": simulatedScreenW,
            "physicalHeight": simulatedScreenH,
            "uiScale": kgtk_get_ui_scale(),
            "colorScheme": KindleStateRegistry.shared.colorScheme == .dark ? "dark" : "light",
            "frontlight": KindleDevice.shared.frontlightIntensity,
            "warmth": KindleDevice.shared.frontlightWarmth,
            "battery": KindleDevice.shared.batteryPercentage,
            "keyboardVisible": KindleKeyboardManager.shared.isVisible,
            "hasSwipeHandlers": !swipeLeftActions.isEmpty || !swipeRightActions.isEmpty,
            "refreshCount": KindleDevice.shared.interactionCount,
            "generation": refreshGeneration,
            "fullFlash": fullFlash,
            "scrollPosition": scrollResetPos
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    /// Renders the simulated Kindle OS AwesomeWM persistent top bar (`101/1648` of height = `152px` on `1860x2480`)
    /// when `WindowGroup` specifies `chrome: .topBar`, matching `GTK2Renderer.swift` line 387 and real Kindle OS chrome.
    internal func buildKindleSystemStatusBarHTML(bg: EInkColor) -> String {
        let theme = KindleTheme.current
        let fg = theme.foreground
        let timeStr = KindleDevice.shared.clockTimeString
        let batt = KindleDevice.shared.batteryPercentage
        let wifiSVG = Self.renderSVGIcon(.wifi, size: 28, fg: fg, bg: nil)
        let battSVG = Self.renderSVGIcon(.battery, size: 30, fg: fg, bg: nil)

        return """
        <div class="k-system-topbar" style="height: 152px; min-height: 152px; max-height: 152px; width: 100%; background-color: \(bg.hexString); padding: 0 38px; display: flex; flex-direction: row; align-items: center; justify-content: space-between; box-sizing: border-box; flex-shrink: 0; position: relative;">
            <div style="display: flex; align-items: center; gap: 14px;">
                <span style="font-family: 'Amazon Ember', 'Helvetica Neue', sans-serif; font-size: 38px; font-weight: 700; color: \(fg.hexString); letter-spacing: 0.01em;">\(Self.escapeHTML(timeStr))</span>
            </div>
            <div style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); display: flex; align-items: center; justify-content: center;">
                <svg viewBox="0 0 88 28" width="88" height="28" fill="none" stroke="\(fg.hexString)" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="16 6 44 22 72 6" />
                </svg>
            </div>
            <div style="display: flex; align-items: center; gap: 22px;">
                \(wifiSVG)
                <div style="display: inline-flex; align-items: center; gap: 10px;">
                    <span style="font-family: 'Amazon Ember', 'Helvetica Neue', sans-serif; font-size: 36px; font-weight: 700; color: \(fg.hexString);">\(batt)%</span>
                    \(battSVG)
                </div>
            </div>
        </div>
        """
    }


    // MARK: - Low-Level HTTP Parsing & Socket Helpers

    internal struct HTTPRequest {
        let method: String
        let path: String
        let queryParams: [String: String]
        let body: String
    }

    private static func readHTTPRequest(fd: Int32) -> HTTPRequest? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 8192)
        var headerEndIndex: Int? = nil
        var contentLength: Int = 0

        while true {
            let n = recv(fd, &chunk, chunk.count, 0)
            if n <= 0 { break }
            buffer.append(chunk, count: n)

            if headerEndIndex == nil,
               let range = buffer.range(of: Data([13, 10, 13, 10])) {
                headerEndIndex = range.upperBound
                if let headerStr = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: .utf8) {
                    for line in headerStr.components(separatedBy: "\r\n") {
                        let lower = line.lowercased()
                        if lower.hasPrefix("content-length:") {
                            let valStr = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                            contentLength = Int(valStr) ?? 0
                        }
                    }
                }
            }

            if let endIdx = headerEndIndex, buffer.count >= endIdx + contentLength {
                break
            }
        }

        guard let endIdx = headerEndIndex,
              let headerStr = String(data: buffer.subdata(in: 0..<(endIdx - 4)), encoding: .utf8) else {
            return nil
        }

        let lines = headerStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let rawTarget = String(parts[1])

        var pathOnly = rawTarget
        var queryParams: [String: String] = [:]
        if let qIdx = rawTarget.firstIndex(of: "?") {
            pathOnly = String(rawTarget[..<qIdx])
            let queryStr = String(rawTarget[rawTarget.index(after: qIdx)...])
            if let comps = URLComponents(string: "http://localhost?\(queryStr)"),
               let items = comps.queryItems {
                for item in items {
                    queryParams[item.name] = item.value ?? ""
                }
            }
        }

        let bodyData = buffer.count > endIdx ? buffer.subdata(in: endIdx..<min(buffer.count, endIdx + contentLength)) : Data()
        let bodyStr = String(data: bodyData, encoding: .utf8) ?? ""
        return HTTPRequest(method: method, path: pathOnly, queryParams: queryParams, body: bodyStr)
    }

    private static func sendHTTPResponse(fd: Int32, status: String, contentType: String, body: Data, headOnly: Bool = false) {
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")
        _ = writeAll(fd: fd, string: header)
        if !headOnly {
            _ = writeAll(fd: fd, data: body)
        }
    }

    private static func writeAll(fd: Int32, string: String) -> Bool {
        writeAll(fd: fd, data: Data(string.utf8))
    }

    private static func writeAll(fd: Int32, data: Data) -> Bool {
        guard !data.isEmpty else { return true }
        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return false }
            var totalSent = 0
            while totalSent < data.count {
                #if canImport(Glibc)
                let flags = Int32(MSG_NOSIGNAL)
                #else
                let flags: Int32 = 0
                #endif
                let sent = send(fd, base.advanced(by: totalSent), data.count - totalSent, flags)
                if sent <= 0 { return false }
                totalSent += sent
            }
            return true
        }
    }


}
