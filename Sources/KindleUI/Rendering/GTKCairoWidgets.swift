import Foundation
import CKindleGTK

/// Holds mutable drawing state for Cairo-rendered E-Ink widgets (`Icon`, `Switch`, `ProgressBar`, `Divider`, `ModalScrim`).
/// Retained by the underlying GTK widget via `kgtk_connect_cairo_expose` and released automatically when the widget is destroyed.
internal final class GTKCairoTarget {
    enum Kind {
        case modalScrim(bgGray: UInt8, alpha: Double)
        case toggleSwitch(isOn: Bool, isCheckbox: Bool, fgGray: UInt8, bgGray: UInt8, trackGray: UInt8)
        case progressBar(fraction: Double, fgGray: UInt8, bgGray: UInt8, trackGray: UInt8)
        case divider(grayLevel: UInt8)
        case icon(icon: KindleIconName, fgGray: UInt8, bgGray: UInt8, hasBg: Bool)
    }

    var kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    func draw(cr: KCairoRef, x: Double, y: Double, width: Double, height: Double) {
        switch kind {
        case .modalScrim(let bgGray, let alpha):
            guard width > 1, height > 1 else { return }
            kcairo_set_gray_alpha(cr, bgGray, alpha)
            kcairo_rectangle(cr, x, y, width, height)
            kcairo_fill(cr)

        case .toggleSwitch(let isOn, let isCheckbox, let fgGray, let bgGray, let trackGray):
            guard width > 4, height > 4 else { return }
            drawToggleSwitch(
                cr: cr, ox: x, oy: y, w: width, h: height,
                isOn: isOn, isCheckbox: isCheckbox,
                fgGray: fgGray, bgGray: bgGray, trackGray: trackGray
            )

        case .progressBar(let fraction, let fgGray, _, let trackGray):
            guard width > 4, height > 4 else { return }
            let ox = x + 1.5
            let oy = y + 1.5
            let w = width - 3.0
            let h = height - 3.0
            let r = h * 0.5

            kcairo_rounded_rect(cr, ox, oy, w, h, r)
            kcairo_set_gray(cr, trackGray)
            kcairo_fill(cr)

            let fillW = w * min(1.0, max(0.0, fraction))
            if fillW > 4.0 {
                kcairo_rounded_rect(cr, ox, oy, fillW, h, r)
                kcairo_set_gray(cr, fgGray)
                kcairo_fill(cr)
            }

            let lw = max(1.0, 1.6 * kgtk_get_ui_scale())
            kcairo_rounded_rect(cr, ox, oy, w, h, r)
            kcairo_set_line_width(cr, lw)
            kcairo_set_gray(cr, fgGray)
            kcairo_stroke(cr)

        case .divider(let grayLevel):
            guard width > 0, height > 0 else { return }
            kcairo_rounded_rect(cr, x, y, width, height, 0)
            kcairo_set_gray(cr, grayLevel)
            kcairo_fill(cr)

        case .icon(let icon, let fgGray, let bgGray, let hasBg):
            guard width > 2, height > 2 else { return }
            drawIcon(cr: cr, ox: x, oy: y, w: width, h: height, icon: icon, fgGray: fgGray, bgGray: bgGray, hasBg: hasBg)
        }
    }

