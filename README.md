# `KindleUI` — Declarative SwiftUI-Style Framework for Amazon Kindle (ARMv7 Linux)

`KindleUI` is a declarative, SwiftUI-inspired UI framework for Amazon Kindle E-Ink devices (Paperwhite, Oasis, Basic, Scribe, and older soft-float models), backed by GTK+-2.0, Cairo, Pango, WebKitGTK, and LIPC (`Sources/KindleUI/CKindleGTK`), and cross-compiled from macOS/Linux using Docker and the [swift-embedded-linux/armhf-debian](https://github.com/swift-embedded-linux/armhf-debian) SDK.

---

## Example Applications (`Examples/`)

| Binary | Source Location | Application ID | Description |
| :--- | :--- | :--- | :--- |
| **`KindleWiki`** | `Examples/KindleWiki/` | `org.kindlemodding.kindlewiki` | **Wikipedia & Wiktionary E-Ink Reader**: Paginated article reader with floated lead infocards, inline figures & tables, live search, featured feed, separate **Bookmark (`Save`)** & **Offline Download (`Download`)** controls, reading history, and typography customization. |
| **`KindleShowcase`** | `Examples/KindleShowcase/` | `org.kindlemodding.KindleShowcase` | **Comprehensive `KindleUI` Showcase App**: 6-tab interactive showcase covering Controls & Overlays, Navigation & Lists, Freehand & Vector Canvas, Embedded WebKitGTK Browser, Declarative Charts & `@Query` Data, and Split-View Settings. |

---

## Using KindleUI in Your Own Package

```swift
dependencies: [
    .package(url: "https://github.com/<you>/KindleUI", from: "1.0.0")
],
targets: [
    .executableTarget(name: "MyApp", dependencies: [
        .product(name: "KindleUI", package: "KindleUI")
    ])
]
```

---

## Project Layout

```text
.
├── Package.swift                              # SwiftPM manifest (exports only the KindleUI library)
├── build.sh                                   # Docker cross-compilation pipeline (armhf + softfp, glibc >= 2.20)
├── test.sh                                    # Host unit tests + example build runner
├── Dockerfile                                 # Swift ARMv7 cross-compiler container definition
├── Sources/
│   └── KindleUI/                              # SwiftUI-style declarative framework organized by domain:
│       ├── CKindleGTK/                        # C runtime bridge for GTK+-2.0, Cairo, Pango, WebKitGTK, WebP & LIPC
│       ├── App/                               # App, Scene, WindowGroup, KindleWindowConfig
│       ├── Core/                              # View, ViewBuilder, RenderNode, RenderTreeDiff, Transaction
│       ├── State/                             # State, Binding, StateObject, ObservedObject, Environment, AppStorage, SwiftData (@Query)
│       ├── Styling/                           # EInkColor, KindleFont, KindleTheme, ControlStyles, KindleIconName
│       ├── Layout/                            # VStack, HStack, ZStack, Spacer, Divider, Grid, ScrollView, GeometryReader, Layout
│       ├── Views/                             # Text, Icon, Image, AsyncImage, Containers, List, ForEach, Table, ReaderViews, WebView
│       ├── Controls/                          # Button, Toggle, Slider, Stepper, ProgressView, TextField, TextEditor, Picker, DatePicker
│       ├── Navigation/                        # NavigationStack, NavigationSplitView, TabView, Presentation (.sheet, .alert, .popover)
│       ├── Modifiers/                         # ViewModifier, LayoutModifiers, SearchAndInputModifiers, Gestures
│       ├── Drawing/                           # Shape, Path, Gradients, Canvas, Charts
│       ├── Hardware/                          # KindleDevice, KindleEPD, KindleHTTP
│       ├── Rendering/                         # GTK2Renderer, GTKStyledWidgets, GTKSignalTarget
│       └── Previews/                          # KindlePreview, KindlePreviewServer, KindlePreviewHTMLRenderer, KindlePreviewStudioUI
├── Examples/                                  # Separate package (not part of the KindleUI library package)
│   ├── Package.swift                          # Depends on KindleUI via path: ".."
│   ├── KindleShowcase/                        # 6-tab KindleUI component & API showcase app
│   ├── KindleWiki/                            # Wikipedia & Wiktionary E-Ink reader app
│   └── Tests/KindleWikiTests/                 # KindleWiki unit tests
└── Tests/
    └── KindleUITests/                         # KindleUI unit tests
```

---

## Persistent App Data on Kindle

Each `KindleUI` application declares a unique `applicationID` (e.g., `org.kindlemodding.kindlewiki`) via `App.applicationID` / `WindowGroup(id:)`. All persistent files are automatically scoped per app under:

- **On Kindle**: `/mnt/us/appdata/<applicationID>/`
  - `storage.json` (`@AppStorage` preferences)
  - `models.json` (`@Query` / `ModelContainer` persistent models)
  - `images/` (`AsyncImageCache` cached images)
- **On macOS / Desktop Simulator**: `/tmp/kindleui-appdata/<applicationID>/`

---

## Build & Test Instructions

### 1. Local Build, Unit Tests & Live Browser Preview Studio (macOS / Linux)

```sh
# KindleUI library tests
swift test

# Example apps (separate package in Examples/)
cd Examples
swift test
swift run KindleWiki --preview
swift run KindleShowcase --preview
```

Passing `--preview` (with optional `--port <port>` and `--open`) starts `KindlePreviewServer` at `http://127.0.0.1:8080`, rendering the exact `GTK2Renderer` layout grid, Pango typography scaling, Cairo button/toggle/container styles, `KindleCanvas` pixel buffers, and live `KindleHTTP` / `AsyncImage` updates over Server-Sent Events.

### 2. Cross-Compile for Kindle (`armhf` and `softfp`)

Make sure Docker Desktop (or OrbStack / Docker Engine) is running, then execute:

```sh
./build.sh
```

`./build.sh` builds static-Swift-stdlib ARMv7 binaries with glibc `>= 2.20` compatibility shims for both ABIs in `dist/`:

- **Hard-Float (`armhf` — Kindle FW `>= 5.16.3`, `/lib/ld-linux-armhf.so.3`)**:
  - `dist/KindleWiki`
  - `dist/KindleShowcase`
- **Soft-Float (`softfp` — Kindle FW `< 5.16.3`, `/lib/ld-linux.so.3`)**:
  - `dist/KindleWiki-softfp`
  - `dist/KindleShowcase-softfp`

### 3. Deploy & Run on a Kindle or QEMU Emulator

#### Over SSH (Physical Kindle or Running QEMU Emulator)

```sh
# Copy the binary to /mnt/us/ on the Kindle
scp dist/KindleWiki root@<kindle-ip>:/mnt/us/KindleWiki
scp dist/KindleShowcase root@<kindle-ip>:/mnt/us/KindleShowcase

# Launch on the Kindle Xorg display
ssh root@<kindle-ip> "chmod +x /mnt/us/KindleWiki && DISPLAY=:0 /mnt/us/KindleWiki"
```

*(For the local QEMU emulator listening on port `4022`:)*

```sh
scp -P 4022 -i ~/Developer/eink-emulator/build/ssh/id_ed25519 dist/KindleWiki root@127.0.0.1:/mnt/us/KindleWiki
ssh -p 4022 -i ~/Developer/eink-emulator/build/ssh/id_ed25519 root@127.0.0.1 "DISPLAY=:0 /mnt/us/KindleWiki"
```
