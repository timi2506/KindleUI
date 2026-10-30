import Foundation

// MARK: - Section & Form

/// A themed E-Ink card section with an optional header and crisp Cairo rounded border + offset shadow.
public struct Section<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let header: String?
    public let footer: String?
    private let content: Content

    public init(
        _ header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let cardBody = VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(EdgeInsets(top: 22, leading: 26, bottom: 22, trailing: 26))
        .background(theme.cardBackground, cornerRadius: 20)
        .border(theme.subtleBorder, width: 1, cornerRadius: 20)

        if header == nil && footer == nil {
            return cardBody
                .padding(.horizontal, 32)
                .buildRenderTree()
        }

        return VStack(alignment: .leading, spacing: 12) {
            if let header = header, !header.isEmpty {
                Text(header.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.mutedForeground)
                    .padding(.leading, 8)
            }
            cardBody
            if let footer = footer, !footer.isEmpty {
                Text(footer)
                    .font(.footnote)
                    .foregroundColor(theme.mutedForeground)
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 32)
        .buildRenderTree()
    }
}

/// A scrollable container for grouping `Section` and control views on an E-Ink page.
public struct Form<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 28) {
                content
            }
            .padding(.vertical, 6)
        }
        .expand(true, fill: true)
        .buildRenderTree()
    }
}



/// A high-contrast E-Ink framed section or card (`gtk_frame_new`).
public struct KindleCard<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        .card(title: title, child: content.buildRenderTree(), style: ViewStyle())
    }
}


/// A stylized view, with an optional label, that visually collects a logical grouping of content.
public struct GroupBox<LabelView: View, Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let titleText: String?
    private let labelView: LabelView?
    private let content: Content

    public init(
        _ titleKey: String,
        @ViewBuilder content: () -> Content
    ) where LabelView == EmptyView {
        self.titleText = titleKey
        self.labelView = nil
        self.content = content()
    }

    public init(
        @ViewBuilder content: () -> Content
    ) where LabelView == EmptyView {
        self.titleText = nil
        self.labelView = nil
        self.content = content()
    }

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> LabelView
    ) {
        self.titleText = nil
        self.labelView = label()
        self.content = content()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        return VStack(alignment: .leading, spacing: 10) {
            if let labelView = labelView {
                labelView
                    .font(.headline)
                Divider(thickness: 1, color: theme.subtleBorder)
            } else if let titleText = titleText, !titleText.isEmpty {
                Text(titleText)
                    .font(.headline)
                    .foregroundColor(theme.foreground)
                Divider(thickness: 1, color: theme.subtleBorder)
            }
            content
        }
        .padding(16)
        .background(theme.panelBackground, cornerRadius: 16)
        .border(theme.subtleBorder, width: 1, cornerRadius: 16)
        .buildRenderTree()
    }
}



// MARK: - DisclosureGroup (Collapsible E-Ink Accordion)

/// A view that shows or hides another content view, based on the state of a disclosure control.
public struct DisclosureGroup<Content: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let isExpanded: Binding<Bool>
    private let content: () -> Content

    public init(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isExpanded = isExpanded
        self.content = content
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let expanded = isExpanded.wrappedValue
        let binding = isExpanded

        return VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                binding.wrappedValue.toggle()
            }) {
                HStack(alignment: .center, spacing: 16) {
                    Icon(expanded ? .chevronDown : .chevronRight, size: 38)
                        .foregroundColor(theme.foreground)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(theme.foreground)
                    Spacer()
                    Badge(expanded ? "Hide" : "Show")
                }
            }
            .buttonStyle(.plain)
            .expand(false, fill: true)

            if expanded {
                Divider(thickness: 1, color: theme.subtleBorder)
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .padding(.leading, 12)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .background(theme.panelBackground, cornerRadius: 16)
        .border(theme.subtleBorder, width: 1, cornerRadius: 16)
        .buildRenderTree()
    }
}



// MARK: - ContentUnavailableView & AsyncImage

/// A standard view for displaying empty states, search misses, or offline errors on E-Ink.
public struct ContentUnavailableView: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let icon: KindleIconName
    public let description: String?
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        _ title: String,
        icon: KindleIconName = .info,
        description: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        return VStack(alignment: .center, spacing: 18) {
            Icon(icon, size: 80)
                .foregroundColor(theme.foreground)

            Text(title)
                .multilineTextAlignment(.center)
                .font(.title2)
                .foregroundColor(theme.foreground)

            if let description = description, !description.isEmpty {
                Text(description)
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(theme.mutedForeground)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .cornerRadius(999)
                    .expand(false, fill: false)
            }
        }
        .padding(EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28))
        .background(theme.panelBackground, cornerRadius: 20)
        .border(theme.subtleBorder, width: 1, cornerRadius: 20)
        .expand(false, fill: true)
        .buildRenderTree()
    }
}


// MARK: - High-Level Kindle Chrome Views

/// Standard Kindle application top status bar showing the app title, optional subtitle badge,
/// live battery percentage, and local clock followed by a crisp divider.
public struct KindleStatusBar: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let dev = KindleDevice.shared
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.foreground)

                if let subtitle = subtitle {
                    Badge(subtitle)
                }

                Spacer()

                Badge("\(dev.batteryLevel)%  ·  \(dev.clockTimeString)", prominent: true)
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))

            Divider(thickness: 1, color: theme.subtleBorder)
        }
        .buildRenderTree()
    }
}

/// Standard Kindle Serif page header with an optional italic subtitle and optional trailing action controls.
public struct KindlePageHeader<TrailingContent: View>: View, _PrimitiveView {
    public typealias Body = Never
    public let title: String
    public let subtitle: String?
    private let trailingContent: TrailingContent?

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingContent = trailing()
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        if let trailingContent = trailingContent {
            return VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 18) {
                    Text(title)
                        .font(.largeTitle)
                        .foregroundColor(theme.foreground)
                    Spacer()
                    trailingContent
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .lineWrap(true)
                        .font(.subheadline)
                        .foregroundColor(theme.mutedForeground)
                }
            }
            .padding(.horizontal, 4)
            .buildRenderTree()
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .foregroundColor(theme.foreground)
            if let subtitle = subtitle {
                Text(subtitle)
                    .lineWrap(true)
                    .font(.subheadline)
                    .foregroundColor(theme.mutedForeground)
            }
        }
        .padding(.horizontal, 4)
        .buildRenderTree()
    }
}

extension KindlePageHeader where TrailingContent == EmptyView {
    /// Creates a `KindlePageHeader` without trailing action controls.
    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailingContent = nil
    }
}
