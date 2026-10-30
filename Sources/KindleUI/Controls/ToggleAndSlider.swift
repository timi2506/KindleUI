import Foundation

/// A control that toggles between on and off states, rendered with a Cairo E-Ink switch or checkbox.
public struct Toggle: View, _PrimitiveView {
    public typealias Body = Never
    public let label: String
    public let isOn: Binding<Bool>

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self.isOn = isOn
    }

    public func _makeNode() -> RenderNode {
        .toggle(
            label: label,
            isOn: isOn.wrappedValue,
            onToggle: { newValue in
                isOn.wrappedValue = newValue
            },
            style: ViewStyle()
        )
    }
}



/// A control for selecting a value from a bounded linear range, rendered with a custom Cairo E-Ink track and bullseye thumb.
public struct Slider: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String?
    public let valueLabel: String?
    public let value: Binding<Double>
    public let bounds: ClosedRange<Double>
    public let step: Double

    public init(
        _ title: String? = nil,
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0.0...1.0,
        step: Double = 0.05,
        valueLabel: String? = nil
    ) {
        self.title = title
        self.value = value
        self.bounds = bounds
        self.step = step
        self.valueLabel = valueLabel
    }

    public func _makeNode() -> RenderNode {
        var sliderStyle = ViewStyle()
        sliderStyle.expand = (title != nil || valueLabel != nil)
        sliderStyle.fill = true
        let rawSlider = RenderNode.slider(
            value: value.wrappedValue,
            range: bounds,
            step: step,
            onValueChange: { updated in
                value.wrappedValue = updated
            },
            style: sliderStyle
        )

        if title == nil && valueLabel == nil {
            return rawSlider
        }

        let theme = KindleTheme.current
        var children: [RenderNode] = []
        if let title = title, !title.isEmpty {
            var labelStyle = ViewStyle()
            labelStyle.font = .headline
            labelStyle.foregroundColor = theme.foreground
            children.append(.text(content: title, wrap: false, alignment: .leading, style: labelStyle))
        }
        children.append(rawSlider)
        if let valueLabel = valueLabel, !valueLabel.isEmpty {
            var badgeStyle = ViewStyle()
            badgeStyle.font = .monospaced
            badgeStyle.foregroundColor = theme.foreground
            badgeStyle.backgroundColor = theme.panelBackground
            badgeStyle.borderColor = theme.subtleBorder
            badgeStyle.borderWidth = 1
            badgeStyle.cornerRadius = 14
            badgeStyle.width = 160
            badgeStyle.contentPadding = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            children.append(.text(content: valueLabel, wrap: false, alignment: .center, style: badgeStyle))
        }
        var rowStyle = ViewStyle()
        rowStyle.expand = false
        rowStyle.fill = true
        return .hstack(alignment: .center, spacing: 20, children: children, style: rowStyle)
    }
}

/// A view that shows the progress toward completion of a task, rendered with a Cairo capsule bar.
public struct ProgressView: View, _PrimitiveView {
    public typealias Body = Never
    public let fraction: Double
    public let label: String?

    public init(value: Double, total: Double = 1.0, label: String? = nil) {
        let clampedTotal = max(0.0001, total)
        self.fraction = min(1.0, max(0.0, value / clampedTotal))
        self.label = label
    }

    public init(_ label: String, value: Double, total: Double = 1.0) {
        let clampedTotal = max(0.0001, total)
        self.fraction = min(1.0, max(0.0, value / clampedTotal))
        self.label = label
    }

    public init(_ label: String? = nil) {
        self.fraction = 0.5
        self.label = label.map { "\($0) (Indeterminate)" } ?? "Loading…"
    }

    public func _makeNode() -> RenderNode {
        .progressBar(fraction: fraction, text: label, style: ViewStyle())
    }
}

