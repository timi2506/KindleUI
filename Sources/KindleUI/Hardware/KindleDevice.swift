import Foundation
import CKindleGTK

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation
import CKindleGTK

/// Provides access to Kindle hardware services via Amazon's LIPC bus (`liblipc.so`),
/// automatic MediaTek `hwtcon` E-Ink panel refreshes (`/dev/fb0`), and device telemetry.
///
/// When running on a desktop simulator (Linux/macOS/Windows), `KindleDevice` safely
/// falls back to in-memory simulated hardware state.
public final class KindleDevice: @unchecked Sendable {
    public static let shared = KindleDevice()

    /// Current screen pixel width queried from GDK / hardware display.
    public var screenWidth: Int {
        var screenW: Int32 = 1200
        var screenH: Int32 = 1600
        kgtk_get_screen_size(&screenW, &screenH)
        return screenW > 0 ? Int(screenW) : 1200
    }

    /// Current screen pixel height queried from GDK / hardware display.
    public var screenHeight: Int {
        var screenW: Int32 = 1200
        var screenH: Int32 = 1600
        kgtk_get_screen_size(&screenW, &screenH)
        return screenH > 0 ? Int(screenH) : 1600
    }

    private var simulatedFrontlight: Int = 12
    private var simulatedWarmth: Int = 6
    private var simulatedBattery: Int = 87
    private var simulatedPreventScreenSaver: Bool = false
    private var simulatedAirplaneMode: Bool = false
    private var simulatedOrientationLock: String = "U"
    private var simulatedKeyboardVisible: Bool = false
    private var cachedNativeKeyboardPhysHeight: Int? = nil
    private var activeNativeKeyboardAppID: String? = nil

    /// Active AwesomeWM application ID (`ID` key), used when opening/closing `com.lab126.keyboard`.
    public var activeApplicationID: String = "org.kindlemodding.swiftapp"

    /// When `true` (default), `TextField`, `SecureField`, `TextEditor`, and `showKeyboard()` summon
    /// the native Kindle OS keyboard (`com.lab126.keyboard` / `/usr/bin/kb`) whenever `liblipc.so` is available,
    /// falling back to the built-in KindleUI E-Ink keyboard only on desktop simulators.
    public var preferNativeSystemKeyboard: Bool = true

    /// Returns `true` when the native Kindle OS keyboard (`com.lab126.keyboard`) is active on this host.
    public var isUsingNativeSystemKeyboard: Bool {
        preferNativeSystemKeyboard && isHardwareAvailable
    }

    /// Logical height (in 1860x2480 coordinates) of the native Kindle OS keyboard (`com.lab126.keyboard`).
    public var nativeKeyboardHeightLogicalPx: Int {
        let physH: Int
        if let cached = cachedNativeKeyboardPhysHeight {
            physH = cached
        } else {
            let queried = getLipcInt(service: "com.lab126.keyboard", property: "height") ?? 567
            let valid = max(360, queried)
            cachedNativeKeyboardPhysHeight = valid
            physH = valid
        }
        let scale = max(0.28, kgtk_get_ui_scale())
        return Int((Double(physH) / scale).rounded()) + 16
    }

    /// Active E-Ink framebuffer controller (automatically attached on launch unless `--no-epd` is passed).
    public private(set) var epd: KindleEPDController?
    private var epdConfigured = false

    /// Active automatic E-Ink refresh policy.
    public var refreshPolicy: EInkRefreshPolicy = .automatic

    /// Number of automatic or manual E-Ink refreshes performed during this session.
    public private(set) var partialRefreshCounter: Int = 0
    public private(set) var interactionCount: Int = 0

    /// Optional callback invoked when `refreshScreen(full: true)` is triggered.
    public var onFullRefresh: (() -> Void)?

    private init() {}

    // MARK: - Automatic E-Ink Panel Management

