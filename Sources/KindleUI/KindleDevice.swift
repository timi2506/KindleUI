import Foundation
import CKindleGTK

/// Provides access to Kindle hardware services via Amazon's LIPC bus (`liblipc.so`)
/// and E-Ink framebuffer utilities (`eips`).
///
/// When running on a desktop simulator (Linux/macOS/Windows), `KindleDevice` safely
/// falls back to in-memory simulated hardware state.
public final class KindleDevice: @unchecked Sendable {
    public static let shared = KindleDevice()

    private var simulatedFrontlight: Int = 12
    private var simulatedBattery: Int = 87
    private var simulatedPreventScreenSaver: Bool = false

    private init() {}

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

    /// Reads the current battery percentage (`0...100`) from `com.lab126.powerd` -> `battLevel`.
    public var batteryLevel: Int {
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

    /// Sends a custom LIPC string property command.
    @discardableResult
    public func setLipcString(service: String, property: String, value: String) -> Bool {
        klipc_set_string_property(service, property, value) == 0
    }
}