    private func drawToggleSwitch(
        cr: KCairoRef,
        ox: Double,
        oy: Double,
        w: Double,
        h: Double,
        isOn: Bool,
        isCheckbox: Bool,
        fgGray: UInt8,
        bgGray: UInt8,
        trackGray: UInt8
    ) {
        let s = kgtk_get_ui_scale()
        let inset = max(2.0, 6.0 * s)
        let lw = max(1.5, 3.0 * s)

        if isCheckbox {
            let sz = min(w, h) - inset
            let x = ox + (w - sz) * 0.5
            let y = oy + (h - sz) * 0.5
            let rad = max(4.0, 12.0 * s)

            kcairo_rounded_rect(cr, x, y, sz, sz, rad)
            kcairo_set_gray(cr, isOn ? fgGray : bgGray)
            kcairo_fill(cr)

            kcairo_rounded_rect(cr, x, y, sz, sz, rad)
            kcairo_set_line_width(cr, lw)
            kcairo_set_gray(cr, fgGray)
            kcairo_stroke(cr)

            if isOn {
                kcairo_set_line_round(cr)
                kcairo_new_path(cr)
                kcairo_move_to(cr, x + sz * 0.24, y + sz * 0.52)
                kcairo_line_to(cr, x + sz * 0.44, y + sz * 0.72)
                kcairo_line_to(cr, x + sz * 0.78, y + sz * 0.30)
                kcairo_set_line_width(cr, max(2.0, 4.5 * s))
                kcairo_set_gray(cr, bgGray)
                kcairo_stroke(cr)
            }
        } else {
            let sw = w - inset
            let sh = h - inset
            let sx = ox + inset * 0.5
            let sy = oy + inset * 0.5
            let r = sh * 0.5

            kcairo_rounded_rect(cr, sx, sy, sw, sh, r)
            kcairo_set_gray(cr, isOn ? fgGray : trackGray)
            kcairo_fill(cr)

            kcairo_rounded_rect(cr, sx, sy, sw, sh, r)
            kcairo_set_line_width(cr, lw)
            kcairo_set_gray(cr, fgGray)
            kcairo_stroke(cr)

            let thumbPad = max(2.5, 7.0 * s)
            let thumbR = max(3.0, r - thumbPad)
            let cx = isOn ? (sx + sw - r) : (sx + r)
            let cy = sy + r
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, thumbR, 0.0, 2.0 * .pi)
            kcairo_set_gray(cr, isOn ? bgGray : fgGray)
            kcairo_fill(cr)
        }
    }

    private func drawIcon(
        cr: KCairoRef,
        ox: Double,
        oy: Double,
        w: Double,
        h: Double,
        icon: KindleIconName,
        fgGray: UInt8,
        bgGray: UInt8,
        hasBg: Bool
    ) {
        let s = min(w, h)
        let cx = ox + w * 0.5
        let cy = oy + h * 0.5
        let r = s * 0.45
        let lw = max(2.0, s * 0.085)
        let pi = Double.pi

        if hasBg {
            kcairo_rounded_rect(cr, ox, oy, w, h, s * 0.22)
            kcairo_set_gray(cr, bgGray)
            kcairo_fill(cr)
        }

        kcairo_set_gray(cr, fgGray)
        kcairo_set_line_width(cr, lw)
        kcairo_set_line_round(cr)

        switch icon {
        case .wifi:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy + r * 0.55, r * 0.12, 0, 2 * pi)
            kcairo_fill(cr)
            for ring in 1...3 {
                kcairo_new_path(cr)
                kcairo_arc(cr, cx, cy + r * 0.55, r * (0.38 * Double(ring)), 1.22 * pi, 1.78 * pi)
                kcairo_stroke(cr)
            }

        case .battery:
            kcairo_rounded_rect(cr, cx - r * 0.95, cy - r * 0.52, r * 1.65, r * 1.04, r * 0.18)
            kcairo_stroke(cr)
            kcairo_rounded_rect(cr, cx + r * 0.75, cy - r * 0.25, r * 0.20, r * 0.50, r * 0.06)
            kcairo_fill(cr)
            kcairo_rounded_rect(cr, cx - r * 0.72, cy - r * 0.30, r * 1.05, r * 0.60, r * 0.08)
            kcairo_fill(cr)

        case .sun:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.45, 0, 2 * pi)
            kcairo_stroke(cr)
            for i in 0..<8 {
                let c = (i % 2 == 0) ? ((i == 0) ? 1.0 : (i == 4 ? -1.0 : 0.0)) : ((i == 1 || i == 7) ? 0.7071 : -0.7071)
                let sn = (i % 2 == 0) ? ((i == 2) ? 1.0 : (i == 6 ? -1.0 : 0.0)) : ((i == 1 || i == 3) ? 0.7071 : -0.7071)
                kcairo_move_to(cr, cx + c * r * 0.68, cy + sn * r * 0.68)
                kcairo_line_to(cr, cx + c * r * 0.98, cy + sn * r * 0.98)
            }
            kcairo_stroke(cr)

        case .moon:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.78, 0.25 * pi, 1.55 * pi)
            kcairo_arc(cr, cx + r * 0.35, cy - r * 0.22, r * 0.62, 1.40 * pi, 0.40 * pi)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .refresh:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.78, 0.15 * pi, 1.75 * pi)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx + r * 0.30, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.78, cy - r * 0.55)
            kcairo_line_to(cr, cx + r * 0.42, cy - r * 0.20)
            kcairo_stroke(cr)

        case .chevronLeft:
            kcairo_move_to(cr, cx + r * 0.30, cy - r * 0.68)
            kcairo_line_to(cr, cx - r * 0.38, cy)
            kcairo_line_to(cr, cx + r * 0.30, cy + r * 0.68)
            kcairo_stroke(cr)

        case .chevronRight:
            kcairo_move_to(cr, cx - r * 0.30, cy - r * 0.68)
            kcairo_line_to(cr, cx + r * 0.38, cy)
            kcairo_line_to(cr, cx - r * 0.30, cy + r * 0.68)
            kcairo_stroke(cr)

        case .chevronDown:
            kcairo_move_to(cr, cx - r * 0.68, cy - r * 0.28)
            kcairo_line_to(cr, cx, cy + r * 0.38)
            kcairo_line_to(cr, cx + r * 0.68, cy - r * 0.28)
            kcairo_stroke(cr)

        case .chevronUp:
            kcairo_move_to(cr, cx - r * 0.68, cy + r * 0.28)
            kcairo_line_to(cr, cx, cy - r * 0.38)
            kcairo_line_to(cr, cx + r * 0.68, cy + r * 0.28)
            kcairo_stroke(cr)

        case .search:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx - r * 0.15, cy - r * 0.15, r * 0.58, 0, 2 * pi)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx + r * 0.28, cy + r * 0.28)
            kcairo_line_to(cr, cx + r * 0.85, cy + r * 0.85)
            kcairo_stroke(cr)

        case .bookmark:
            kcairo_move_to(cr, cx - r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy + r * 0.85)
            kcairo_line_to(cr, cx, cy + r * 0.38)
            kcairo_line_to(cr, cx - r * 0.58, cy + r * 0.85)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .check:
            kcairo_move_to(cr, cx - r * 0.72, cy + r * 0.05)
            kcairo_line_to(cr, cx - r * 0.18, cy + r * 0.58)
            kcairo_line_to(cr, cx + r * 0.78, cy - r * 0.52)
            kcairo_stroke(cr)

        case .warning:
            kcairo_move_to(cr, cx, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.88, cy + r * 0.75)
            kcairo_line_to(cr, cx - r * 0.88, cy + r * 0.75)
            kcairo_close_path(cr)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx, cy - r * 0.25)
            kcairo_line_to(cr, cx, cy + r * 0.25)
            kcairo_stroke(cr)
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy + r * 0.50, lw * 0.6, 0, 2 * pi)
            kcairo_fill(cr)

        case .info:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.85, 0, 2 * pi)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx, cy - r * 0.05)
            kcairo_line_to(cr, cx, cy + r * 0.48)
            kcairo_stroke(cr)
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy - r * 0.42, lw * 0.6, 0, 2 * pi)
            kcairo_fill(cr)

        case .book:
            kcairo_move_to(cr, cx, cy - r * 0.65)
            kcairo_line_to(cr, cx, cy + r * 0.75)
            kcairo_move_to(cr, cx, cy - r * 0.65)
            kcairo_line_to(cr, cx - r * 0.85, cy - r * 0.78)
            kcairo_line_to(cr, cx - r * 0.85, cy + r * 0.62)
            kcairo_line_to(cr, cx, cy + r * 0.75)
            kcairo_line_to(cr, cx + r * 0.85, cy + r * 0.62)
            kcairo_line_to(cr, cx + r * 0.85, cy - r * 0.78)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .globe:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.85, 0, 2 * pi)
            kcairo_stroke(cr)
            kcairo_new_path(cr)
            kcairo_arc(cr, cx - r * 0.72, cy, r * 1.12, -0.26 * pi, 0.26 * pi)
            kcairo_stroke(cr)
            kcairo_new_path(cr)
            kcairo_arc(cr, cx + r * 0.72, cy, r * 1.12, 0.74 * pi, 1.26 * pi)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx - r * 0.85, cy)
            kcairo_line_to(cr, cx + r * 0.85, cy)
            kcairo_move_to(cr, cx, cy - r * 0.85)
            kcairo_line_to(cr, cx, cy + r * 0.85)
            kcairo_stroke(cr)

        case .cloud:
            kcairo_rounded_rect(cr, cx - r * 0.85, cy - r * 0.25, r * 1.70, r * 0.85, r * 0.42)
            kcairo_stroke(cr)
            kcairo_new_path(cr)
            kcairo_arc(cr, cx - r * 0.15, cy - r * 0.25, r * 0.45, pi, 2 * pi)
            kcairo_stroke(cr)

        case .gear:
            kcairo_new_path(cr)
            kcairo_arc(cr, cx, cy, r * 0.42, 0, 2 * pi)
            kcairo_stroke(cr)
            for i in 0..<8 {
                let c = (i % 2 == 0) ? ((i == 0) ? 1.0 : (i == 4 ? -1.0 : 0.0)) : ((i == 1 || i == 7) ? 0.7071 : -0.7071)
                let sn = (i % 2 == 0) ? ((i == 2) ? 1.0 : (i == 6 ? -1.0 : 0.0)) : ((i == 1 || i == 3) ? 0.7071 : -0.7071)
                kcairo_move_to(cr, cx + c * r * 0.45, cy + sn * r * 0.45)
                kcairo_line_to(cr, cx + c * r * 0.88, cy + sn * r * 0.88)
            }
            kcairo_stroke(cr)

        case .sliders:
            for row in -1...1 {
                let ry = cy + Double(row) * r * 0.55
                kcairo_move_to(cr, cx - r * 0.82, ry)
                kcairo_line_to(cr, cx + r * 0.82, ry)
                kcairo_stroke(cr)
                let kx = cx + (row == 0 ? r * 0.32 : -r * 0.28)
                kcairo_new_path(cr)
                kcairo_arc(cr, kx, ry, r * 0.18, 0, 2 * pi)
                kcairo_fill(cr)
            }

        case .plus:
            kcairo_move_to(cr, cx - r * 0.72, cy)
            kcairo_line_to(cr, cx + r * 0.72, cy)
            kcairo_move_to(cr, cx, cy - r * 0.72)
            kcairo_line_to(cr, cx, cy + r * 0.72)
            kcairo_stroke(cr)

        case .minus:
            kcairo_move_to(cr, cx - r * 0.72, cy)
            kcairo_line_to(cr, cx + r * 0.72, cy)
            kcairo_stroke(cr)

        case .close:
            kcairo_move_to(cr, cx - r * 0.62, cy - r * 0.62)
            kcairo_line_to(cr, cx + r * 0.62, cy + r * 0.62)
            kcairo_move_to(cr, cx + r * 0.62, cy - r * 0.62)
            kcairo_line_to(cr, cx - r * 0.62, cy + r * 0.62)
            kcairo_stroke(cr)

        case .star:
            kcairo_move_to(cr, cx, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.52, cy + r * 0.75)
            kcairo_line_to(cr, cx - r * 0.82, cy - r * 0.22)
            kcairo_line_to(cr, cx + r * 0.82, cy - r * 0.22)
            kcairo_line_to(cr, cx - r * 0.52, cy + r * 0.75)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .bolt:
            kcairo_move_to(cr, cx + r * 0.12, cy - r * 0.88)
            kcairo_line_to(cr, cx - r * 0.55, cy + r * 0.08)
            kcairo_line_to(cr, cx + r * 0.05, cy + r * 0.08)
            kcairo_line_to(cr, cx - r * 0.12, cy + r * 0.88)
            kcairo_line_to(cr, cx + r * 0.55, cy - r * 0.08)
            kcairo_line_to(cr, cx - r * 0.05, cy - r * 0.08)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .pencil:
            kcairo_move_to(cr, cx - r * 0.78, cy + r * 0.78)
            kcairo_line_to(cr, cx - r * 0.72, cy + r * 0.30)
            kcairo_line_to(cr, cx + r * 0.36, cy - r * 0.78)
            kcairo_line_to(cr, cx + r * 0.78, cy - r * 0.36)
            kcairo_line_to(cr, cx - r * 0.30, cy + r * 0.72)
            kcairo_close_path(cr)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx + r * 0.16, cy - r * 0.58)
            kcairo_line_to(cr, cx + r * 0.58, cy - r * 0.16)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx - r * 0.72, cy + r * 0.30)
            kcairo_line_to(cr, cx - r * 0.30, cy + r * 0.72)
            kcairo_stroke(cr)

        case .share:
            kcairo_move_to(cr, cx - r * 0.42, cy - r * 0.08)
            kcairo_line_to(cr, cx - r * 0.72, cy - r * 0.08)
            kcairo_line_to(cr, cx - r * 0.72, cy + r * 0.80)
            kcairo_line_to(cr, cx + r * 0.72, cy + r * 0.80)
            kcairo_line_to(cr, cx + r * 0.72, cy - r * 0.08)
            kcairo_line_to(cr, cx + r * 0.42, cy - r * 0.08)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx, cy + r * 0.36)
            kcairo_line_to(cr, cx, cy - r * 0.82)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx - r * 0.36, cy - r * 0.44)
            kcairo_line_to(cr, cx, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.36, cy - r * 0.44)
            kcairo_stroke(cr)

        case .folder:
            kcairo_move_to(cr, cx - r * 0.85, cy - r * 0.58)
            kcairo_line_to(cr, cx - r * 0.22, cy - r * 0.58)
            kcairo_line_to(cr, cx - r * 0.02, cy - r * 0.32)
            kcairo_line_to(cr, cx + r * 0.85, cy - r * 0.32)
            kcairo_line_to(cr, cx + r * 0.85, cy + r * 0.68)
            kcairo_line_to(cr, cx - r * 0.85, cy + r * 0.68)
            kcairo_close_path(cr)
            kcairo_stroke(cr)

        case .document:
            kcairo_move_to(cr, cx - r * 0.65, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.25, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.65, cy - r * 0.42)
            kcairo_line_to(cr, cx + r * 0.65, cy + r * 0.82)
            kcairo_line_to(cr, cx - r * 0.65, cy + r * 0.82)
            kcairo_close_path(cr)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx + r * 0.25, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.25, cy - r * 0.42)
            kcairo_line_to(cr, cx + r * 0.65, cy - r * 0.42)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx - r * 0.36, cy + r * 0.05)
            kcairo_line_to(cr, cx + r * 0.36, cy + r * 0.05)
            kcairo_move_to(cr, cx - r * 0.36, cy + r * 0.38)
            kcairo_line_to(cr, cx + r * 0.36, cy + r * 0.38)
            kcairo_stroke(cr)

        case .calendar:
            kcairo_rounded_rect(cr, cx - r * 0.78, cy - r * 0.62, r * 1.56, r * 1.40, r * 0.16)
            kcairo_stroke(cr)
            kcairo_move_to(cr, cx - r * 0.78, cy - r * 0.18)
            kcairo_line_to(cr, cx + r * 0.78, cy - r * 0.18)
            kcairo_move_to(cr, cx - r * 0.38, cy - r * 0.82)
            kcairo_line_to(cr, cx - r * 0.38, cy - r * 0.46)
            kcairo_move_to(cr, cx + r * 0.38, cy - r * 0.82)
            kcairo_line_to(cr, cx + r * 0.38, cy - r * 0.46)
            kcairo_stroke(cr)

        case .bookmarkFill:
            kcairo_move_to(cr, cx - r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy + r * 0.85)
            kcairo_line_to(cr, cx, cy + r * 0.38)
            kcairo_line_to(cr, cx - r * 0.58, cy + r * 0.85)
            kcairo_close_path(cr)
            kcairo_fill(cr)
            kcairo_move_to(cr, cx - r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy - r * 0.85)
            kcairo_line_to(cr, cx + r * 0.58, cy + r * 0.85)
            kcairo_line_to(cr, cx, cy + r * 0.38)
            kcairo_line_to(cr, cx - r * 0.58, cy + r * 0.85)
            kcairo_close_path(cr)
            kcairo_stroke(cr)
        }
    }
}