    /// Automatically attaches to `/dev/fb0` based on CLI arguments (`--no-epd`, `--epd-device <path>`).
    public func configureEPDFromCommandLine() {
        guard !epdConfigured else { return }
        epdConfigured = true
        let args = CommandLine.arguments
        if args.contains("--no-epd") {
            epd = nil
            return
        }
        var devicePath = "/dev/fb0"
        if let idx = args.firstIndex(of: "--epd-device"), idx + 1 < args.count {
            devicePath = args[idx + 1]
        }
        epd = KindleEPDController.attach(path: devicePath)
    }

    /// Manually attaches or replaces the E-Ink framebuffer controller.
    public func attachEPD(path: String = "/dev/fb0") {
        epdConfigured = true
        epd = KindleEPDController.attach(path: path)
    }

    /// Disables automatic E-Ink framebuffer ioctls.
    public func disableEPD() {
        epdConfigured = true
        epd = nil
    }

    /// Called automatically by `KindleUI` (`GTK2Renderer`) after UI state rebuilds or canvas strokes.
    /// Note: Under X11 on Kindle OS, Xorg's `fbdev`/`hwtcon` XDamage driver automatically submits partial
    /// waveform updates for damaged regions. Issuing a second `MXCFB_SEND_UPDATE_MTK` ioctl from the app
    /// process on every partial frame races with Xorg and causes a 700ms LUT collision stall in `hwtcon`.
    /// Therefore, direct `/dev/fb0` updates are only issued when a full-screen ghosting refresh (`shouldFull`) is requested.
    internal func performAutomaticRefresh(forceFull: Bool = false) {
        interactionCount += 1
        guard let epd = epd else { return }
        partialRefreshCounter += 1
        let shouldFull = forceFull ||
            (refreshPolicy.autoFullRefreshInterval > 0 &&
             partialRefreshCounter % refreshPolicy.autoFullRefreshInterval == 0)
        if shouldFull {
            _ = epd.refresh(waveform: refreshPolicy.fullWaveform, full: true)
        }
    }

    /// Explicitly refreshes the E-Ink screen (defaults to a full `GC16` ghosting-clearing flash).
    public func refreshScreen(full: Bool = true, waveform: EInkWaveform? = nil) {
        if full {
            onFullRefresh?()
        }
        guard let epd = epd else { return }
        let wf = waveform ?? (full ? refreshPolicy.fullWaveform : refreshPolicy.partialWaveform)
        _ = epd.refresh(waveform: wf, full: full)
    }

    // MARK: - LIPC Hardware Properties

    /// Returns `true` if running on actual Kindle hardware with `liblipc.so` available.
    public var isHardwareAvailable: Bool {
        klipc_is_available()
    }

    /// Reads or sets the Kindle frontlight brightness intensity (`0...24`).
    /// Uses `com.lab126.powerd` -> `flIntensity` on Kindle hardware.
    public var frontlightIntensity: Int {
        get {
            var val: Int32 = 0
            if klipc_get_int_property("com.lab126.powerd", "flIntensity", &val) == 0 {
                return Int(val)
            }
            return simulatedFrontlight
        }
        set {
            let clamped = max(0, min(24, newValue))
            simulatedFrontlight = clamped
            _ = klipc_set_int_property("com.lab126.powerd", "flIntensity", Int32(clamped))
        }
    }

    /// Reads the current battery percentage (`0...100`) from sysfs `/sys/class/power_supply` or LIPC `com.lab126.powerd`.
    public var batteryPercentage: Int {
        get { batteryLevel }
        set { simulatedBattery = max(0, min(100, newValue)) }
    }

