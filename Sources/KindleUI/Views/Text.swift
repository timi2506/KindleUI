import Foundation

/// Formatting styles supported by `Text(_:format:)`.
public enum KindleTextFormat: Sendable, Equatable {
    case number
    case percent
    case currency(code: String)
    case byteCount
}

/// A view that displays one or more lines of read-only text on the Kindle E-Ink display (`gtk_label_new`),
/// supporting inline Markdown (`**bold**`, `*italic*`, `` `code` ``, `~~strikethrough~~`) and `Text + Text` concatenation.
public struct Text: View, _PrimitiveView {
    public typealias Body = Never

    public enum DateStyle: Sendable, Equatable {
        case date
        case time
        case relative
        case timer
        case offset
    }

    internal struct Span: Sendable, Equatable {
        var rawText: String
        var parseMarkdown: Bool
        var isBold: Bool = false
        var isItalic: Bool = false
        var isMonospaced: Bool = false
        var isUnderline: Bool = false
        var isStrikethrough: Bool = false
        var foregroundColor: EInkColor? = nil
        var font: KindleFont? = nil
    }

    internal var spans: [Span]
    private var wrap: Bool = false
    private var textAlignment: HorizontalAlignment = .leading
    private var style: ViewStyle = ViewStyle()

    public var content: String {
        spans.map { span in
            span.parseMarkdown ? Self.stripInlineMarkdown(span.rawText) : span.rawText
        }.joined()
    }

    private static func containsMarkdownDelimiter(_ s: String) -> Bool {
        for b in s.utf8 {
            if b == 0x2A || b == 0x7E || b == 0x60 { return true }
        }
        return false
    }

    public init(_ content: String) {
        self.spans = [Span(rawText: content, parseMarkdown: Self.containsMarkdownDelimiter(content))]
    }

    public init(verbatim content: String) {
        self.spans = [Span(rawText: content, parseMarkdown: false)]
    }

    public init(_ value: Double, format: KindleTextFormat) {
        let formatted: String
        switch format {
        case .number:
            if value.rounded() == value {
                formatted = String(format: "%.0f", value)
            } else {
                formatted = String(format: "%.2f", value)
            }
        case .percent:
            let pct = abs(value) <= 1.0 && value != 0.0 ? value * 100.0 : value
            formatted = String(format: "%.0f%%", pct)
        case .currency(let code):
            let sym: String
            switch code.uppercased() {
            case "USD": sym = "$"
            case "EUR": sym = "€"
            case "GBP": sym = "£"
            default: sym = "\(code.uppercased()) "
            }
            formatted = String(format: "%@%.2f", sym, value)
        case .byteCount:
            let bytes = max(0.0, value)
            if bytes >= 1_048_576 {
                formatted = String(format: "%.1f MB", bytes / 1_048_576.0)
            } else if bytes >= 1024 {
                formatted = String(format: "%.1f KB", bytes / 1024.0)
            } else {
                formatted = String(format: "%.0f B", bytes)
            }
        }
        self.spans = [Span(rawText: formatted, parseMarkdown: false)]
    }

    public init(_ value: Int, format: KindleTextFormat) {
        self.init(Double(value), format: format)
    }

    public init(_ date: Date, style dateStyle: DateStyle = .date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let str: String
        switch dateStyle {
        case .date:
            formatter.dateFormat = "MMM d, yyyy"
            str = formatter.string(from: date)
        case .time:
            formatter.dateFormat = "HH:mm:ss"
            str = formatter.string(from: date)
        case .relative, .offset:
            let diff = Int(Date().timeIntervalSince(date))
            if abs(diff) < 60 {
                str = "\(abs(diff))s \(diff >= 0 ? "ago" : "from now")"
            } else if abs(diff) < 3600 {
                str = "\(abs(diff) / 60)m \(diff >= 0 ? "ago" : "from now")"
            } else {
                str = "\(abs(diff) / 3600)h \(diff >= 0 ? "ago" : "from now")"
            }
        case .timer:
            let secs = max(0, Int( abs(Date().timeIntervalSince(date)) ))
            let m = secs / 60
            let s = secs % 60
            str = String(format: "%02d:%02d", m, s)
        }
        self.spans = [Span(rawText: str, parseMarkdown: false)]
    }

