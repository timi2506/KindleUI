# KindleUI

A SwiftUI-like declarative UI library for jailbroken Amazon Kindles.

KindleUI renders native GTK 2 / Cairo views on the Kindle's X11 display and handles E-Ink refresh modes, LIPC system events, touch gestures, and on-screen keyboard input out of the box. It also includes a local browser preview server so you can build and test layouts on macOS or Linux without deploying to a device on every change.

## Usage

Add KindleUI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/timi2506/KindleUI.git", branch: "main")
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [.product(name: "KindleUI", package: "KindleUI")]
    )
]
```

Write views just like you would in SwiftUI:

```swift
import KindleUI

@main
struct CounterApp: App {
    var applicationID: String { "org.example.counter" }

    var body: some Scene {
        WindowGroup("Counter") {
            CounterView()
        }
    }
}

struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Count: \(count)")
                .font(.title)

            HStack(spacing: 12) {
                Button("Decrement") { count -= 1 }
                Button("Increment") { count += 1 }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}
```

## Local Preview

Pass `--preview` when running an app on macOS or Linux to start the local preview server on `http://127.0.0.1:8080`:

```sh
cd Examples
swift run KindleShowcase --preview
swift run KindleWiki --preview
```

You can also pass `--port <port>` or `--open` to open the browser automatically.

## Building for Kindle

Requires Docker. The build script cross-compiles static-Swift ARMv7 binaries for both `armhf` (firmware 5.16.3+) and `softfp` (older firmware):

```sh
./build.sh                          # build all apps in Examples/
./build.sh KindleWiki               # build a specific target
./build.sh -p path/to/pkg MyApp     # build an external package
```

Compiled binaries are written to `dist/<App>` (`armhf`) and `dist/<App>-softfp` (`softfp`).

To run on a Kindle over SSH:

```sh
scp dist/KindleWiki root@<kindle-ip>:/mnt/us/KindleWiki
ssh root@<kindle-ip> "chmod +x /mnt/us/KindleWiki && DISPLAY=:0 /mnt/us/KindleWiki"
```

## Examples

The [`Examples/`](Examples) directory contains two sample apps in a standalone Swift package:

- **KindleShowcase** (`Examples/KindleShowcase`): Demo of the available controls, layouts, navigation containers, canvas drawing, charts, and embedded WebKit view.
- **KindleWiki** (`Examples/KindleWiki`): Wikipedia and Wiktionary reader with article search, table of contents, bookmarks, offline storage, and reading settings.

## App Data

Persistent storage (`@AppStorage`, `@Query` models, and cached images) is scoped by `applicationID`:

- **Kindle**: `/mnt/us/appdata/<applicationID>/`
- **macOS / Linux host**: `/tmp/kindleui-appdata/<applicationID>/`

## Tests

```sh
./test.sh
```