internal func gtkCairoExposeTrampoline(
    widget: KWidgetRef?,
    cr: KCairoRef?,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    userData: UnsafeMutableRawPointer?
) {
    guard let cr = cr, let userData = userData else { return }
    let target = Unmanaged<GTKCairoTarget>.fromOpaque(userData).takeUnretainedValue()
    target.draw(cr: cr, x: x, y: y, width: width, height: height)
}

internal func gtkCairoDestroyTrampoline(userData: UnsafeMutableRawPointer?) {
    guard let userData = userData else { return }
    Unmanaged<GTKCairoTarget>.fromOpaque(userData).release()
}

extension GTK2Renderer {
    private static let iconOrder: [KindleIconName] = [
        .wifi, .battery, .sun, .moon, .refresh,
        .chevronLeft, .chevronRight, .chevronDown, .chevronUp,
        .search, .bookmark, .check, .warning, .info,
        .book, .globe, .cloud, .gear, .sliders,
        .plus, .minus, .close, .star, .bolt,
        .pencil, .share, .folder, .document, .calendar,
        .bookmarkFill
    ]

    internal func attachCairoTarget(_ target: GTKCairoTarget, to widget: KWidgetRef) {
        let ptr = Unmanaged.passRetained(target).toOpaque()
        switch target.kind {
        case .icon(let icon, let fgGray, let bgGray, let hasBg):
            let iconIdx = UInt64(Self.iconOrder.firstIndex(of: icon) ?? 0) + 1
            let key: UInt64 = (1 << 24)
                | (iconIdx << 17)
                | (UInt64(hasBg ? 1 : 0) << 16)
                | (UInt64(fgGray) << 8)
                | UInt64(bgGray)
            kgtk_connect_cairo_expose_cached(widget, key, bgGray, gtkCairoExposeTrampoline, ptr, gtkCairoDestroyTrampoline)

        case .toggleSwitch(let isOn, let isCheckbox, let fgGray, let bgGray, let trackGray):
            let key: UInt64 = (2 << 24)
                | (UInt64(isOn ? 1 : 0) << 23)
                | (UInt64(isCheckbox ? 1 : 0) << 22)
                | (UInt64(trackGray) << 14)
                | (UInt64(fgGray) << 6)
                | UInt64(bgGray >> 2)
            kgtk_connect_cairo_expose_cached(widget, key, bgGray, gtkCairoExposeTrampoline, ptr, gtkCairoDestroyTrampoline)

        default:
            kgtk_connect_cairo_expose(widget, gtkCairoExposeTrampoline, ptr, gtkCairoDestroyTrampoline)
        }
    }