    private init(spans: [Span], wrap: Bool, textAlignment: HorizontalAlignment, style: ViewStyle) {
        self.spans = spans
        self.wrap = wrap
        self.textAlignment = textAlignment
        self.style = style
    }

    public static func + (lhs: Text, rhs: Text) -> Text {
        Text(
            spans: lhs.spans + rhs.spans,
            wrap: lhs.wrap || rhs.wrap,
            textAlignment: lhs.textAlignment,
            style: lhs.style
        )
    }

    public func bold(_ isActive: Bool = true) -> Text {
        var copy = self
        for i in copy.spans.indices {
            copy.spans[i].isBold = isActive
        }
        var f = copy.style.font ?? .body
        f.isBold = isActive
        copy.style.font = f
        return copy
    }

    public func italic(_ isActive: Bool = true) -> Text {
        var copy = self
        for i in copy.spans.indices {
            copy.spans[i].isItalic = isActive
        }
        var f = copy.style.font ?? .body
        f.isItalic = isActive
        copy.style.font = f
        return copy
    }

    public func monospaced(_ isActive: Bool = true) -> Text {
        var copy = self
        for i in copy.spans.indices {
            copy.spans[i].isMonospaced = isActive
        }
        if isActive {
            var f = copy.style.font ?? .monospaced
            f.family = "Monospace"
            copy.style.font = f
        }
        return copy
    }

    public func underline(_ isActive: Bool = true) -> Text {
        var copy = self
        for i in copy.spans.indices {
            copy.spans[i].isUnderline = isActive
        }
        return copy
    }

    public func strikethrough(_ isActive: Bool = true) -> Text {
        var copy = self
        for i in copy.spans.indices {
            copy.spans[i].isStrikethrough = isActive
        }
        return copy
    }

    public func foregroundColor(_ color: EInkColor) -> Text {
        var copy = self
        for i in copy.spans.indices where copy.spans[i].foregroundColor == nil {
            copy.spans[i].foregroundColor = color
        }
        copy.style.foregroundColor = color
        return copy
    }

    public func foregroundStyle(_ color: EInkColor) -> Text {
        foregroundColor(color)
    }

    public func fontWeight(_ weight: KindleFont.Weight) -> Text {
        bold(weight.isBold)
    }

    public func font(_ font: KindleFont) -> Text {
        var copy = self
        for i in copy.spans.indices where copy.spans[i].font == nil {
            copy.spans[i].font = font
        }
        copy.style.font = font
        return copy
    }

    public func multilineTextAlignment(_ alignment: HorizontalAlignment) -> Text {
        var copy = self
        copy.textAlignment = alignment
        return copy
    }

    public func lineWrap(_ enabled: Bool) -> Text {
        var copy = self
        copy.wrap = enabled
        return copy
    }

    public func lineLimit(_ limit: Int?) -> Text {
        var copy = self
        if let limit = limit {
            copy.wrap = limit > 1
        } else {
            copy.wrap = true
        }
        return copy
    }

    public func _makeNode() -> RenderNode {
        var nodeStyle = style
        let reasons = KindleStateRegistry.shared.currentEnvironment.redactionReasons
        if reasons.contains(.placeholder) {
            let theme = KindleTheme.current
            let charCount = max(4, min(28, content.count))
            let blocks = String(repeating: "█", count: charCount)
            nodeStyle.foregroundColor = theme.subtleBorder
            nodeStyle.pangoMarkup = nil
            return .text(content: blocks, wrap: false, alignment: textAlignment, style: nodeStyle)
        } else if reasons.contains(.privacy) {
            let charCount = max(4, min(20, content.count))
            let masked = String(repeating: "•", count: charCount)
            nodeStyle.pangoMarkup = nil
            return .text(content: masked, wrap: false, alignment: textAlignment, style: nodeStyle)
        }
        if Self.needsPangoMarkup(spans: spans) {
            nodeStyle.pangoMarkup = Self.buildPangoMarkup(from: spans)
        }
        return .text(content: content, wrap: wrap, alignment: textAlignment, style: nodeStyle)
    }

