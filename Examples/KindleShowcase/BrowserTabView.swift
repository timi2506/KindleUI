import Foundation
import KindleUI

// MARK: - Tab 4: Embedded WebKit Browser

extension KindleShowcaseRootView {
    internal func browserTab(theme: KindleTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Button("←") {
                        browserWeb.goBack()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("→") {
                        browserWeb.goForward()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("↻") {
                        browserWeb.reload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    TextField("https://…", text: $browserURL) {
                        navigateBrowser(to: browserURL)
                    }
                    .keyboardType(.URL)
                    .submitLabel(.go)

                    Button("Go") {
                        navigateBrowser(to: browserURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                HStack(alignment: .center, spacing: 8) {
                    ForEach(browserPresets) { preset in
                        Button(preset.title) {
                            if preset.id == "welcome" {
                                loadWelcomeHTML()
                            } else {
                                browserURL = preset.url
                                navigateBrowser(to: preset.url)
                            }
                        }
                        .buttonStyle(browserURL == preset.url ? .borderedProminent : .capsule)
                        .controlSize(.mini)
                    }

                    Spacer()

                    Button("A−") {
                        browserWeb.zoomLevel = max(0.6, browserWeb.zoomLevel - 0.15)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Text("\(Int(browserWeb.zoomLevel * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(theme.mutedForeground)

                    Button("A+") {
                        browserWeb.zoomLevel = min(2.2, browserWeb.zoomLevel + 0.15)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
            .background(theme.cardBackground, in: .rect(cornerRadius: 16))
            .overlay(theme.subtleBorder, in: .rect(cornerRadius: 16), lineWidth: 1)

            WebView(
                controller: browserWeb,
                minHeight: 420,
                onLoadFinished: {
                    let loaded = browserWeb.currentURL
                    if !loaded.isEmpty && !loaded.contains("127.0.0.1") && !loaded.contains("__local_doc_") {
                        browserURL = loaded
                    }
                }
            )
            .expand(true, fill: true)
        }
        .expand(true, fill: true)
    }

    internal func navigateBrowser(to raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed == "https://kindle.local/welcome" {
            loadWelcomeHTML()
            return
        }
        let normalized: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("about:") {
            normalized = trimmed
        } else {
            normalized = "https://" + trimmed
        }
        browserURL = normalized
        browserWeb.load(url: normalized)
    }

    internal func loadWelcomeHTML() {
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Reader Start Page</title>
          <style>
            body {
              font-family: Georgia, serif;
              background: #ffffff;
              color: #111111;
              margin: 36px 40px;
              line-height: 1.65;
            }
            h1 { font-size: 28px; margin: 0 0 12px 0; border-bottom: 1px solid #333; padding-bottom: 10px; }
            blockquote {
              font-size: 19px;
              font-style: italic;
              margin: 20px 0;
              padding-left: 18px;
              border-left: 3px solid #222;
            }
            .cite { font-size: 14px; color: #555; margin-top: 6px; font-style: normal; }
            p { font-size: 16px; color: #333; margin-top: 22px; }
          </style>
        </head>
        <body>
          <h1>Daily Reading</h1>
          <blockquote>
            “Nowhere either with more quiet or more freedom from trouble does a man retire than into his own soul.”
            <div class="cite">— Marcus Aurelius, Meditations IV.3</div>
          </blockquote>
          <p>Select a bookmark above or enter a web address to browse articles formatted for E-Ink.</p>
        </body>
        </html>
        """
        browserURL = "https://kindle.local/welcome"
        browserWeb.loadHTML(html, baseURL: "https://kindle.local/welcome")
    }
}
