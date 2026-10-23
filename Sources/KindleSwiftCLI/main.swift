import Foundation
import KindleUI

struct CLIConfig {
    var command: String
    var positional: [String] = []
    var options: [String: String] = [:]
    var flags: Set<String> = []

    static func parse(_ args: [String]) -> CLIConfig {
        guard args.count > 1 else {
            return CLIConfig(command: "help")
        }
        let cmd = args[1]
        var config = CLIConfig(command: cmd)
        var i = 2
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--") {
                let key = String(arg.dropFirst(2))
                if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
                    config.options[key] = args[i + 1]
                    i += 2
                } else {
                    config.flags.insert(key)
                    i += 1
                }
            } else if arg.hasPrefix("-") {
                let key = String(arg.dropFirst(1))
                config.flags.insert(key)
                i += 1
            } else {
                config.positional.append(arg)
                i += 1
            }
        }
        return config
    }
}

enum KindleTarget: String {
    case host = "host"
    case kindlehf = "kindlehf"
    case kindlepw2 = "kindlepw2"

    var toolchainTuple: String {
        switch self {
        case .host: return "native"
        case .kindlehf: return "arm-kindlehf-linux-gnueabihf"
        case .kindlepw2: return "arm-kindlepw2-linux-gnueabi"
        }
    }

    var swiftTriple: String {
        switch self {
        case .host: return ""
        case .kindlehf: return "armv7-unknown-linux-gnueabihf"
        case .kindlepw2: return "armv7-unknown-linux-gnueabi"
        }
    }
}

final class KindleSwiftTool {
    let fm = FileManager.default

    func run() {
        let cli = CLIConfig.parse(CommandLine.arguments)
        switch cli.command.lowercased() {
        case "init", "new", "create":
            handleInit(cli)
        case "build", "compile":
            handleBuild(cli)
        case "sim", "preview", "run":
            handleSim(cli)
        case "package", "bundle", "kual":
            handlePackage(cli)
        case "doctor", "check":
            handleDoctor()
        case "title":
            handleTitle(cli)
        default:
            printHelp()
        }
    }

    // MARK: - `kindle-swift init`