    // MARK: - Inline Markdown & Pango Markup Conversion

    private static func needsPangoMarkup(spans: [Span]) -> Bool {
        if spans.count > 1 { return true }
        guard let first = spans.first else { return false }
        if first.isUnderline || first.isStrikethrough || first.isMonospaced {
            return true
        }
        if first.parseMarkdown {
            let s = first.rawText
            if s.contains("**") || s.contains("~~") || s.contains("`") || s.contains("*") {
                return true
            }
        }
        return false
    }

    internal static func escapeXML(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&apos;")
            default: out.append(ch)
            }
        }
        return out
    }

    internal static func stripInlineMarkdown(_ input: String) -> String {
        var s = input
        s = replacePairedDelimiter(in: s, delimiter: "**", openTag: "", closeTag: "")
        s = replacePairedDelimiter(in: s, delimiter: "~~", openTag: "", closeTag: "")
        s = replacePairedDelimiter(in: s, delimiter: "`", openTag: "", closeTag: "")
        s = replacePairedDelimiter(in: s, delimiter: "*", openTag: "", closeTag: "")
        return s
    }

    internal static func markdownToPango(_ input: String) -> String {
        var s = escapeXML(input)
        s = replacePairedDelimiter(in: s, delimiter: "**", openTag: "<b>", closeTag: "</b>")
        s = replacePairedDelimiter(in: s, delimiter: "~~", openTag: "<s>", closeTag: "</s>")
        s = replacePairedDelimiter(in: s, delimiter: "`", openTag: "<tt>", closeTag: "</tt>")
        s = replacePairedDelimiter(in: s, delimiter: "*", openTag: "<i>", closeTag: "</i>")
        return s
    }

    private static func replacePairedDelimiter(
        in input: String,
        delimiter: String,
        openTag: String,
        closeTag: String
    ) -> String {
        guard input.contains(delimiter) else { return input }
        let parts = input.components(separatedBy: delimiter)
        guard parts.count >= 3 else { return input }
        var result = ""
        var i = 0
        while i < parts.count {
            if i + 2 < parts.count && !parts[i + 1].isEmpty {
                result.append(parts[i])
                result.append(openTag)
                result.append(parts[i + 1])
                result.append(closeTag)
                i += 2
                if i == parts.count - 1 {
                    result.append(parts[i])
                    break
                }
                // Continue from parts[i]
                let remaining = Array(parts[i...]).joined(separator: delimiter)
                result.append(replacePairedDelimiter(in: remaining, delimiter: delimiter, openTag: openTag, closeTag: closeTag))
                break
            } else {
                result.append(parts[i])
                if i < parts.count - 1 {
                    result.append(delimiter)
                }
                i += 1
            }
        }
        return result
    }

    internal static func buildPangoMarkup(from spans: [Span]) -> String {
        var out = ""
        let multiSpan = spans.count > 1
        for span in spans {
            var frag = span.parseMarkdown ? markdownToPango(span.rawText) : escapeXML(span.rawText)
            if span.isMonospaced {
                frag = "<tt>\(frag)</tt>"
            }
            if span.isUnderline {
                frag = "<u>\(frag)</u>"
            }
            if span.isStrikethrough {
                frag = "<s>\(frag)</s>"
            }
            if multiSpan {
                if span.isBold || (span.font?.isBold ?? false) {
                    frag = "<b>\(frag)</b>"
                }
                if span.isItalic || (span.font?.isItalic ?? false) {
                    frag = "<i>\(frag)</i>"
                }
                if let fg = span.foregroundColor {
                    frag = "<span foreground=\"\(fg.hexString)\">\(frag)</span>"
                }
            }
            out.append(frag)
        }
        return out
    }
}