    internal func buildCairoModalScrim(
        child: KWidgetRef,
        bgGray: UInt8,
        alpha: Double,
        xalign: Float,
        yalign: Float,
        xscale: Float,
        yscale: Float
    ) -> KWidgetRef? {
        guard let align = kgtk_alignment_new(xalign, yalign, xscale, yscale) else { return child }
        kgtk_container_add(align, child)
        attachCairoTarget(GTKCairoTarget(.modalScrim(bgGray: bgGray, alpha: alpha)), to: align)
        return align
    }

    internal func buildCairoSwitch(
        isOn: Bool,
        isCheckbox: Bool,
        fgGray: UInt8,
        bgGray: UInt8,
        trackGray: UInt8
    ) -> KWidgetRef? {
        guard let eb = kgtk_alignment_new(0.5, 0.5, 0.0, 0.0) else { return nil }
        if isCheckbox {
            kgtk_widget_set_size_request(eb, 52, 52)
        } else {
            kgtk_widget_set_size_request(eb, 104, 56)
        }
        attachCairoTarget(
            GTKCairoTarget(.toggleSwitch(isOn: isOn, isCheckbox: isCheckbox, fgGray: fgGray, bgGray: bgGray, trackGray: trackGray)),
            to: eb
        )
        return eb
    }

