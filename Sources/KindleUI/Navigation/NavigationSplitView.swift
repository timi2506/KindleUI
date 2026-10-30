import Foundation

/// The visibility of the leading columns in a `NavigationSplitView`.
public enum NavigationSplitViewVisibility: String, CaseIterable, Sendable, Equatable, AppStorageConvertible {
    case automatic
    case all
    case doubleColumn
    case detailOnly

    public func toAppStorageString() -> String { rawValue }
    public static func fromAppStorageString(_ raw: String) -> NavigationSplitViewVisibility? {
        NavigationSplitViewVisibility(rawValue: raw)
    }
}

/// A view that presents views in two or three columns, where selections in leading columns control presentations in subsequent columns.
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View, _PrimitiveView {
    public typealias Body = Never
    private let columnVisibility: Binding<NavigationSplitViewVisibility>?
    private let sidebarWidth: Int
    private let contentWidth: Int
    private let hasMiddleColumn: Bool
    private let sidebar: () -> Sidebar
    private let content: () -> Content
    private let detail: () -> Detail

    /// Creates a two-column split view with a sidebar and a detail column.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        sidebarWidth: Int = 0,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) where Content == EmptyView {
        self.columnVisibility = columnVisibility
        self.sidebarWidth = sidebarWidth
        self.contentWidth = 0
        self.hasMiddleColumn = false
        self.sidebar = sidebar
        self.content = { EmptyView() }
        self.detail = detail
    }

    /// Creates a three-column split view with a sidebar, middle content column, and detail column.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil,
        sidebarWidth: Int = 0,
        contentWidth: Int = 0,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.columnVisibility = columnVisibility
        self.sidebarWidth = sidebarWidth
        self.contentWidth = contentWidth
        self.hasMiddleColumn = true
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
    }

    public func _makeNode() -> RenderNode {
        let theme = KindleTheme.current
        let fallbackVisBox = KindleStateRegistry.shared.obtainBox(
            siteKey: "split-vis",
            initialValue: { NavigationSplitViewVisibility.all }
        )
        let vis = columnVisibility?.wrappedValue ?? fallbackVisBox.value
        let showSidebar = (vis != .detailOnly)
        let showMiddle = hasMiddleColumn && (vis == .all || vis == .automatic || vis == .doubleColumn)

        let toggleButton = Button(showSidebar ? "Hide Sidebar" : "Show Sidebar") {
            let next: NavigationSplitViewVisibility = showSidebar ? .detailOnly : .all
            if let binding = columnVisibility {
                binding.wrappedValue = next
            } else {
                fallbackVisBox.value = next
                KindleStateRegistry.shared.notifyStateMutation()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)

        return HStack(alignment: .top, spacing: 16) {
            if showSidebar {
                VStack(alignment: .leading, spacing: 10) {
                    sidebar()
                }
                .padding(18)
                .background(theme.cardBackground, cornerRadius: 16)
                .border(theme.subtleBorder, width: 1, cornerRadius: 16)
                .frame(width: sidebarWidth > 0 ? sidebarWidth : nil)
                .expand(false, fill: true)
            }

            if showMiddle {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(18)
                .background(theme.cardBackground, cornerRadius: 16)
                .border(theme.subtleBorder, width: 1, cornerRadius: 16)
                .frame(width: contentWidth > 0 ? contentWidth : nil)
                .expand(false, fill: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                if !showSidebar {
                    HStack(alignment: .center, spacing: 10) {
                        toggleButton
                        Spacer()
                    }
                }
                detail()
            }
            .padding(22)
            .background(theme.cardBackground, cornerRadius: 16)
            .border(theme.subtleBorder, width: 1, cornerRadius: 16)
            .expand(true, fill: true)
        }
        .expand(false, fill: true)
        .buildRenderTree()
    }
}

extension View {
    /// Presents a trailing slide-over Inspector drawer when `isPresented` is `true`.
    public func inspector<InspectorContent: View>(
        isPresented: Binding<Bool>,
        columnWidth: Int = 560,
        @ViewBuilder content: @escaping () -> InspectorContent
    ) -> some View {
        let theme = KindleTheme.current
        let effectiveWidth = max(480, columnWidth)
        return ModalOverlayView(isPresented: isPresented, alignment: .trailing, upstream: self) {
            HStack(alignment: .top, spacing: 0) {
                // Dimmed left backdrop: tapping outside closes the inspector drawer
                VStack(alignment: .center, spacing: 8) {
                    Spacer()
                    Badge("Tap outside to close Inspector")
                    Spacer()
                }
                .expand(true, fill: true)
                .onTapGesture {
                    isPresented.wrappedValue = false
                }

                // Right-docked Inspector panel
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Icon(.sliders, size: 36)
                        Text("Inspector")
                            .font(.title2)
                        Spacer()
                        Button("Close ✕") {
                            isPresented.wrappedValue = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Divider(thickness: 1, color: theme.subtleBorder)
                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            content()
                        }
                        .padding(.trailing, 8)
                    }
                    .expand(true, fill: true)
                }
                .padding(EdgeInsets(top: 22, leading: 24, bottom: 22, trailing: 24))
                .background(theme.cardBackground, cornerRadius: 24)
                .border(theme.border, width: 2, cornerRadius: 24)
                .frame(width: effectiveWidth)
                .expand(false, fill: true)
            }
            .expand(true, fill: true)
        }
    }
}
