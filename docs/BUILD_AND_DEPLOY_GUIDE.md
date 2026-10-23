# Building & Running a `KindleUI` App on a Real Kindle (From Scratch)

This guide walks you through every step required to go from a fresh machine (macOS Apple Silicon/Intel, Linux, or Windows WSL2) to running your own `KindleUI` application natively on a physical Kindle.

---

## Table of Contents

1. [Step 1: Prepare Your Physical Kindle](#step-1-prepare-your-physical-kindle)
2. [Step 2: Identify Your Kindle Target (`kindlehf` vs. `kindlepw2`)](#step-2-identify-your-kindle-target-kindlehf-vs-kindlepw2)
3. [Step 3: Set Up the Build Environment & Cross-Toolchain](#step-3-set-up-the-build-environment--cross-toolchain)
   - [Option A: macOS (Apple Silicon M1/M2/M3/M4) via OrbStack / Lima (Recommended)](#option-a-macos-apple-silicon-m1m2m3m4-via-orbstack--lima-recommended)
   - [Option B: Native Ubuntu / Debian / Arch Linux / WSL2](#option-b-native-ubuntu--debian--arch-linux--wsl2)
4. [Step 4: Build `koxtoolchain` and `kindle-sdk`](#step-4-build-koxtoolchain-and-kindle-sdk)
5. [Step 5: Create & Preview Your `KindleUI` App](#step-5-create--preview-your-kindleui-app)
6. [Step 6: Cross-Compile for Your Kindle](#step-6-cross-compile-for-your-kindle)
7. [Step 7: Package & Deploy to Your Kindle](#step-7-package--deploy-to-your-kindle)
   - [Method 1: Deploy via USB Mass Storage (KUAL or Home Library Scriptlet)](#method-1-deploy-via-usb-mass-storage-kual-or-home-library-scriptlet)
   - [Method 2: Deploy & Live-Debug over Wi-Fi / USBNet SSH](#method-2-deploy--live-debug-over-wi-fi--usbnet-ssh)
8. [Step 8: Understanding Kindle Screen Resolutions & AwesomeWM Rules](#step-8-understanding-kindle-screen-resolutions--awesomewm-rules)
9. [Troubleshooting](#troubleshooting)

---

## Step 1: Prepare Your Physical Kindle

To run custom native GTK+-2.0 binaries on a Kindle, your device must have:

1. **Jailbreak installed**: Follow the [KindleModding Jailbreak Guide](https://kindlemodding.org/jailbreaking/index.html) (e.g., *WinterBreak* for modern firmware).
2. **Hotfix installed**: Ensures your jailbreak survives firmware updates.
3. **KUAL (Kindle Unified Application Launcher) & MRPI**: Installed in your Kindle library so you can launch extensions from `/mnt/us/extensions/` or scriptlets from `/mnt/us/documents/`.
4. *(Optional but recommended)* **USBNetwork (`usbnet`)**: Allows you to SSH into your Kindle over USB (`192.168.15.244`) or Wi-Fi to run binaries directly and see `stdout` / `stderr` logs in real time.

---

## Step 2: Identify Your Kindle Target (`kindlehf` vs. `kindlepw2`)

On your Kindle, go to **Settings → Device Options → Device Info** and check your **Firmware Version**:

| Target Name | Firmware Version | Supported Devices | Compiler Triple |
| :--- | :--- | :--- | :--- |
| **`kindlehf`** | **Firmware >= 5.16.3** | All Kindles running FW 5.16.3 or newer (hard-float ABI) | `arm-kindlehf-linux-gnueabihf` |
| **`kindlepw2`** | **Firmware < 5.16.3** | Kindle Paperwhite 2 (PW2) and newer on FW < 5.16.3 (soft-float ABI) | `arm-kindlepw2-linux-gnueabi` |

> **Note:** Always use the target that matches your Kindle's firmware ABI. Mixing `kindlehf` and `kindlepw2` binaries will result in `"No such file or directory"` (missing dynamic linker `/lib/ld-linux-armhf.so.3` vs `/lib/ld-linux.so.3`) when launching on the Kindle.

---

## Step 3: Set Up the Build Environment & Cross-Toolchain

### How `KindleUI` Builds for Kindle

`KindleUI` uses a 2-stage pipeline:
1. **Stage 1 (Swift Host Evaluation)**: Runs your Swift `@main` app with `--emit-meson` to evaluate your `@ViewBuilder` hierarchy and emit a self-contained **C++17 + GTK+-2.0 Meson project** (`.kindle-build/meson_src`).
2. **Stage 2 (Meson + `koxtoolchain` Cross-Compilation)**: Compiles the generated C++17 GTK+-2.0 code against `kindle-sdk` using `meson` and `arm-kindlehf-linux-gnueabihf-g++` (with `-static-libstdc++` so it runs on the Kindle's older system `libstdc++`).

### Option A: macOS (Apple Silicon M1/M2/M3/M4) via OrbStack / Lima (Recommended)

Because `koxtoolchain` and `crosstool-ng` target Linux (and require a case-sensitive filesystem + GNU build tools), the cleanest workflow on Apple Silicon macOS is:
- Run **Swift** (`swift build` / `kindle-swift`) natively on macOS (or inside Linux), and
- Run the **`koxtoolchain` + `kindle-sdk` Meson cross-compiler** inside a lightweight Ubuntu Linux VM that shares your macOS filesystem automatically.

1. **Install OrbStack (or Lima) on macOS**:
   ```bash
   brew install --cask orbstack
   ```
2. **Create an Ubuntu 24.04 container/machine in OrbStack**:
   ```bash
   orb create ubuntu:24.04 kindle-builder
   orb -m kindle-builder
   ```
   *(OrbStack automatically mounts your Mac's `/Users/<you>` directory at the exact same path `/Users/<you>` inside Ubuntu!)*

3. **Inside the Ubuntu shell, install the required packages**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y \
     build-essential autoconf automake bison flex gawk libtool libtool-bin \
     libncurses-dev curl file git gperf help2man texinfo unzip wget \
     sed libarchive-dev nettle-dev meson ninja-build pkg-config \
     gtk2.0 libgtk2.0-dev
   ```

### Option B: Native Ubuntu / Debian / Arch Linux / WSL2

- **Debian / Ubuntu / WSL2**:
  ```bash
  sudo apt-get update
  sudo apt-get install -y \
    build-essential autoconf automake bison flex gawk libtool libtool-bin \
    libncurses-dev curl file git gperf help2man texinfo unzip wget \
    sed libarchive-dev nettle-dev meson ninja-build pkg-config \
    gtk2.0 libgtk2.0-dev
  ```
- **Arch Linux**:
  ```bash
  sudo pacman -S base-devel curl git gperf help2man unzip wget sed libarchive nettle meson gtk2
  ```

---

## Step 4: Build `koxtoolchain` and `kindle-sdk`

Run these commands inside your Linux environment (or OrbStack Ubuntu shell). Replace `kindlehf` with `kindlepw2` if your Kindle firmware is older than `5.16.3`.

### 1. Build `koxtoolchain` (installs to `~/x-tools`)

```bash
cd ~
git clone --recursive --depth=1 https://github.com/koreader/koxtoolchain.git
cd koxtoolchain
chmod +x ./gen-tc.sh
./gen-tc.sh kindlehf
```

> **Tip:** Compiling the cross-toolchain takes ~20–30 minutes. When complete, your compiler will be located at `~/x-tools/arm-kindlehf-linux-gnueabihf/`.

### 2. Install `kindle-sdk` (adds Kindle GTK2/LIPC headers & `meson-crosscompile.txt`)

```bash
cd ~
git clone --recursive --depth=1 https://github.com/KindleModding/kindle-sdk.git
cd kindle-sdk
chmod +x ./gen-sdk.sh
./gen-sdk.sh kindlehf
```

When `./gen-sdk.sh` finishes, verify that the Meson cross-file exists:

```bash
ls -l ~/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt
```

---

## Step 5: Create & Preview Your `KindleUI` App

From the `KindleUI` repository root on your Mac (or Linux):

### 1. Build the `KindleUI` Framework & `kindle-swift` CLI

```bash
swift build
```

Verify your environment status with:

```bash
swift run kindle-swift doctor
```

### 2. Initialize a New App (or Use `HelloWorld`)

```bash
swift run kindle-swift init MyKindleApp --id org.kindlemodding.mykindleapp
```

This creates `./MyKindleApp`:
```text
MyKindleApp/
├── Package.swift
├── Sources/
│   └── MyKindleApp/
│       └── MyKindleAppApp.swift
└── kual/
    └── MyKindleApp/
        ├── config.xml
        └── menu.json
```

### 3. Test & Preview Locally Before Cross-Compiling

- **Interactive Terminal Simulator**:
  ```bash
  cd MyKindleApp
  swift run MyKindleApp --sim
  ```
- **Standalone E-Ink HTML Preview**:
  ```bash
  swift run MyKindleApp --export-html preview.html
  open preview.html
  ```
- **Single-Frame Terminal Snapshot**:
  ```bash
  swift run MyKindleApp --snapshot
  ```

---

## Step 6: Cross-Compile for Your Kindle

### Workflow A: Single-Machine Build (Linux, or macOS with Toolchain at `~/x-tools`)

From the `KindleUI` repository root:

```bash
swift run kindle-swift build --project ./HelloWorld --target kindlehf
```

This automatically:
1. Evaluates `HelloWorld` and emits `.kindle-build/meson_src/` (`meson.build`, `meson.options`, `src/include/kindle_ui.hpp`, `src/main.cpp`).
2. Runs `meson setup --cross-file ~/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt`.
3. Runs `meson compile` to produce the ARM binary at `HelloWorld/.kindle-build/builddir_kindlehf/HelloWorld`.

### Workflow B: Split macOS + OrbStack Linux Build

If Swift is installed on macOS and `koxtoolchain` + `kindle-sdk` are installed inside your OrbStack Ubuntu VM:

1. **On macOS**, emit the C++17 + GTK+-2.0 Meson project:
   ```bash
   swift run kindle-swift build --project ./HelloWorld --target kindlehf --emit-only
   ```
   This writes the ready-to-compile Meson project to `HelloWorld/.kindle-build/meson_src`.

2. **Inside your OrbStack Ubuntu shell** (or via `orb -m kindle-builder <cmd>` directly from your Mac terminal!), run Meson to cross-compile the ARM binary:
   ```bash
   orb -m kindle-builder meson setup \
     --cross-file ~/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt \
     HelloWorld/.kindle-build/builddir_kindlehf \
     HelloWorld/.kindle-build/meson_src

   orb -m kindle-builder meson compile -C HelloWorld/.kindle-build/builddir_kindlehf
   ```

3. Verify the resulting binary is a 32-bit ARM ELF executable for Kindle:
   ```bash
   file HelloWorld/.kindle-build/builddir_kindlehf/HelloWorld
   # Expected output:
   # ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3 ...
   ```

---

## Step 7: Package & Deploy to Your Kindle

Once `HelloWorld/.kindle-build/builddir_kindlehf/HelloWorld` is built, package it into a **KUAL Extension** and **Kindle Home Library Scriptlet**:

```bash
swift run kindle-swift package --project ./HelloWorld --target kindlehf
```

This generates `./HelloWorld/dist/`:
```text
HelloWorld/dist/
├── documents/
│   └── HelloWorld.sh                 # Kindle Home Library Scriptlet
└── extensions/
    └── HelloWorld/
        ├── bin/
        │   └── HelloWorld            # Cross-compiled ARM Kindle binary
        ├── config.xml                # KUAL Extension Metadata
        └── menu.json                 # KUAL Menu Entry
```

### Method 1: Deploy via USB Mass Storage (KUAL or Home Library Scriptlet)

1. Plug your Kindle into your Mac via USB (on macOS with modern MTP Kindles, use *OpenMTP* or *Android File Transfer*, or USB Mass Storage on older Kindles).
2. **To launch via KUAL**:
   - Copy `HelloWorld/dist/extensions/HelloWorld` into the `extensions/` folder on your Kindle (`/mnt/us/extensions/HelloWorld`).
   - Eject your Kindle, open **KUAL** from your library, and tap **HelloWorld → Launch HelloWorld**.
3. **To launch directly from your Kindle Home Library (Scriptlet)**:
   - Copy `HelloWorld/dist/documents/HelloWorld.sh` into the `documents/` folder on your Kindle (`/mnt/us/documents/HelloWorld.sh`).
   - Eject your Kindle; a new item named **HelloWorld** will appear directly in your Kindle's book library. Tap it to launch!

### Method 2: Deploy & Live-Debug over Wi-Fi / USBNet SSH

If you have **USBNetwork** enabled on your Kindle:

1. Copy the extension folder over `scp`:
   ```bash
   scp -r HelloWorld/dist/extensions/HelloWorld root@192.168.15.244:/mnt/us/extensions/
   ```
2. SSH into the Kindle, set `DISPLAY=:0`, make the binary executable, and run it directly:
   ```bash
   ssh root@192.168.15.244
   chmod +x /mnt/us/extensions/HelloWorld/bin/HelloWorld
   DISPLAY=:0 /mnt/us/extensions/HelloWorld/bin/HelloWorld
   ```
   Running with `DISPLAY=:0` over SSH prints any GTK warnings or application logs directly to your terminal while displaying the UI on the Kindle's E-Ink screen.

---

## Step 8: Understanding Kindle Screen Resolutions & AwesomeWM Rules

1. **Awesome Window Manager Title Format**:
   The Kindle's window manager (`awesome`) uses the X11/GTK window title to decide how to display your window (`L:A_N:application_PC:T_ID:org.kindlemodding.helloworld`).
   - **Never use raw underscores (`_`) inside your `applicationID`**, because AwesomeWM splits key-value pairs on `_`. (`KindleWindowConfig` automatically sanitizes `_` to `-` for you.)
   - Use `chrome: .topBar` (`PC:T`) or `.topAndSearch` (`PC:TS`) if you want the Kindle's native top status bar (with the **Home** button to exit your app) to stay visible.
   - If you use `chrome: .none` (`PC:N`, full-screen), make sure your UI includes a **Quit / Exit** button that calls `gtk_main_quit()` so the user isn't trapped in full-screen mode!

2. **Matching Your Kindle's Native Resolution**:
   In `WindowGroup(id: ..., width: ..., height: ...)`, you can match your target device's pixel dimensions:
   - **Classic 6" (167/212 PPI)**: `600 × 800` or `758 × 1024`
   - **300 PPI 6" (Paperwhite 3/4, Voyage, Oasis 1)**: `1072 × 1448`
   - **300 PPI 6.8" / 7" (Paperwhite 5, Oasis 2/3)**: `1236 × 1648` or `1264 × 1680`
   - **300 PPI 10.2" (Kindle Scribe)**: `1860 × 2480`

---

## Troubleshooting

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `-sh: ./HelloWorld: not found` when running on Kindle | Binary was compiled for the wrong ABI (`kindlehf` vs `kindlepw2`) or for host macOS/x86_64 instead of ARM | Check `file ./HelloWorld`. Ensure it says `ELF 32-bit LSB executable, ARM` and matches your Kindle's firmware (`kindlehf` for FW >= 5.16.3, `kindlepw2` for FW < 5.16.3). |
| Window opens on Kindle, then immediately disappears or stays invisible | Invalid AwesomeWM window title (e.g., missing `L:A_N:application_ID:...` or extra `_` in the app ID) | Check your title with `swift run kindle-swift title --id org.kindlemodding.myapp`. |
| `Permission denied` when launching from KUAL | FAT32 `/mnt/us` mount or missing `+x` permission | KUAL runs commands via `/bin/sh`. Ensure `menu.json` `action` points to `./bin/<AppName>`. |
| `version 'GLIBCXX_3.4.xx' not found` on Kindle | Dynamic `libstdc++` linked against newer GCC in `koxtoolchain` | `KindleUI`'s `MesonCPPGenerator` automatically passes `-static-libstdc++` in `cpp_args` and `link_args` to prevent this. |