    /// Reads the current battery percentage (`0...100`) from sysfs `/sys/class/power_supply` or LIPC `com.lab126.powerd`.
    public var batteryLevel: Int {
        if let dir = opendir("/sys/class/power_supply") {
            defer { closedir(dir) }
            while let entry = readdir(dir) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
                if name != "." && name != ".." {
                    if let raw = Self.readSmallFile("/sys/class/power_supply/\(name)/capacity", maxBytes: 12),
                       let pct = Int(raw) {
                        return max(0, min(100, pct))
                    }
                }
            }
        }
        var val: Int32 = 0
        if klipc_get_int_property("com.lab126.powerd", "battLevel", &val) == 0 {
            return Int(val)
        }
        return simulatedBattery
    }

    /// Controls whether the Kindle screensaver/sleep timer is suppressed (`com.lab126.powerd` -> `preventScreenSaver`).
    public var preventScreenSaver: Bool {
        get {
            var val: Int32 = 0
            if klipc_get_int_property("com.lab126.powerd", "preventScreenSaver", &val) == 0 {
                return val != 0
            }
            return simulatedPreventScreenSaver
        }
        set {
            simulatedPreventScreenSaver = newValue
            _ = klipc_set_int_property("com.lab126.powerd", "preventScreenSaver", newValue ? 1 : 0)
        }
    }

    /// Sends a custom LIPC integer property command.
    @discardableResult
    public func setLipcInt(service: String, property: String, value: Int) -> Bool {
        klipc_set_int_property(service, property, Int32(value)) == 0
    }

    /// Reads a custom LIPC integer property.
    public func getLipcInt(service: String, property: String) -> Int? {
        var val: Int32 = 0
        guard klipc_get_int_property(service, property, &val) == 0 else { return nil }
        return Int(val)
    }

    /// Sends a custom LIPC string property command.
    @discardableResult
    public func setLipcString(service: String, property: String, value: String) -> Bool {
        klipc_set_string_property(service, property, value) == 0
    }

    /// Reads a custom LIPC string property.
    public func getLipcString(service: String, property: String) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        guard klipc_get_string_property(service, property, &buf, Int32(buf.count)) == 0 else {
            return nil
        }
        return String(cString: buf)
    }

    /// Reads or sets the Kindle warm/amber LED frontlight intensity (`0...24`) on supported devices
    /// (Paperwhite 5, Oasis, Scribe) via `com.lab126.powerd` -> `currentAmberLevel` / `flWarmth` / `com.lab126.winmgr` -> `chrontelWarmth`.
    public var frontlightWarmth: Int {
        get {
            if let v = getLipcInt(service: "com.lab126.powerd", property: "currentAmberLevel") {
                return v
            }
            if let v = getLipcInt(service: "com.lab126.powerd", property: "flWarmth") {
                return v
            }
            if let v = getLipcInt(service: "com.lab126.winmgr", property: "chrontelWarmth") {
                return v
            }
            return simulatedWarmth
        }
        set {
            let clamped = max(0, min(24, newValue))
            simulatedWarmth = clamped
            if !setLipcInt(service: "com.lab126.powerd", property: "currentAmberLevel", value: clamped) {
                _ = setLipcInt(service: "com.lab126.powerd", property: "flWarmth", value: clamped)
                _ = setLipcInt(service: "com.lab126.winmgr", property: "chrontelWarmth", value: clamped)
            }
        }
    }

    /// Reads or toggles Kindle Airplane Mode (`com.lab126.cmd` -> `wirelessEnable`).
    public var isAirplaneMode: Bool {
        get {
            if let wireless = getLipcInt(service: "com.lab126.cmd", property: "wirelessEnable") {
                return wireless == 0
            }
            return simulatedAirplaneMode
        }
        set {
            simulatedAirplaneMode = newValue
            _ = setLipcInt(service: "com.lab126.cmd", property: "wirelessEnable", value: newValue ? 0 : 1)
        }
    }

    /// Returns the active Wi-Fi SSID or network state from `com.lab126.wifid`.
    public var wifiSSID: String {
        if let ssid = getLipcString(service: "com.lab126.wifid", property: "currentEssid"), !ssid.isEmpty {
            return ssid
        }
        if let state = getLipcString(service: "com.lab126.wifid", property: "cmState"), !state.isEmpty {
            return state
        }
        return isAirplaneMode ? "Airplane Mode" : "KindleNet"
    }

    /// Returns `true` if a non-loopback network interface is currently up.
    public var isNetworkConnected: Bool {
        if isAirplaneMode { return false }
        if let dir = opendir("/sys/class/net") {
            defer { closedir(dir) }
            while let entry = readdir(dir) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
                if name != "." && name != ".." && name != "lo" {
                    if let state = Self.readSmallFile("/sys/class/net/\(name)/operstate", maxBytes: 16),
                       state == "up" || state == "unknown" {
                        return true
                    }
                }
            }
        }
        return true
    }

    /// Reads or sets the Kindle screen orientation lock (`"U"`, `"D"`, `"L"`, `"R"`) via `com.lab126.winmgr`.
    public var orientationLock: String {
        get {
            if let lock = getLipcString(service: "com.lab126.winmgr", property: "orientationLock"), !lock.isEmpty {
                return lock
            }
            return simulatedOrientationLock
        }
        set {
            simulatedOrientationLock = newValue
            _ = setLipcString(service: "com.lab126.winmgr", property: "orientationLock", value: newValue)
        }
    }

    /// Summons the Kindle on-screen virtual keyboard.
    /// On Kindle hardware (`liblipc.so`), this opens the native Kindle OS keyboard (`com.lab126.keyboard`)
    /// on the `KB` layer (`<appID>:<layout>:0`); on desktop simulators, it falls back to the built-in E-Ink keyboard.
    public func showKeyboard(layout: String = "abc", useSystemLipcKeyboard: Bool = true) {
        simulatedKeyboardVisible = true
        preferNativeSystemKeyboard = useSystemLipcKeyboard
        KindleKeyboardManager.shared.showDefault(layout: layout)
    }

    /// Dismisses the Kindle on-screen virtual keyboard (`com.lab126.keyboard` and Input Dock).
    public func hideKeyboard() {
        simulatedKeyboardVisible = false
        KindleKeyboardManager.shared.dismiss()
        closeNativeSystemKeyboard()
    }

    internal func openNativeSystemKeyboard(layout: String = "abc") {
        guard isUsingNativeSystemKeyboard else { return }
        let appID = activeApplicationID.isEmpty ? "org.kindlemodding.swiftapp" : activeApplicationID
        activeNativeKeyboardAppID = appID
        _ = setLipcString(service: "com.lab126.keyboard", property: "open", value: "\(appID):\(layout):0")
    }

    internal func closeNativeSystemKeyboard(force: Bool = false) {
        guard isHardwareAvailable else { return }
        var closedAny = false
        if let openAppID = activeNativeKeyboardAppID, !openAppID.isEmpty {
            activeNativeKeyboardAppID = nil
            _ = setLipcString(service: "com.lab126.keyboard", property: "close", value: openAppID)
            closedAny = true
        }
        if force || !closedAny {
            let appID = activeApplicationID.isEmpty ? "org.kindlemodding.swiftapp" : activeApplicationID
            _ = setLipcString(service: "com.lab126.keyboard", property: "close", value: appID)
        }
        if getLipcInt(service: "com.lab126.keyboard", property: "show") == 1,
           let kbAppID = getLipcString(service: "com.lab126.keyboard", property: "appID"),
           !kbAppID.isEmpty {
            _ = setLipcString(service: "com.lab126.keyboard", property: "close", value: kbAppID)
        }
    }

    /// Triggers a native Kindle Pillow system alert dialog via `com.lab126.pillow`.
    @discardableResult
    public func sendPillowAlert(title: String, message: String) -> Bool {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
        let payload = "{\"clientParams\":{\"alertId\":\"appAlert1\",\"show\":true,\"customStrings\":[{\"matchStr\":\"alertTitle\",\"replaceStr\":\"\(escapedTitle)\"},{\"matchStr\":\"alertText\",\"replaceStr\":\"\(escapedMsg)\"}]}}"
        return setLipcString(service: "com.lab126.pillow", property: "simpleAlert", value: payload)
    }

    /// Suspends the Kindle into screensaver/sleep mode via `com.lab126.powerd`.
    @discardableResult
    public func suspendToScreenSaver() -> Bool {
        setLipcInt(service: "com.lab126.powerd", property: "suspend", value: 1)
    }

    // MARK: - Device Telemetry & Clock

    /// Current local time formatted as `HH:mm`.
    public var clockTimeString: String {
        var t = time(nil)
        var tmv = tm()
        localtime_r(&t, &tmv)
        var buf = [CChar](repeating: 0, count: 16)
        strftime(&buf, buf.count, "%H:%M", &tmv)
        return String(cString: buf)
    }

    /// Short Kindle serial/board prefix from `/proc/usid` (or `"Sim"` when unavailable).
    public var deviceCode: String {
        Self.readSmallFile("/proc/usid", maxBytes: 8).map { String($0.prefix(4)) } ?? "Sim"
    }

    /// Kernel name and release string (e.g., `"Linux 6.1.0"`).
    public var kernelDescription: String {
        let u = Self.unameInfo()
        return "\(u.sys) \(u.release)"
    }

    /// CPU architecture string (e.g., `"armv7l"` or `"arm64"`).
    public var architecture: String {
        Self.unameInfo().machine
    }

    /// Human-readable system uptime string from `/proc/uptime`.
    public var uptimeDescription: String {
        guard let raw = Self.readSmallFile("/proc/uptime", maxBytes: 32),
              let first = raw.split(separator: " ").first,
              let secs = Double(first) else {
            return "0h 5m"
        }
        let s = Int(secs)
        let d = s / 86400
        let h = (s % 86400) / 3600
        let m = (s % 3600) / 60
        return d > 0 ? "\(d)d \(h)h \(m)m" : "\(h)h \(m)m"
    }

    /// Human-readable available and total RAM from `/proc/meminfo`.
    public var memoryDescription: String {
        guard let f = fopen("/proc/meminfo", "r") else { return "N/A" }
        defer { fclose(f) }
        var total = 0
        var avail = 0
        var line = [CChar](repeating: 0, count: 128)
        while fgets(&line, Int32(line.count), f) != nil {
            let s = String(cString: line)
            let parts = s.split(whereSeparator: { $0 == " " || $0 == ":" })
            guard parts.count >= 2, let kb = Int(parts[1]) else { continue }
            if parts[0] == "MemTotal" { total = kb }
            if parts[0] == "MemAvailable" { avail = kb }
        }
        return total > 0 ? "\(avail / 1024) of \(total / 1024) MB free" : "N/A"
    }

    /// Description of the active E-Ink framebuffer or GTK display backend.
    public var displayDescription: String {
        epd?.info.summary ?? "GTK+-2.0 / X11"
    }

    /// Cleanly terminates the running GTK+-2.0 event loop or simulator process.
    public func quitApplication() {
        closeNativeSystemKeyboard()
        kgtk_main_quit()
        exit(0)
    }

    // MARK: - Internal Helpers

    private static func readSmallFile(_ path: String, maxBytes: Int = 64) -> String? {
        guard let f = fopen(path, "r") else { return nil }
        defer { fclose(f) }
        var buf = [CChar](repeating: 0, count: maxBytes + 1)
        guard fgets(&buf, Int32(maxBytes), f) != nil else { return nil }
        return String(cString: buf).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unameInfo() -> (sys: String, release: String, machine: String) {
        var u = utsname()
        uname(&u)
        func extract<T>(_ field: inout T) -> String {
            withUnsafePointer(to: &field) {
                $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { String(cString: $0) }
            }
        }
        return (extract(&u.sysname), extract(&u.release), extract(&u.machine))
    }
}

/// Convenience screen utility to access display bounds.
public struct KindleScreen {
    /// Screen pixel width (defaults to 1200 on simulators or when uninitialized).
    public static var width: Int {
        KindleDevice.shared.screenWidth
    }

    /// Screen pixel height (defaults to 1600 on simulators or when uninitialized).
    public static var height: Int {
        KindleDevice.shared.screenHeight
    }
}
