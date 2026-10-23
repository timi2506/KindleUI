import Foundation

/// Interactive E-Ink terminal simulator & HTML preview renderer for testing KindleUI apps on Windows/macOS/Linux without X11.
public final class EInkSimulatorRenderer: @unchecked Sendable {
    private struct InteractiveControl {
        let index: Int
        let summary: String
        let trigger: (String?) -> Void
    }

    private let defaultConfig: KindleWindowConfig
    private let makeTree: () -> RenderNode
    private var controls: [InteractiveControl] = []

    public init(defaultConfig: KindleWindowConfig, makeTree: @escaping () -> RenderNode) {
        self.defaultConfig = defaultConfig
        self.makeTree = makeTree
    }

    /// Runs an interactive terminal-based E-Ink simulator loop.
    public func runInteractiveTerminal(singleFrameOnly: Bool = false) {
        var running = true
        while running {
            KindleStateRegistry.shared.beginRenderPass()
            let tree = makeTree()
            KindleStateRegistry.shared.endRenderPass()

            let config = tree.extractedWindowConfig ?? defaultConfig
            controls.removeAll()

            let widthCols = 64
            let borderHoriz = String(repeating: "═", count: widthCols)
            let thinHoriz = String(repeating: "─", count: widthCols)

            print("\n╔\(borderHoriz)╗")
            print(padLine(" KINDLE E-INK SIMULATOR  •  \(KindleDevice.shared.batteryLevel)% 🔋  💡 \(KindleDevice.shared.frontlightIntensity)/24", width: widthCols))
            print(padLine(" AwesomeWM: \(config.awesomeWindowTitle)", width: widthCols))
            if config.persistentChrome.contains(.topBar) {
                print("╟\(thinHoriz)╢")
                print(padLine(" ⌂ Home   |   \(config.applicationID)   |   12:00 PM", width: widthCols))
            }
            if config.persistentChrome.contains(.searchBar) {
                print(padLine(" [ 🔍 Search Kindle...                                        ]", width: widthCols))
            }
            print("╠\(borderHoriz)╣")

            let lines = renderTerminalLines(node: tree, indent: 1, maxWidth: widthCols - 2)
            for line in lines {
                print(padLine(" " + line, width: widthCols))
            }

            print("╚\(borderHoriz)╝")

            if singleFrameOnly {
                break
            }

            if !controls.isEmpty {
                print("Interactive Controls: enter number [1..\(controls.count)] (for TextField/Slider: '<num> <value>'), 'html' to export preview, or 'q' to quit:")
            } else {
                print("Enter 'html' to export E-Ink HTML preview, or 'q' to quit:")
            }
            print("> ", terminator: "")
            fflush(stdout)

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                break
            }
            if input.lowercased() == "q" || input.lowercased() == "quit" || input.lowercased() == "exit" {
                running = false
                break
            }
            if input.lowercased() == "html" {
                let path = "kindle_preview.html"
                let html = Self.generateHTMLPreview(tree: tree, config: config)
                try? html.write(toFile: path, atomically: true, encoding: .utf8)
                print("Saved E-Ink HTML preview to \(path)")
                continue
            }

            let parts = input.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = parts.first, let idx = Int(first), idx >= 1 && idx <= controls.count {
                let arg = parts.count > 1 ? String(parts[1]) : nil
                controls[idx - 1].trigger(arg)
            }
        }
    }

    private func padLine(_ text: String, width: Int) -> String {
        let chars = Array(text)
        if chars.count >= width {
            return "║" + String(chars.prefix(width)) + "║"
        }
        return "║" + text + String(repeating: " ", count: width - chars.count) + "║"
    }

    private func renderTerminalLines(node: RenderNode, indent: Int, maxWidth: Int) -> [String] {
        let prefix = String(repeating: "  ", count: indent)
        switch node {
        case .empty:
            return []
        case .group(let children):
            return children.flatMap { renderTerminalLines(node: $0, indent: indent, maxWidth: maxWidth) }
        case .vstack(_, _, let children, _):
            return children.flatMap { renderTerminalLines(node: $0, indent: indent, maxWidth: maxWidth) }
        case .hstack(_, _, let children, _):
            var pieces: [String] = []
            for child in children {
                let childLines = renderTerminalLines(node: child, indent: 0, maxWidth: maxWidth)
                let joined = childLines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                if !joined.isEmpty {
                    pieces.append(joined)
                }
            }
            if pieces.isEmpty { return [] }
            return [prefix + pieces.joined(separator: "   ")]
        case .zstack(_, let children, _):
            return children.flatMap { renderTerminalLines(node: $0, indent: indent, maxWidth: maxWidth) }
        case .scrollView(_, let child, _):
            return renderTerminalLines(node: child, indent: indent, maxWidth: maxWidth)
        case .card(let title, let child, _):
            var out: [String] = []
            if let title = title, !title.isEmpty {
                out.append("\(prefix)┌─ [ \(title) ] ──────────────────────┐")
            } else {
                out.append("\(prefix)┌────────────────────────────────────┐")
            }
            out.append(contentsOf: renderTerminalLines(node: child, indent: indent + 1, maxWidth: maxWidth))
            out.append("\(prefix)└────────────────────────────────────┘")
            return out
        case .text(let content, _, _, let style):
            if let font = style.font, font.isBold {
                return ["\(prefix)★ \(content)"]
            }
            return ["\(prefix)\(content)"]
        case .button(let label, let customChild, let action, _):
            let idx = controls.count + 1
            let resolvedLabel: String
            if !label.isEmpty {
                resolvedLabel = label
            } else if let customChild = customChild {
                resolvedLabel = renderTerminalLines(node: customChild, indent: 0, maxWidth: maxWidth).joined(separator: " ").trimmingCharacters(in: .whitespaces)
            } else {
                resolvedLabel = "Button"
            }
            controls.append(InteractiveControl(index: idx, summary: resolvedLabel, trigger: { _ in action() }))
            return ["\(prefix)[(\(idx)) \(resolvedLabel) ]"]
        case .toggle(let label, let isOn, let onToggle, _):
            let idx = controls.count + 1
            controls.append(InteractiveControl(index: idx, summary: label, trigger: { _ in onToggle(!isOn) }))
            let box = isOn ? "☑" : "☐"
            return ["\(prefix)(\(idx)) \(box) \(label)"]
        case .textField(let placeholder, let text, let onTextChange, _):
            let idx = controls.count + 1
            controls.append(InteractiveControl(index: idx, summary: placeholder, trigger: { arg in
                if let arg = arg {
                    onTextChange(arg)
                }
            }))
            let shown = text.isEmpty ? placeholder : text
            return ["\(prefix)(\(idx)) ✎ [ \(shown) ___ ]"]
        case .slider(let value, let range, _, let onValueChange, _):
            let idx = controls.count + 1
            controls.append(InteractiveControl(index: idx, summary: "Slider", trigger: { arg in
                if let arg = arg, let v = Double(arg) {
                    let clamped = min(range.upperBound, max(range.lowerBound, v))
                    onValueChange(clamped)
                } else {
                    let next = min(range.upperBound, value + 1.0)
                    onValueChange(next)
                }
            }))
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let ratio = min(1.0, max(0.0, (value - range.lowerBound) / span))
            let filled = Int(ratio * 12.0)
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: 12 - filled)
            return ["\(prefix)(\(idx)) ◄\(bar)► \(String(format: "%.1f", value))"]
        case .progressBar(let fraction, let text, _):
            let filled = Int(min(1.0, max(0.0, fraction)) * 16.0)
            let bar = String(repeating: "▓", count: filled) + String(repeating: "░", count: 16 - filled)
            let suffix = text.map { " (\($0))" } ?? " (\(Int(fraction * 100))%)"
            return ["\(prefix)[\(bar)]\(suffix)"]
        case .divider(let vertical, _):
            return [vertical ? "\(prefix)│" : "\(prefix)──────────────────────────────────────"]
        case .spacer:
            return [""]
        case .image(let path, let altText, _):
            return ["\(prefix)[🖼 \(altText): \(path)]"]
        }
    }

    /// Generates a standalone E-Ink HTML preview document for a `RenderNode` hierarchy.
    public static func generateHTMLPreview(tree: RenderNode, config: KindleWindowConfig) -> String {
        let bodyHTML = renderHTMLNode(tree)
        let showTopBar = config.persistentChrome.contains(.topBar)
        let showSearch = config.persistentChrome.contains(.searchBar)

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8" />
        <title>\(config.awesomeWindowTitle)</title>
        <style>
          body {
            background: #252525;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 24px;
            font-family: "Bookerly", Georgia, serif;
            color: #111;
          }
          .kindle-bezel {
            background: #1a1a1a;
            padding: 28px 24px 48px 24px;
            border-radius: 22px;
            box-shadow: 0 16px 40px rgba(0,0,0,0.65);
          }
          .eink-screen {
            width: \(config.width)px;
            min-height: \(config.height)px;
            background: #f4f4f0;
            border: 2px solid #000;
            display: flex;
            flex-direction: column;
            box-sizing: border-box;
          }
          .chrome-top {
            border-bottom: 2px solid #000;
            padding: 6px 12px;
            font-family: sans-serif;
            font-size: 13px;
            font-weight: bold;
            display: flex;
            justify-content: space-between;
            background: #eee;
          }
          .chrome-search {
            border-bottom: 1px solid #000;
            padding: 6px 12px;
            font-family: sans-serif;
            font-size: 13px;
            background: #f9f9f9;
          }
          .content {
            padding: 12px;
            flex: 1;
            display: flex;
            flex-direction: column;
            gap: 8px;
          }
          .k-card {
            border: 2px solid #111;
            padding: 10px;
            background: #fafaf7;
          }
          .k-card-title {
            font-weight: bold;
            font-family: sans-serif;
            margin-bottom: 6px;
            border-bottom: 1px solid #444;
            padding-bottom: 4px;
          }
          .k-btn {
            border: 2px solid #000;
            background: #fff;
            color: #000;
            padding: 8px 14px;
            font-weight: bold;
            font-family: sans-serif;
            cursor: pointer;
            box-shadow: 2px 2px 0 #000;
          }
          .k-btn:active {
            background: #000;
            color: #fff;
          }
          .awesome-meta {
            color: #bbb;
            font-family: monospace;
            font-size: 12px;
            margin-bottom: 10px;
          }
        </style>
        </head>
        <body>
          <div class="awesome-meta">AwesomeWM Title: <strong>\(config.awesomeWindowTitle)</strong></div>
          <div class="kindle-bezel">
            <div class="eink-screen">
              \(showTopBar ? "<div class='chrome-top'><span>⌂ Kindle</span><span>\(config.applicationID)</span><span>87% 🔋</span></div>" : "")
              \(showSearch ? "<div class='chrome-search'>🔍 Search Kindle</div>" : "")
              <div class="content">
                \(bodyHTML)
              </div>
            </div>
          </div>
        </body>
        </html>
        """
    }

    private static func renderHTMLNode(_ node: RenderNode) -> String {
        switch node {
        case .empty:
            return ""
        case .group(let children):
            return children.map(renderHTMLNode).joined(separator: "\n")
        case .vstack(_, let spacing, let children, _):
            let inner = children.map(renderHTMLNode).joined(separator: "\n")
            return "<div style='display:flex;flex-direction:column;gap:\(spacing)px;'>\(inner)</div>"
        case .hstack(_, let spacing, let children, _):
            let inner = children.map(renderHTMLNode).joined(separator: "\n")
            return "<div style='display:flex;flex-direction:row;align-items:center;gap:\(spacing)px;'>\(inner)</div>"
        case .zstack(_, let children, _):
            let inner = children.map(renderHTMLNode).joined(separator: "\n")
            return "<div style='position:relative;'>\(inner)</div>"
        case .scrollView(_, let child, _):
            return "<div style='overflow-y:auto;'>\(renderHTMLNode(child))</div>"
        case .card(let title, let child, _):
            let titleHTML = title.map { "<div class='k-card-title'>\($0)</div>" } ?? ""
            return "<div class='k-card'>\(titleHTML)\(renderHTMLNode(child))</div>"
        case .text(let content, _, _, let style):
            let weight = (style.font?.isBold ?? false) ? "bold" : "normal"
            let size = style.font?.sizePoints ?? 13
            return "<div style='font-weight:\(weight);font-size:\(size + 3)px;'>\(content)</div>"
        case .button(let label, _, _, _):
            return "<button class='k-btn'>\(label)</button>"
        case .toggle(let label, let isOn, _, _):
            return "<label style='display:flex;align-items:center;gap:6px;'><input type='checkbox' \(isOn ? "checked" : "") /> \(label)</label>"
        case .textField(let placeholder, let text, _, _):
            return "<input type='text' placeholder='\(placeholder)' value='\(text)' style='border:2px solid #000;padding:6px;background:#fff;' />"
        case .slider(let value, let range, let step, _, _):
            return "<input type='range' min='\(range.lowerBound)' max='\(range.upperBound)' step='\(step)' value='\(value)' />"
        case .progressBar(let fraction, let text, _):
            let pct = Int(min(1.0, max(0.0, fraction)) * 100)
            return "<div style='border:2px solid #000;height:20px;background:#eee;position:relative;'><div style='width:\(pct)%;height:100%;background:#222;'></div><span style='position:absolute;top:1px;left:8px;font-size:11px;color:#888;'>\(text ?? "\(pct)%")</span></div>"
        case .divider(let vertical, _):
            return vertical ? "<div style='width:2px;background:#000;'></div>" : "<hr style='border:0;border-top:2px solid #000;width:100%;' />"
        case .spacer:
            return "<div style='flex:1;'></div>"
        case .image(let path, let altText, _):
            return "<img src='\(path)' alt='\(altText)' />"
        }
    }
}