/// A view that shows a value within a bounded range (`Gauge`), rendered with a labeled E-Ink capsule bar and value badge.
public struct Gauge: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let value: Double
    public let bounds: ClosedRange<Double>
    public let valueLabel: String?

    public init(
        _ title: String,
        value: Double,
        in bounds: ClosedRange<Double> = 0.0...1.0,
        valueLabel: String? = nil
    ) {
        self.title = title
        self.value = value
        self.bounds = bounds
        self.valueLabel = valueLabel
    }

    public func _makeNode() -> RenderNode {
        let span = max(0.0001, bounds.upperBound - bounds.lowerBound)
        let fraction = min(1.0, max(0.0, (value - bounds.lowerBound) / span))
        let displayLabel: String
        if let valueLabel = valueLabel, !valueLabel.isEmpty {
            displayLabel = "\(title) — \(valueLabel)"
        } else {
            displayLabel = title
        }
        return .progressBar(fraction: fraction, text: displayLabel, style: ViewStyle())
    }
}



// MARK: - Stepper

/// A control for incrementing and decrementing a numeric value with crisp rounded `−` and `+` buttons.
public struct Stepper<CenterContent: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let value: Binding<Int>
    public let bounds: ClosedRange<Int>?
    public let step: Int
    public let buttonWidth: Int
    public let buttonHeight: Int?
    public let onChange: ((Int) -> Void)?
    private let centerContent: CenterContent

    public init(
        value: Binding<Int>,
        in bounds: ClosedRange<Int>? = nil,
        step: Int = 1,
        buttonWidth: Int = 104,
        buttonHeight: Int? = nil,
        onChange: ((Int) -> Void)? = nil,
        @ViewBuilder label: () -> CenterContent
    ) {
        self.value = value
        self.bounds = bounds
        self.step = step
        self.buttonWidth = buttonWidth
        self.buttonHeight = buttonHeight
        self.onChange = onChange
        self.centerContent = label()
    }

    public func _makeNode() -> RenderNode {
        return HStack(alignment: .center, spacing: 18) {
            Button("−") {
                var next = value.wrappedValue - step
                if let bounds = bounds {
                    next = max(bounds.lowerBound, min(bounds.upperBound, next))
                }
                value.wrappedValue = next
                onChange?(next)
            }
            .font(.system(size: 20, weight: .bold))
            .buttonStyle(.bordered)
            .cornerRadius(16)
            .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
            .frame(width: buttonWidth, height: buttonHeight)

            Spacer()

            centerContent

            Spacer()

            Button("+") {
                var next = value.wrappedValue + step
                if let bounds = bounds {
                    next = max(bounds.lowerBound, min(bounds.upperBound, next))
                }
                value.wrappedValue = next
                onChange?(next)
            }
            .font(.system(size: 20, weight: .bold))
            .buttonStyle(.bordered)
            .cornerRadius(16)
            .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
            .frame(width: buttonWidth, height: buttonHeight)
        }
        .buildRenderTree()
    }
}

extension Stepper where CenterContent == Text {
    /// Creates a standard labeled `Stepper`.
    public init(
        _ title: String,
        value: Binding<Int>,
        in bounds: ClosedRange<Int>? = nil,
        step: Int = 1,
        onChange: ((Int) -> Void)? = nil
    ) {
        self.init(
            value: value,
            in: bounds,
            step: step,
            buttonWidth: 120,
            buttonHeight: nil,
            onChange: onChange
        ) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
}



// MARK: - 9. ControlGroup & ColorPicker (16-Shade E-Ink Palette)

/// A container view that displays semantically-related controls in a visually-appropriate grouped strip.
public struct ControlGroup<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        return HStack(alignment: .center, spacing: 8) {
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.trailing, 8)
            }
            HStack(alignment: .center, spacing: 8, homogeneous: true) {
                content
            }
            .expand(true, fill: true)
        }
        .padding(8)
        .background(theme.panelBackground, cornerRadius: 16)
        .buildRenderTree()
    }
}