    private func handleInit(_ cli: CLIConfig) {
        guard let rawName = cli.positional.first, !rawName.isEmpty else {
            fputs("Error: Missing project name. Usage: kindle-swift init <AppName> [--id org.kindlemodding.myapp]\n", stderr)
            exit(1)
        }

        let safeName = rawName.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        let appID = cli.options["id"] ?? "org.kindlemodding.\(safeName.lowercased())"
        let targetDir = cli.options["dir"] ?? rawName

        let sourcesDir = (targetDir as NSString).appendingPathComponent("Sources/\(safeName)")
        let kualDir = (targetDir as NSString).appendingPathComponent("kual/\(safeName)")

        do {
            try fm.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: kualDir, withIntermediateDirectories: true)

            let kindleUIPath = resolveKindleUIPackageRoot()

            let packageSwift = """
            // swift-tools-version: 5.9
            import PackageDescription

            let package = Package(
                name: "\(safeName)",
                platforms: [
                    .macOS(.v13)
                ],
                dependencies: [
                    .package(path: "\(escapeSwiftString(kindleUIPath))")
                ],
                targets: [
                    .executableTarget(
                        name: "\(safeName)",
                        dependencies: [
                            .product(name: "KindleUI", package: "KindleSwift")
                        ],
                        path: "Sources/\(safeName)"
                    )
                ]
            )
            """

            let appSwift = """
            import KindleUI

            @main
            struct \(safeName)App: App {
                var body: some Scene {
                    WindowGroup(
                        id: "\(appID)",
                        layer: .application,
                        role: .application,
                        chrome: .topBar
                    ) {
                        ContentView()
                    }
                }
            }

            struct ContentView: View {
                @State private var counter: Int = 0
                @State private var keepAwake: Bool = false
                @State private var frontlight: Double = Double(KindleDevice.shared.frontlightIntensity)
                @State private var noteText: String = "Hello from Swift on Kindle!"

                var body: some View {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(safeName)")
                            .font(.largeTitle)
                            .bold()

                        Text("Declarative SwiftUI-style app running on Kindle (GTK+-2.0 + AwesomeWM)")
                            .font(.subheadline)

                        Divider()

                        KindleCard("Quick Actions") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Page Counter: \\(counter)")
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    Button("+ Increment") {
                                        counter += 1
                                    }
                                    Button("- Decrement") {
                                        counter = max(0, counter - 1)
                                    }
                                    Button("Reset") {
                                        counter = 0
                                    }
                                }
                            }
                        }

                        KindleCard("Kindle Hardware (LIPC)") {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Prevent Screensaver Sleep", isOn: $keepAwake)
                                Text("Frontlight Intensity: \\(Int(frontlight)) / 24")
                                Slider(value: $frontlight, in: 0...24, step: 1)
                                ProgressView(
                                    value: Double(KindleDevice.shared.batteryLevel),
                                    total: 100.0,
                                    label: "Battery \\(KindleDevice.shared.batteryLevel)%"
                                )
                            }
                        }

                        KindleCard("Scratchpad") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Enter note...", text: $noteText)
                                Text("Saved: \\(noteText)")
                                    .font(.caption)
                            }
                        }

                        Spacer()
                    }
                    .padding(16)
                }
            }
            """

            let configXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <extension>
                <information>
                    <name>\(safeName)</name>
                    <version>1.0.0</version>
                    <author>KindleSwift Developer</author>
                    <id>\(appID)</id>
                </information>
                <menus>
                    <menu type="json" dynamic="true">menu.json</menu>
                </menus>
            </extension>
            """

            let menuJSON = """
            {
                "items": [
                    {
                        "name": "Launch \(safeName)",
                        "priority": 1,
                        "action": "./bin/\(safeName)",
                        "exitmenu": true
                    }
                ]
            }
            """

            try packageSwift.write(
                toFile: (targetDir as NSString).appendingPathComponent("Package.swift"),
                atomically: true,
                encoding: .utf8
            )
            try appSwift.write(
                toFile: (sourcesDir as NSString).appendingPathComponent("\(safeName)App.swift"),
                atomically: true,
                encoding: .utf8
            )
            try configXML.write(
                toFile: (kualDir as NSString).appendingPathComponent("config.xml"),
                atomically: true,
                encoding: .utf8
            )
            try menuJSON.write(
                toFile: (kualDir as NSString).appendingPathComponent("menu.json"),
                atomically: true,
                encoding: .utf8
            )

            print("✓ Created KindleUI Swift project '\(safeName)' in ./\(targetDir)")
            print("  • AwesomeWM App ID: \(appID)")
            print("  • Source file:      \(targetDir)/Sources/\(safeName)/\(safeName)App.swift")
            print("  • KUAL manifest:    \(targetDir)/kual/\(safeName)/config.xml")
            print("\nNext steps:")
            print("  cd \(targetDir)")
            print("  kindle-swift sim                       # Run interactive E-Ink simulator / GTK2 window")
            print("  kindle-swift build --target kindlehf   # Cross-compile for Kindle FW >= 5.16.3")
            print("  kindle-swift package --target kindlehf # Create KUAL extension & Kindle scriptlet")
        } catch {
            fputs("Error initializing project: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: - `kindle-swift build`

    private func handleBuild(_ cli: CLIConfig) {
        let projectDir = cli.options["project"] ?? fm.currentDirectoryPath
        let targetRaw = cli.options["target"] ?? "host"
        let target = KindleTarget(rawValue: targetRaw.lowercased()) ?? .host
        let isRelease = cli.flags.contains("release")
        let backend = cli.options["backend"] ?? (target == .host ? "swift" : "meson")
        let appName = cli.options["product"] ?? detectExecutableName(in: projectDir)

        print("==> Building '\(appName)' for target '\(target.rawValue)' (backend: \(backend))...")

        if target == .host && backend == "swift" {
            let configFlag = isRelease ? "release" : "debug"
            let status = runProcess(
                executable: "swift",
                arguments: ["build", "-c", configFlag, "--product", appName],
                workingDirectory: projectDir
            )
            guard status == 0 else {
                fputs("✗ Swift build failed with exit code \(status).\n", stderr)
                exit(status)
            }
            print("✓ Built host executable: \(projectDir)/.build/\(configFlag)/\(appName)")
            return
        }

        if backend == "swift-cross" {
            let sysroot = cli.options["sdk"] ?? defaultToolchainSysroot(for: target)
            let configFlag = isRelease ? "release" : "debug"
            var args = [
                "build",
                "-c", configFlag,
                "--product", appName,
                "--triple", target.swiftTriple
            ]
            if !sysroot.isEmpty {
                args.append(contentsOf: ["--sdk", sysroot])
            }
            args.append(contentsOf: ["-Xlinker", "-static-libstdc++"])
            let status = runProcess(executable: "swift", arguments: args, workingDirectory: projectDir)
            guard status == 0 else {
                fputs("✗ Swift cross-compilation failed (exit \(status)). Tip: use '--backend meson' to cross-compile via koxtoolchain + kindle-sdk Meson.\n", stderr)
                exit(status)
            }
            print("✓ Cross-compiled Swift binary for \(target.rawValue)!")
            return
        }

        // Meson + GTK+-2.0 C++17 cross-compilation pipeline (compatible with koxtoolchain + kindle-sdk)
        let mesonSrcDir = (projectDir as NSString).appendingPathComponent(".kindle-build/meson_src")
        let mesonBuildDir = (projectDir as NSString).appendingPathComponent(".kindle-build/builddir_\(target.rawValue)")

        print("  [1/3] Evaluating SwiftUI view hierarchy and emitting Meson + GTK+-2.0 C++17 project...")
        let emitStatus = runProcess(
            executable: "swift",
            arguments: ["run", appName, "--emit-meson", mesonSrcDir, "--name", appName],
            workingDirectory: projectDir
        )
        guard emitStatus == 0 else {
            fputs("✗ Failed to evaluate Swift target '\(appName)' for Meson emission.\n", stderr)
            exit(emitStatus)
        }

        if cli.flags.contains("emit-only") {
            print("✓ Emitted Meson project at \(mesonSrcDir)")
            return
        }

        var setupArgs = ["setup"]
        if fm.fileExists(atPath: mesonBuildDir) {
            setupArgs.append("--reconfigure")
        }
        if target != .host {
            let crossFile = cli.options["cross-file"] ?? detectMesonCrossFile(for: target)
            guard let crossFile = crossFile, fm.fileExists(atPath: crossFile) else {
                print("⚠ Meson project generated in '\(mesonSrcDir)', but 'meson-crosscompile.txt' for '\(target.rawValue)' was not found.")
                print("  Once koxtoolchain + kindle-sdk are installed, run:")
                print("    meson setup --cross-file ~/x-tools/\(target.toolchainTuple)/meson-crosscompile.txt \(mesonBuildDir) \(mesonSrcDir)")
                print("    meson compile -C \(mesonBuildDir)")
                return
            }
            print("  [2/3] Configuring Meson cross-build with \(crossFile)...")
            setupArgs.append(contentsOf: ["--cross-file", crossFile])
        } else {
            print("  [2/3] Configuring host Meson GTK+-2.0 build...")
        }
        setupArgs.append(contentsOf: [mesonBuildDir, mesonSrcDir])

        let setupStatus = runProcess(executable: "meson", arguments: setupArgs, workingDirectory: projectDir)
        guard setupStatus == 0 else {
            fputs("✗ 'meson setup' failed with code \(setupStatus).\n", stderr)
            exit(setupStatus)
        }

        print("  [3/3] Compiling Kindle binary with Meson...")
        let compileStatus = runProcess(
            executable: "meson",
            arguments: ["compile", "-C", mesonBuildDir],
            workingDirectory: projectDir
        )
        guard compileStatus == 0 else {
            fputs("✗ 'meson compile' failed with code \(compileStatus).\n", stderr)
            exit(compileStatus)
        }

        let outputBin = (mesonBuildDir as NSString).appendingPathComponent(appName)
        print("✓ Successfully compiled Kindle binary: \(outputBin)")
    }

    // MARK: - `kindle-swift sim`

    private func handleSim(_ cli: CLIConfig) {
        let projectDir = cli.options["project"] ?? fm.currentDirectoryPath
        let appName = cli.options["product"] ?? detectExecutableName(in: projectDir)

        var args = ["run", appName]
        if let htmlOut = cli.options["html"] {
            args.append(contentsOf: ["--export-html", htmlOut])
        } else if cli.flags.contains("terminal") || cli.flags.contains("sim") {
            args.append("--sim")
        }
        if cli.flags.contains("snapshot") {
            args.append("--snapshot")
        }

        let status = runProcess(executable: "swift", arguments: args, workingDirectory: projectDir)
        exit(status)
    }

    // MARK: - `kindle-swift package`

    private func handlePackage(_ cli: CLIConfig) {
        let projectDir = cli.options["project"] ?? fm.currentDirectoryPath
        let targetRaw = cli.options["target"] ?? "kindlehf"
        let target = KindleTarget(rawValue: targetRaw.lowercased()) ?? .kindlehf
        let appName = cli.options["product"] ?? detectExecutableName(in: projectDir)
        let appID = cli.options["id"] ?? "org.kindlemodding.\(appName.lowercased())"
        let distDir = cli.options["output"] ?? (projectDir as NSString).appendingPathComponent("dist")

        let extDir = (distDir as NSString).appendingPathComponent("extensions/\(appName)")
        let binDir = (extDir as NSString).appendingPathComponent("bin")
        let docsDir = (distDir as NSString).appendingPathComponent("documents")

        do {
            try fm.createDirectory(atPath: binDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: docsDir, withIntermediateDirectories: true)

            let candidateBins = [
                (projectDir as NSString).appendingPathComponent(".kindle-build/builddir_\(target.rawValue)/\(appName)"),
                (projectDir as NSString).appendingPathComponent(".build/release/\(appName)"),
                (projectDir as NSString).appendingPathComponent(".build/debug/\(appName)")
            ]

            let destBin = (binDir as NSString).appendingPathComponent(appName)
            if let existingBin = candidateBins.first(where: { fm.fileExists(atPath: $0) }) {
                if fm.fileExists(atPath: destBin) {
                    try fm.removeItem(atPath: destBin)
                }
                try fm.copyItem(atPath: existingBin, toPath: destBin)
                print("✓ Packaged binary '\(existingBin)' -> '\(destBin)'")
            } else {
                print("ℹ Compiled binary not found yet; created KUAL extension skeleton in '\(extDir)'.")
            }

            let configXML = """
            <?xml version="1.0" encoding="UTF-8"?>
            <extension>
                <information>
                    <name>\(appName)</name>
                    <version>1.0.0</version>
                    <author>KindleSwift</author>
                    <id>\(appID)</id>
                </information>
                <menus>
                    <menu type="json" dynamic="true">menu.json</menu>
                </menus>
            </extension>
            """

            let menuJSON = """
            {
                "items": [
                    {
                        "name": "Launch \(appName)",
                        "priority": 1,
                        "action": "./bin/\(appName)",
                        "exitmenu": true
                    }
                ]
            }
            """

            let scriptlet = """
            #!/bin/sh
            # Name: \(appName)
            # Author: KindleSwift
            # DontUseFBInk
            /mnt/us/extensions/\(appName)/bin/\(appName) &
            """

            try configXML.write(toFile: (extDir as NSString).appendingPathComponent("config.xml"), atomically: true, encoding: .utf8)
            try menuJSON.write(toFile: (extDir as NSString).appendingPathComponent("menu.json"), atomically: true, encoding: .utf8)
            try scriptlet.write(toFile: (docsDir as NSString).appendingPathComponent("\(appName).sh"), atomically: true, encoding: .utf8)

            print("✓ Created KUAL Extension & Scriptlet bundle in '\(distDir)':")
            print("  • Copy '\(distDir)/extensions/\(appName)' to '/mnt/us/extensions/\(appName)' on your Kindle")
            print("  • Or copy '\(distDir)/documents/\(appName).sh' to '/mnt/us/documents/' to launch directly from the Kindle library!")
        } catch {
            fputs("Error packaging KUAL bundle: \(error)\n", stderr)
            exit(1)
        }
    }

    // MARK: - `kindle-swift title`

    private func handleTitle(_ cli: CLIConfig) {
        let appID = cli.options["id"] ?? "org.kindlemodding.example-gtk-application"
        let layer = KindleLayer(rawValue: cli.options["layer"] ?? "A") ?? .application
        let role = KindleWindowRole(rawValue: cli.options["role"] ?? "application") ?? .application
        let pcRaw = cli.options["pc"] ?? "T"
        var chrome: KindleChrome = []
        if pcRaw.contains("T") { chrome.insert(.topBar) }
        if pcRaw.contains("S") { chrome.insert(.searchBar) }
        if pcRaw.contains("B") { chrome.insert(.bottomBar) }

        let cfg = KindleWindowConfig(
            applicationID: appID,
            layer: layer,
            role: role,
            persistentChrome: chrome
        )
        print(cfg.awesomeWindowTitle)
    }

    // MARK: - `kindle-swift doctor`

    private func handleDoctor() {
        print("KindleSwift Environment Doctor")
        print("==============================")

        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let hfCross = "\(home)/x-tools/arm-kindlehf-linux-gnueabihf/meson-crosscompile.txt"
        let pw2Cross = "\(home)/x-tools/arm-kindlepw2-linux-gnueabi/meson-crosscompile.txt"

        print("• Host OS:                     \( currentOSName() )")
        print("• kindlehf cross-file:         \( fm.fileExists(atPath: hfCross) ? "Found (\(hfCross))" : "Not found at \(hfCross)" )")
        print("• kindlepw2 cross-file:        \( fm.fileExists(atPath: pw2Cross) ? "Found (\(pw2Cross))" : "Not found at \(pw2Cross)" )")
        if let envCross = ProcessInfo.processInfo.environment["KINDLE_MESON_CROSS_FILE"] {
            print("• $KINDLE_MESON_CROSS_FILE:    \(envCross)")
        }
        print("\nTip: Follow 'prerequisites.html' to install koxtoolchain & kindle-sdk for 'kindlehf' or 'kindlepw2'.")
    }

    // MARK: - Helpers

    private func resolveKindleUIPackageRoot() -> String {
        let cwd = fm.currentDirectoryPath
        if fm.fileExists(atPath: (cwd as NSString).appendingPathComponent("Sources/KindleUI")) {
            return cwd
        }
        return ".."
    }

    private func detectExecutableName(in projectDir: String) -> String {
        let packagePath = (projectDir as NSString).appendingPathComponent("Package.swift")
        if let content = try? String(contentsOfFile: packagePath, encoding: .utf8) {
            if content.contains("KindleNotesDemo") {
                return "KindleNotesDemo"
            }
            // Extract first executableTarget name
            let lines = content.components(separatedBy: .newlines)
            var insideExec = false
            for line in lines {
                if line.contains(".executableTarget") {
                    insideExec = true
                } else if insideExec, line.contains("name:") {
                    let parts = line.components(separatedBy: "\"")
                    if parts.count >= 2 {
                        return parts[1]
                    }
                }
            }
        }
        return (projectDir as NSString).lastPathComponent
    }

    private func detectMesonCrossFile(for target: KindleTarget) -> String? {
        if let env = ProcessInfo.processInfo.environment["KINDLE_MESON_CROSS_FILE"], !env.isEmpty {
            return env
        }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let path = "\(home)/x-tools/\(target.toolchainTuple)/meson-crosscompile.txt"
        if fm.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private func defaultToolchainSysroot(for target: KindleTarget) -> String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/x-tools/\(target.toolchainTuple)/\(target.toolchainTuple)/sysroot"
    }

    private func runProcess(executable: String, arguments: [String], workingDirectory: String) -> Int32 {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
        process.arguments = ["/c", executable] + arguments
        #else
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        #endif
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            fputs("Failed to launch '\(executable)': \(error)\n", stderr)
            return 1
        }
    }

    private func escapeSwiftString(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "/")
    }

    private func currentOSName() -> String {
        #if os(Linux)
        return "Linux"
        #elseif os(macOS)
        return "macOS"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }

    private func printHelp() {
        print("""
        kindle-swift — SwiftUI-like Framework & Build System for Kindle Apps
        ====================================================================

        USAGE:
          kindle-swift <subcommand> [options]

        SUBCOMMANDS:
          init <AppName> [--id <app-id>]
              Creates a new KindleUI Swift project with AwesomeWM & KUAL support.

          sim [--product <Target>] [--terminal] [--html <file.html>]
              Runs the app in native GTK+-2.0 or the interactive E-Ink Simulator.

          build [--target host|kindlehf|kindlepw2] [--cross-file <path>] [--backend meson|swift-cross]
              Builds the app natively with Swift or cross-compiles for Kindle (koxtoolchain + kindle-sdk).

          package [--target kindlehf|kindlepw2] [--output dist]
              Packages the compiled binary into a KUAL extension and Kindle Home Scriptlet (.sh).

          title [--id <app-id>] [--layer A|D|C|KB|SS] [--role application|dialog] [--pc T|TS|N]
              Generates a formatted Kindle Awesome Window Manager title string.

          doctor
              Checks your host environment for Swift, Meson, GTK2, and Kindle SDK toolchains.
        """)
    }
}

KindleSwiftTool().run()