    internal func buildCairoProgressBar(
        fraction: Double,
        fgGray: UInt8,
        bgGray: UInt8,
        trackGray: UInt8,
        height: Int
    ) -> (widget: KWidgetRef, target: GTKCairoTarget)? {
        guard let eb = kgtk_alignment_new(0.5, 0.5, 1.0, 1.0) else { return nil }
        kgtk_widget_set_size_request(eb, -1, Int32(height > 8 ? height : 28))
        let target = GTKCairoTarget(.progressBar(
            fraction: min(1.0, max(0.0, fraction)),
            fgGray: fgGray,
            bgGray: bgGray,
            trackGray: trackGray
        ))
        attachCairoTarget(target, to: eb)
        return (eb, target)
    }

    internal func buildCairoDivider(
        vertical: Bool,
        thickness: Int,
        grayLevel: UInt8
    ) -> KWidgetRef? {
        guard let eb = kgtk_alignment_new(0.5, 0.5, 1.0, 1.0) else { return nil }
        let t = Int32(thickness > 0 ? thickness : 2)
        if vertical {
            kgtk_widget_set_size_request(eb, t, -1)
        } else {
            kgtk_widget_set_size_request(eb, -1, t)
        }
        attachCairoTarget(GTKCairoTarget(.divider(grayLevel: grayLevel)), to: eb)
        return eb
    }

    internal func buildCairoIcon(
        icon: KindleIconName,
        size: Int,
        fgGray: UInt8,
        bgGray: UInt8,
        hasBg: Bool
    ) -> KWidgetRef? {
        guard let eb = kgtk_alignment_new(0.5, 0.5, 0.0, 0.0) else { return nil }
        let px = Int32(Double(size > 8 ? size : 40) * 1.35)
        kgtk_widget_set_size_request(eb, px, px)
        attachCairoTarget(GTKCairoTarget(.icon(icon: icon, fgGray: fgGray, bgGray: bgGray, hasBg: hasBg)), to: eb)
        return eb
    }
}
