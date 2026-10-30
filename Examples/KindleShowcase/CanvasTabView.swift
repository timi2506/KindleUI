import Foundation
import KindleUI

// MARK: - Tab 3: Canvas, Shapes & Grayscale Palette

extension KindleShowcaseRootView {
    internal func canvasTab(theme: KindleTheme) -> some View {
        let fourColumns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 4)
        let eightColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)

        return VStack(alignment: .leading, spacing: 22) {
            // Section 1: Sketchpad
            Surface("Sketchpad") {
                HStack(alignment: .center, spacing: 10) {
                    Button("Thin") { penThickness = 2 }
                        .buttonStyle(penThickness == 2 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Button("Medium") { penThickness = 4 }
                        .buttonStyle(penThickness == 4 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Button("Bold") { penThickness = 8 }
                        .buttonStyle(penThickness == 8 ? .borderedProminent : .bordered)
                        .controlSize(.small)

                    Spacer()

                    Button("Wave") {
                        stampSineWave()
                        strokeCount += 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Invert") {
                        sketchBuffer.invert()
                        strokeCount += 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Clear") {
                        sketchBuffer.clear(fill: 255)
                        strokeCount = 0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                KindleCanvas(
                    buffer: sketchBuffer,
                    label: "SketchPad",
                    onPrepare: { w, h in
                        sketchBuffer.resizeIfNeeded(width: w, height: h)
                        if w != sketchSeededWidth && strokeCount == 0 {
                            sketchSeededWidth = w
                            seedDefaultSketch()
                        }
                    },
                    onPointer: { phase, x, y in
                        struct Holder { static var lastPt: (Int, Int)? = nil }
                        switch phase {
                        case 0:
                            Holder.lastPt = (x, y)
                            return sketchBuffer.drawBrush(x: x, y: y, radius: penThickness, gray: 0)
                        case 1:
                            let prev = Holder.lastPt ?? (x, y)
                            Holder.lastPt = (x, y)
                            return sketchBuffer.drawLine(fromX: prev.0, fromY: prev.1, toX: x, toY: y, radius: penThickness, gray: 0)
                        default:
                            Holder.lastPt = nil
                            strokeCount += 1
                            return nil
                        }
                    }
                )
                .frame(height: 280)
                .border(theme.border, width: 1, cornerRadius: 12)
            }

            // Section 2: Vector Shapes (Single Clean Row of 4 Shapes)
            Surface("Vector Shapes") {
                LazyVGrid(columns: fourColumns, spacing: 16) {
                    VStack(alignment: .center, spacing: 8) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.foreground)
                            .frame(height: 56)
                        Text("Rounded")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .center, spacing: 8) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 24,
                            topTrailingRadius: 4
                        )
                        .fill(theme.mutedForeground)
                        .frame(height: 56)
                        Text("Uneven")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .center, spacing: 8) {
                        Capsule()
                            .stroke(theme.foreground, lineWidth: 3)
                            .frame(height: 56)
                        Text("Capsule")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .center, spacing: 8) {
                        Circle()
                            .fill(theme.foreground)
                            .frame(width: 56, height: 56)
                        Text("Circle")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            // Section 3: E-Ink Grayscale Palette (Single Row of 8 Shades)
            Surface("E-Ink Grayscale Palette") {
                let shades: [(String, EInkColor)] = [
                    ("#00", .shade0),
                    ("#22", .shade2),
                    ("#44", .shade4),
                    ("#66", .shade6),
                    ("#99", .shade9),
                    ("#BB", .shade11),
                    ("#DD", .shade13),
                    ("#FF", .shade15)
                ]
                LazyVGrid(columns: eightColumns, spacing: 12) {
                    ForEach(Array(shades.enumerated()), id: \.offset) { _, pair in
                        VStack(alignment: .center, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(pair.1)
                                .border(theme.border, width: 1, cornerRadius: 8)
                                .frame(height: 44)
                            Text(pair.0)
                                .font(.caption.monospacedDigit())
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }

            Spacer()
        }
        .expand(true, fill: true)
    }

    internal func seedDefaultSketch() {
        let w = sketchBuffer.width
        let h = sketchBuffer.height
        sketchBuffer.clear(fill: 255)
        sketchBuffer.drawRect(
            fromX: 12,
            fromY: 12,
            toX: w - 12,
            toY: h - 12,
            radius: 2,
            gray: 180,
            filled: false
        )
        let cy = h / 2
        let r = max(24, min(52, (h - 48) / 2))
        let cx = max(80, w / 7)
        sketchBuffer.drawCircle(centerX: cx, centerY: cy, circleRadius: r, strokeRadius: 2, gray: 210, filled: true)
        sketchBuffer.drawCircle(centerX: cx, centerY: cy, circleRadius: r, strokeRadius: 2, gray: 0, filled: false)

        let rx0 = cx + r + 36
        let rx1 = rx0 + max(90, w / 6)
        let ry0 = cy - r
        let ry1 = cy + r
        sketchBuffer.drawRect(fromX: rx0, fromY: ry0, toX: rx1, toY: ry1, radius: 2, gray: 190, filled: true)
        sketchBuffer.drawRect(fromX: rx0, fromY: ry0, toX: rx1, toY: ry1, radius: 2, gray: 0, filled: false)
        stampSineWave()
    }

    internal func stampSineWave() {
        let w = sketchBuffer.width
        let h = sketchBuffer.height
        let midY = h / 2
        let amp = Double(max(20, (h - 56) / 2))
        let startX = max(280, (w * 9) / 20)
        let endX = max(startX + 40, w - 32)
        var prevX = startX
        var prevY = midY
        for x in stride(from: startX + 4, to: endX, by: 4) {
            let progress = Double(x - startX) / Double(max(1, endX - startX))
            let angle = progress * 6.2831853 * 2.5
            let y = midY + Int(sin(angle) * amp)
            sketchBuffer.drawLine(fromX: prevX, fromY: prevY, toX: x, toY: y, radius: 2, gray: 0)
            prevX = x
            prevY = y
        }
    }
}
