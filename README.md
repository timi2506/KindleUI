# KindleSwift (`KindleUI` & `kindle-swift` CLI)

A declarative, **SwiftUI-like framework (`KindleUI`)** and **command-line build system (`kindle-swift`)** for creating native Kindle applications targeting GTK+-2.0, the Kindle Awesome Window Manager, and Amazon's LIPC hardware bus.

---

## Architecture & Highlights

1. **`KindleUI` Declarative DSL**:
   - **`@main` & `App` / `Scene` (`WindowGroup`, `KindleDialogScene`)**: Familiar SwiftUI app lifecycle.
   - **`@ViewBuilder` & `View` Protocol**: Compose views declaratively with `VStack`, `HStack`, `ZStack`, `ScrollView`, `List`, `ForEach`, `KindleCard`, `Text`, `Button`, `Toggle`, `TextField`, `Slider`, `ProgressView`, `Image`, `Divider`, and `Spacer`.
   - **Reactive `@State` & `@Binding`**: Automatic UI reconciliation when state mutates.
   - **Kindle Awesome Window Manager Title Engine (`KindleWindowConfig`)**: Generates compliant `_`-delimited window titles (`L:A_N:application_PC:T_O:UD_ID:org.kindlemodding.app`, modal/dismissible dialogs with `RC` rounded corners, `RKB` keyboard avoidance, `PALMR` palm rejection, `BARTYPE`, and `HIDE`).
   - **16-Shade E-Ink Styling (`EInkColor`, `KindleFont`)**: Built-in support for Bookerly/Serif/Sans/Monospace Pango fonts and 16-level E-Ink grayscale shades.
   - **Kindle LIPC Hardware Bridge (`KindleDevice.shared`)**: Read/write Kindle frontlight brightness (`com.lab126.powerd` `flIntensity`), battery level (`battLevel`), and screensaver inhibition (`preventScreenSaver`).
2. **Multi-Backend Execution & Cross-Compilation**:
   - **Native GTK+-2.0 Runtime (`CKindleGTK` + `GTK2Renderer`)**: Dynamically binds to `libgtk-x11-2.0.so.0` and `liblipc.so` at runtime—no fragile system Clang modulemaps required to run `swift build`.
   - **Interactive Terminal & HTML E-Ink Simulator (`EInkSimulatorRenderer`)**: Test and interact with your Kindle app on Windows, macOS, or headless Linux even without X11/GTK2 installed.
   - **Meson + C++17 GTK+-2.0 Cross-Compiler Emitter (`MesonCPPGenerator`)**: Directly integrates with `koxtoolchain` + `kindle-sdk` (`meson.build` + `meson.options` with `-static-libstdc++`) for one-command cross-compilation to `kindlehf` (FW >= 5.16.3) and `kindlepw2` (FW < 5.16.3).

---

## Quick Start & Build Instructions

### 1. Build the Framework, CLI Tool, and Demo App
From the repository root (`kindledev`):

```bash
swift build
```

This compiles three targets:
- `KindleUI` (the declarative UI library)
- `kindle-swift` (the project generator, builder, simulator, and KUAL packager CLI)
- `KindleNotesDemo` (an example KindleUI app)

### 2. Run the Example App (`KindleNotesDemo`)
- **On Linux/WSL with GTK+-2.0 installed**: Opens a native GTK+-2.0 window with the Kindle AwesomeWM title (`L:A_N:application_PC:T_O:UD_ID:org.kindlemodding.kindlenotes`).
- **On Windows / macOS / Headless Terminal**: Automatically launches the interactive **Kindle E-Ink Terminal Simulator**:

```bash
swift run KindleNotesDemo
```

Or force the terminal simulator / export a standalone E-Ink HTML preview:

```bash
swift run KindleNotesDemo --sim
swift run KindleNotesDemo --export-html preview.html
```

### 3. Use the `kindle-swift` CLI Tool

```bash
# Check environment and Kindle toolchain status
swift run kindle-swift doctor

# Scaffold a brand new KindleUI Swift project
swift run kindle-swift init MyKindleReader --id org.kindlemodding.myreader

# Build & run the interactive E-Ink simulator for the demo or your project
swift run kindle-swift sim --product KindleNotesDemo --sim

# Cross-compile for Kindle (kindlehf or kindlepw2) via koxtoolchain + kindle-sdk Meson
swift run kindle-swift build --target kindlehf --cross-file ~/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt

# Package into a KUAL extension (/mnt/us/extensions/...) and Kindle Home Scriptlet (.sh)
swift run kindle-swift package --target kindlehf
```
