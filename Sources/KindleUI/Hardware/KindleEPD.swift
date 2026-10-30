#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// E-Ink waveform modes supported by MediaTek-based Kindle displays (`hwtcon` driver on `/dev/fb0`).
public enum EInkWaveform: UInt32, Sendable {
    case initialize = 0
    case du = 1
    case gc16 = 2
    case gl16 = 3
    case reagl = 4
    case a2 = 6
    case du4 = 7
    case gc16Partial = 10
    case dunm = 12
    case auto = 257
}

/// Configures how `KindleUI` automatically refreshes the E-Ink display after UI state updates.
public struct EInkRefreshPolicy: Equatable, Sendable {
    /// Waveform used for normal interactive state updates (buttons, toggles, sliders, strokes).
    public var partialWaveform: EInkWaveform
    /// Waveform used for full-screen ghosting-clearing refreshes.
    public var fullWaveform: EInkWaveform
    /// Number of partial refreshes before automatically issuing a full refresh (`0` = manual/tab-change only).
    public var autoFullRefreshInterval: Int
    /// Whether switching tabs in a `TabView` triggers a full-screen refresh to clear ghosting.
    public var fullRefreshOnTabChange: Bool

    public init(
        partialWaveform: EInkWaveform = .auto,
        fullWaveform: EInkWaveform = .gc16,
        autoFullRefreshInterval: Int = 0,
        fullRefreshOnTabChange: Bool = false
    ) {
        self.partialWaveform = partialWaveform
        self.fullWaveform = fullWaveform
        self.autoFullRefreshInterval = autoFullRefreshInterval
        self.fullRefreshOnTabChange = fullRefreshOnTabChange
    }

    /// Default automatic E-Ink refresh policy.
    public static let automatic = EInkRefreshPolicy()

    /// Fast 2-level direct-update (`DU`) refresh policy for low-latency stylus drawing.
    public static let fastDrawing = EInkRefreshPolicy(
        partialWaveform: .du,
        fullWaveform: .gc16,
        autoFullRefreshInterval: 20,
        fullRefreshOnTabChange: true
    )
}

/// Direct access to the E-Ink panel of MediaTek-based Kindles (Paperwhite 5/6, Scribe, Basic 4/5, Colorsoft)
/// via `MXCFB_SEND_UPDATE_MTK` on `/dev/fb0`.
///
/// Managed automatically by `KindleUI` (`KindleDevice.shared` and `GTK2Renderer`) so application code
/// does not need to manually issue framebuffer ioctls. Fails soft on non-Kindle hosts or emulators.
public final class KindleEPDController: @unchecked Sendable {
    public struct FramebufferInfo: Sendable {
        public let xres: Int
        public let yres: Int
        public let xresVirtual: Int
        public let yresVirtual: Int
        public let bitsPerPixel: Int
        public let grayscale: Int
        public let rotate: Int
        public let lineLength: Int
        public let memorySize: Int
        public let id: String

        public var summary: String {
            "\(id) \(xres)×\(yres)"
        }
    }

    private static let sendUpdateRequest: UInt = 0x4060_462E
    private static let updateStructSize = 96
    private static let getVarScreenInfo: UInt = 0x4600
    private static let getFixScreenInfo: UInt = 0x4602

    public let path: String
    public let info: FramebufferInfo
    private let fd: Int32
    private var marker: UInt32 = UInt32(truncatingIfNeeded: getpid())
    public private(set) var lastError: Int32 = 0
    public private(set) var refreshCount: Int = 0

    public static func attach(path: String = "/dev/fb0") -> KindleEPDController? {
        let rw = path.withCString { open($0, O_RDWR) }
        let fd = rw >= 0 ? rw : path.withCString { open($0, O_RDONLY) }
        guard fd >= 0 else { return nil }
        guard let info = queryInfo(fd) else {
            close(fd)
            return nil
        }
        return KindleEPDController(path: path, fd: fd, info: info)
    }

    private init(path: String, fd: Int32, info: FramebufferInfo) {
        self.path = path
        self.fd = fd
        self.info = info
    }

    deinit {
        close(fd)
    }

    private static func queryInfo(_ fd: Int32) -> FramebufferInfo? {
        var v = [UInt32](repeating: 0, count: 40)
        let rv = v.withUnsafeMutableBytes { ioctl(fd, getVarScreenInfo, $0.baseAddress!) }
        guard rv == 0 else { return nil }

        var f = [UInt8](repeating: 0, count: 128)
        let fixOK = f.withUnsafeMutableBytes { ioctl(fd, getFixScreenInfo, $0.baseAddress!) } == 0
        let ul = MemoryLayout<UInt>.size
        func u32(_ o: Int) -> Int {
            Int(f[o]) | Int(f[o + 1]) << 8 | Int(f[o + 2]) << 16 | Int(f[o + 3]) << 24
        }
        let idBytes = f[0..<16].prefix { $0 != 0 }
        return FramebufferInfo(
            xres: Int(v[0]),
            yres: Int(v[1]),
            xresVirtual: Int(v[2]),
            yresVirtual: Int(v[3]),
            bitsPerPixel: Int(v[6]),
            grayscale: Int(v[7]),
            rotate: Int(v[34]),
            lineLength: fixOK ? u32(40 + ul) : 0,
            memorySize: fixOK ? u32(16 + ul) : 0,
            id: fixOK ? String(decoding: idBytes, as: UTF8.self) : "fb0"
        )
    }

    /// Requests an E-Ink panel update for the specified rectangle (defaults to full panel bounds).
    @discardableResult
    public func refresh(
        x: Int = 0,
        y: Int = 0,
        width: Int? = nil,
        height: Int? = nil,
        waveform: EInkWaveform = .auto,
        full: Bool = false
    ) -> Int32 {
        let w = width ?? info.xres
        let h = height ?? info.yres
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(info.xres, x + w)
        let y1 = min(info.yres, y + h)
        guard x1 - x0 > 1, y1 - y0 > 1 else { return EINVAL }

        marker = marker &+ 1
        if marker == 0 { marker = 1 }

        var words = [UInt32](repeating: 0, count: Self.updateStructSize / 4)
        words[0] = UInt32(y0)
        words[1] = UInt32(x0)
        words[2] = UInt32(x1 - x0)
        words[3] = UInt32(y1 - y0)
        words[4] = waveform.rawValue
        words[5] = full ? 1 : 0
        words[6] = marker
        words[7] = 0x1000
        let wf = words[4]
        words[8] = wf == EInkWaveform.a2.rawValue ? 0x02 : 0
        words[20] = wf == EInkWaveform.reagl.rawValue ? EInkWaveform.reagl.rawValue : EInkWaveform.du.rawValue
        words[21] = wf == EInkWaveform.reagl.rawValue ? EInkWaveform.reagl.rawValue : EInkWaveform.gc16.rawValue

        var rv: Int32
        repeat {
            rv = words.withUnsafeMutableBytes { ioctl(fd, Self.sendUpdateRequest, $0.baseAddress!) }
        } while rv < 0 && errno == EINTR
        if rv < 0 {
            lastError = errno
            return errno
        }
        refreshCount += 1
        return 0
    }
}
