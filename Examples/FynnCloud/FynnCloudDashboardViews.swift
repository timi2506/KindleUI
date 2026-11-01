import Foundation
import KindleUI

// MARK: - Shared iOS Inset-Grouped Form Helpers (SettingsRowLabel & Section Cards)

extension FynnCloudRootView {
    /// Ported 1:1 from `SettingsRowLabel` in `AccountTab.swift` / `SettingsTab.swift` / `DebugTab.swift`:
    /// 28x28 rounded-square colored badge (`cornerRadius: 7`) with a white icon on the left + row title.
    internal func iosSettingsRowLabel(
        title: String,
        icon: KindleIconName,
        badgeColor: EInkColor,
        theme: FynnCloudTheme
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .center, spacing: 0) {
                Icon(icon, size: 22)
                    .foregroundColor(theme.cardBg)
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            .background(badgeColor, cornerRadius: 12)
            .expand(false, fill: false)

            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(theme.primaryInk)
                .expand(false, fill: false)
        }
    }

    internal func iosSectionHeader(_ title: String, theme: FynnCloudTheme) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(theme.mutedInk)
            .padding(EdgeInsets(top: 4, leading: 12, bottom: 2, trailing: 12))
    }

    internal func iosSectionFooter(_ text: String, theme: FynnCloudTheme) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(theme.mutedInk)
            .padding(EdgeInsets(top: 2, leading: 12, bottom: 4, trailing: 12))
    }
}

// MARK: - Activity Tab + ActivityDetailPane Sheet (Ported 1:1 from ActivityTab.swift & ActivityDetailPane.swift)

extension FynnCloudRootView {
    internal func activityTabView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let allItems = store.activities

        return VStack(alignment: .leading, spacing: 0) {
            if store.isLoadingActivities {
                VStack(alignment: .center, spacing: 14) {
                    Spacer()
                    Text("Loading Activity…")
                        .font(.system(size: 15))
                        .foregroundColor(theme.secondaryInk)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .expand(true, fill: true)
            } else if allItems.isEmpty {
                emptyActivityState(theme: theme)
                    .expand(true, fill: true)
            } else {
                ScrollView(showsIndicators: false) {
                    // Single iOS .insetGrouped white card container with dividers between ActivityCard rows
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(allItems.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 {
                                Divider()
                            }
                            iosActivityCardRow(item: item, theme: theme)
                        }
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }

    internal func emptyActivityState(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .center, spacing: 12) {
            Spacer()
            Icon(.clock, size: 36)
                .foregroundColor(theme.mutedInk)
            Text("No Recent Activity")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryInk)
                .multilineTextAlignment(.center)
            Text("File changes will appear here")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryInk)
                .multilineTextAlignment(.center)

            Button(action: {
                store.isMockDataEnabled = true
                store.mockScenario = .standard
                store.applyMockData()
                store.notifyUI()
            }) {
                Text("Load Sample Activity")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(.capsule)
            .controlSize(.small)
            Spacer()
        }
        .expand(true, fill: true)
    }

    /// Ported 1:1 from `ActivityCard` in `ActivityTab.swift` (lines 506-563):
    /// - 40x40 rounded squircle (`cornerRadius: 10`) with tinted background + colored icon
    /// - Filename (`15pt medium`, single line — no uppercase pill badge!)
    /// - Subtitle: `author • eventDescription` (if not authored by current user) or `eventDescription`
    /// - Right side: `relativeTime` (`12pt`) + `chevronRight` (`12pt`)
    internal func iosActivityCardRow(item: ActivityItem, theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let badgeColor = item.eventType.accentColor(theme: theme)
        let badgeTint = item.eventType.badgeTint(theme: theme)
        let isMyself = item.isAuthoredByMe(
            currentUserId: store.currentUser?.id,
            currentUsername: store.currentUser?.username ?? store.activeAccount?.username
        )
        let iconToDraw: KindleIconName = {
            if item.isFolder && !item.eventType.isSharingEvent && item.eventType != .trash && item.eventType != .restore {
                return .folder
            }
            return item.eventType.icon
        }()

        return Button(action: {
            store.selectedActivityId = item.id
            showActivityDetailSheet = true
            store.notifyUI()
        }) {
            HStack(alignment: .center, spacing: 14) {
                // 40x40 Tinted Squircle Icon
                VStack(alignment: .center, spacing: 0) {
                    Icon(iconToDraw, size: 24)
                        .foregroundColor(badgeColor)
                }
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                .background(badgeTint, cornerRadius: 15)
                .expand(false, fill: false)

                // Filename + Event Description
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.fileName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.primaryInk)
                        .lineLimit(1)

                    if !isMyself, let author = item.user?.effectiveName {
                        HStack(alignment: .center, spacing: 5) {
                            Text(author)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(badgeColor)
                                .expand(false, fill: false)
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(theme.mutedInk)
                                .expand(false, fill: false)
                            Text(item.humanizedSummary)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryInk)
                                .lineLimit(1)
                        }
                    } else {
                        Text(item.humanizedSummary)
                            .font(.system(size: 13))
                            .foregroundColor(theme.secondaryInk)
                            .lineLimit(1)
                    }
                }
                .expand(true, fill: true)

                // Relative Time + Chevron Right
                HStack(alignment: .center, spacing: 6) {
                    Text(item.relativeTimeText)
                        .font(.system(size: 12))
                        .foregroundColor(theme.mutedInk)
                        .expand(false, fill: false)
                    Icon(.chevronRight, size: 13)
                        .foregroundColor(theme.mutedInk)
                }
                .expand(false, fill: false)
            }
            .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
        }
        .buttonStyle(.plain)
    }

    /// Ported 1:1 from `ActivityDetailPane.swift` (lines 58-206):
    /// Presented as a sheet when tapping an `ActivityCard` row in portrait/iOS mode.
    internal func activityDetailSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let item = store.selectedActivity ?? store.activities.first ?? ActivityItem(
            id: "fallback",
            fileId: "f-1",
            fileName: "FynnCloud_Architecture_2026.pdf",
            isFolder: false,
            eventType: .modify,
            createdAt: Date()
        )
        let accent = item.eventType.accentColor(theme: theme)
        let tint = item.eventType.badgeTint(theme: theme)
        let isMyself = item.isAuthoredByMe(
            currentUserId: store.currentUser?.id,
            currentUsername: store.currentUser?.username ?? store.activeAccount?.username
        )
        let summaryText = item.naturalSummary(
            currentUserId: store.currentUser?.id,
            currentUsername: store.currentUser?.username ?? store.activeAccount?.username
        )

        return VStack(alignment: .leading, spacing: 18) {
            // Hero Section (60x60 squircle + filename + natural-language summary + full-width "Open in Files" button)
            VStack(alignment: .center, spacing: 10) {
                VStack(alignment: .center, spacing: 0) {
                    Icon(item.isFolder ? .folder : item.eventType.icon, size: 34)
                        .foregroundColor(accent)
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .background(tint, cornerRadius: 20)
                .expand(false, fill: false)

                Text(item.fileName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryInk)
                    .multilineTextAlignment(.center)

                Text(summaryText)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryInk)
                    .multilineTextAlignment(.center)

                if item.eventType != .delete && item.eventType != .trash {
                    Button(action: {
                        showActivityDetailSheet = false
                        store.filesFilter = .all
                        if let match = store.files.first(where: { $0.id == item.fileId || $0.name == item.fileName }) {
                            store.selectedFileId = match.id
                        }
                        showFilesSheet = true
                        store.notifyUI()
                    }) {
                        HStack(alignment: .center, spacing: 8) {
                            Spacer()
                            Icon(.folder, size: 16)
                                .foregroundColor(theme.primaryInk)
                            Text("Open in Files")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.primaryInk)
                                .expand(false, fill: false)
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .background(theme.cardBg, cornerRadius: 12)
                        .border(theme.borderSubtle, width: 1, cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .expand(true, fill: true)

            // "Details" Inset-Grouped Section
            VStack(alignment: .leading, spacing: 6) {
                iosSectionHeader("Details", theme: theme)

                VStack(alignment: .leading, spacing: 0) {
                    if let author = item.user {
                        iosLabeledDetailRow(
                            label: "Changed By",
                            icon: .user,
                            value: isMyself ? "\(author.effectiveName) (You)" : author.effectiveName,
                            theme: theme
                        )
                        Divider()
                    } else if item.eventType == .publicDownload {
                        iosLabeledDetailRow(
                            label: "Changed By",
                            icon: .globe,
                            value: "Anonymous (Public Link)",
                            theme: theme
                        )
                        Divider()
                    }

                    if let target = item.targetUsername, !target.isEmpty {
                        let roleSuffix = item.shareRole.map { " (\($0.capitalized))" } ?? ""
                        iosLabeledDetailRow(
                            label: "Shared With",
                            icon: .user,
                            value: "\(target)\(roleSuffix)",
                            theme: theme
                        )
                        Divider()
                    }

                    if item.eventType == .rename, let oldName = item.oldName, !oldName.isEmpty {
                        iosLabeledDetailRow(
                            label: "Previous Name",
                            icon: .pencil,
                            value: oldName,
                            theme: theme
                        )
                        Divider()
                    }

                    iosLabeledDetailRow(
                        label: "Kind",
                        icon: item.isFolder ? .folder : .document,
                        value: item.fileKind,
                        theme: theme
                    )

                    if let sz = item.formattedSize {
                        Divider()
                        iosLabeledDetailRow(
                            label: "Size",
                            icon: .server,
                            value: sz,
                            theme: theme
                        )
                    }

                    if let path = item.path, !path.isEmpty {
                        Divider()
                        iosLabeledDetailRow(
                            label: "Location",
                            icon: .folder,
                            value: path,
                            theme: theme
                        )
                    }

                    Divider()
                    iosLabeledDetailRow(
                        label: "Date",
                        icon: .calendar,
                        value: item.fullDateText,
                        theme: theme
                    )
                }
                .background(theme.cardBg, cornerRadius: 16)
                .border(theme.borderSubtle, width: 1, cornerRadius: 16)
            }

            HStack {
                Spacer()
                Button("Done") {
                    showActivityDetailSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .cornerRadius(999)
            }
        }
        .padding(16)
    }

    internal func iosLabeledDetailRow(
        label: String,
        icon: KindleIconName,
        value: String,
        theme: FynnCloudTheme
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Icon(icon, size: 16)
                .foregroundColor(theme.secondaryInk)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.primaryInk)
                .expand(false, fill: false)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryInk)
                .lineLimit(1)
                .expand(false, fill: false)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    }
}

// MARK: - Account Tab (Ported 1:1 from AccountTab.swift)

extension FynnCloudRootView {
    internal func accountTabView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let user = store.currentUser ?? UserInfo(
            id: "u-default",
            username: store.activeAccount?.username ?? "thilo",
            email: store.activeAccount?.email ?? "thilo@fynncloud.ch",
            displayName: "Thilo"
        )
        let quota = store.currentQuota ?? UserQuota(
            limit: 50 * 1024 * 1024 * 1024,
            used: 32 * 1024 * 1024 * 1024,
            percentage: 64.0,
            tierName: "Pro 50 GB"
        )
        let activeHost = store.activeAccount?.serverHostLabel ?? (URL(string: store.serverUrlInput)?.host ?? "cloud.fynncloud.ch")

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: User Identity Card (AppAvatar .lg + Display Name + Username + Email + Host)
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .center, spacing: 0) {
                        Icon(.user, size: 34)
                            .foregroundColor(theme.cardBg)
                    }
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .background(theme.brandAccent, cornerRadius: 999)
                    .expand(false, fill: false)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(user.effectiveName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(theme.primaryInk)
                                .expand(false, fill: false)
                            if user.effectiveName.lowercased() != user.username.lowercased() {
                                Text(user.username)
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondaryInk)
                                    .expand(false, fill: false)
                            }
                        }

                        if !user.email.isEmpty {
                            Text(user.email)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryInk)
                        }

                        Text(activeHost)
                            .font(.system(size: 12))
                            .foregroundColor(theme.mutedInk)
                    }
                    .expand(true, fill: true)
                }
                .padding(16)
                .background(theme.cardBg, cornerRadius: 16)
                .border(theme.borderSubtle, width: 1, cornerRadius: 16)

                // Section 2: Storage Section
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Storage", theme: theme)

                    VStack(alignment: .leading, spacing: 10) {
                        if quota.isUnlimited {
                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Server Storage",
                                    icon: .server,
                                    badgeColor: theme.brandAccent,
                                    theme: theme
                                )
                                Spacer()
                                Text("\(quota.formattedUsed) (Unlimited)")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.secondaryInk)
                                    .expand(false, fill: false)
                            }
                        } else {
                            let pct = max(0.0, min(100.0, quota.percentage))
                            let availableBytes = max(0, quota.limit - quota.used)
                            let availableStr = FynnCloudFormatting.formatBytes(availableBytes)
                            let barColor: EInkColor = pct >= 90 ? theme.dangerColor : (pct >= 75 ? theme.warningColor : theme.brandAccent)

                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Storage",
                                    icon: .server,
                                    badgeColor: barColor,
                                    theme: theme
                                )
                                Spacer()
                                Text("\(quota.formattedUsed) of \(quota.formattedLimit)")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.secondaryInk)
                                    .expand(false, fill: false)
                            }

                            ProgressView(value: pct / 100.0)
                                .foregroundColor(barColor)

                            HStack {
                                Text("\(availableStr) Available (\(Int(pct))%)")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.secondaryInk)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }

                // Section 3: Cloud Services (FynnCloud Folder & Web Portal)
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        showFilesSheet = true
                    }) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "\(store.instanceName) Folder",
                                icon: .folder,
                                badgeColor: .royalBlue,
                                theme: theme
                            )
                            Spacer()
                            Icon(.chevronRight, size: 13)
                                .foregroundColor(theme.mutedInk)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button(action: {
                        openOAuthBrowser()
                    }) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Web Portal",
                                icon: .globe,
                                badgeColor: .plumPurple,
                                theme: theme
                            )
                            Spacer()
                            Text(activeHost)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                            Icon(.upload, size: 13)
                                .foregroundColor(theme.mutedInk)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                    }
                    .buttonStyle(.plain)
                }
                .background(theme.cardBg, cornerRadius: 16)
                .border(theme.borderSubtle, width: 1, cornerRadius: 16)

                // Section 4: Accounts Switcher + Add Account…
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Accounts", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(store.accounts.enumerated()), id: \.element.id) { idx, acct in
                            if idx > 0 {
                                Divider()
                            }
                            let isCurrent = (acct.accountId == store.activeAccount?.accountId)
                            Button(action: {
                                if !isCurrent {
                                    store.switchAccount(to: acct.accountId)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 14) {
                                    VStack(alignment: .center, spacing: 0) {
                                        Icon(.user, size: 22)
                                            .foregroundColor(theme.cardBg)
                                    }
                                    .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                                    .background(theme.brandAccent, cornerRadius: 999)
                                    .expand(false, fill: false)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acct.displayLabel)
                                            .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                            .foregroundColor(theme.primaryInk)
                                        Text("\(acct.username ?? acct.displayLabel) • \(acct.serverHostLabel)")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondaryInk)
                                    }
                                    .expand(true, fill: true)

                                    if isCurrent {
                                        Icon(.check, size: 18)
                                            .foregroundColor(theme.successColor)
                                    }
                                }
                                .padding(EdgeInsets(top: 11, leading: 16, bottom: 11, trailing: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        if !store.accounts.isEmpty {
                            Divider()
                        }

                        Button(action: {
                            store.isSetupCompleted = false
                            store.wizardStep = .welcome
                            store.notifyUI()
                        }) {
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .center, spacing: 0) {
                                    Icon(.plus, size: 22)
                                        .foregroundColor(theme.brandAccent)
                                }
                                .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                                .background(theme.brandSoftTint, cornerRadius: 12)
                                .expand(false, fill: false)

                                Text("Add Account…")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.brandAccent)
                                    .expand(false, fill: false)
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)

                    iosSectionFooter("Switch between registered accounts or add a new self-hosted cloud connection.", theme: theme)
                }

                // Section 5: Sign Out…
                Button(action: {
                    store.signOutActiveAccount()
                }) {
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Text("Sign Out…")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(theme.dangerColor)
                            .expand(false, fill: false)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }
                .buttonStyle(.plain)
            }
        }
        .expand(true, fill: true)
    }
}

// MARK: - Settings Tab (Ported 1:1 from SettingsTab.swift)

extension FynnCloudRootView {
    internal func settingsTabView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let activeHost = store.activeAccount?.serverHostLabel ?? (URL(string: store.serverUrlInput)?.host ?? "cloud.fynncloud.ch")

        let syncStatusText: String
        let syncBadgeColor: EInkColor
        switch store.syncStatus {
        case .synced:
            syncStatusText = "Up to Date"
            syncBadgeColor = theme.successColor
        case .syncing:
            syncStatusText = "Syncing…"
            syncBadgeColor = theme.brandAccent
        case .offline:
            syncStatusText = "Offline"
            syncBadgeColor = theme.warningColor
        case .error:
            syncStatusText = "Error"
            syncBadgeColor = theme.dangerColor
        }

        let isOnline = (store.syncStatus != .offline)

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: General (Appearance)
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("General", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Appearance",
                                icon: store.isDarkMode ? .moon : .sun,
                                badgeColor: .royalBlue,
                                theme: theme
                            )
                            Spacer()

                            HStack(alignment: .center, spacing: 6) {
                                Button("Light") {
                                    store.isDarkMode = false
                                    store.savePersistedState()
                                    store.notifyUI()
                                }
                                .buttonStyle(!store.isDarkMode ? .borderedProminent : .capsule)
                                .controlSize(.mini)
                                .cornerRadius(999)

                                Button("Dark") {
                                    store.isDarkMode = true
                                    store.savePersistedState()
                                    store.notifyUI()
                                }
                                .buttonStyle(store.isDarkMode ? .borderedProminent : .capsule)
                                .controlSize(.mini)
                                .cornerRadius(999)

                                if KindleDevice.shared.isColorDisplay {
                                    Button(store.isColorEnabled ? "Color" : "Mono") {
                                        store.isColorEnabled.toggle()
                                        store.savePersistedState()
                                        store.notifyUI()
                                    }
                                    .buttonStyle(store.isColorEnabled ? .borderedProminent : .capsule)
                                    .controlSize(.mini)
                                    .cornerRadius(999)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }

                // Section 2: Sync & Connection
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Sync & Connection", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Sync Status",
                                icon: .refresh,
                                badgeColor: syncBadgeColor,
                                theme: theme
                            )
                            Spacer()
                            Text(syncStatusText)
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))

                        Divider()

                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Connection",
                                icon: .wifi,
                                badgeColor: isOnline ? theme.successColor : theme.warningColor,
                                theme: theme
                            )
                            Spacer()
                            Text(isOnline ? "Connected" : "Offline")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }

                // Section 3: Advanced
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Advanced", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            store.refreshAllData()
                            store.statusToast = "Forced metadata recheck against server"
                            store.notifyUI()
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Force Metadata Recheck",
                                    icon: .refresh,
                                    badgeColor: .amberGold,
                                    theme: theme
                                )
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button(action: {
                            store.manualTokenInput = store.activeAccount?.authToken ?? ""
                            store.manualRefreshTokenInput = store.activeAccount?.refreshToken ?? ""
                            showDebugTokenSheet = true
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Debug Token Editor",
                                    icon: .lock,
                                    badgeColor: .plumPurple,
                                    theme: theme
                                )
                                Spacer()
                                Icon(.chevronRight, size: 13)
                                    .foregroundColor(theme.mutedInk)
                            }
                            .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)

                    iosSectionFooter("Force Metadata Recheck clears local sync anchors and re-verifies all files against the server.", theme: theme)
                }

                // Section 4: About
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("About", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Version",
                                icon: .info,
                                badgeColor: .slateMuted,
                                theme: theme
                            )
                            Spacer()
                            Text("1.0.0 (1)")
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))

                        Divider()

                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Server",
                                icon: .server,
                                badgeColor: .royalBlue,
                                theme: theme
                            )
                            Spacer()
                            Text(activeHost)
                                .font(.system(size: 14))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }
                        .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))

                        Divider()

                        Button(action: {
                            KindleDevice.shared.quitApplication()
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Exit to Kindle Home",
                                    icon: .close,
                                    badgeColor: .crimsonRed,
                                    theme: theme
                                )
                                Spacer()
                                Icon(.chevronRight, size: 13)
                                    .foregroundColor(theme.mutedInk)
                            }
                            .padding(EdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }
            }
        }
        .expand(true, fill: true)
    }
}

// MARK: - Trash Tab (Ported 1:1 from DashboardView.trashPlaceholder)

extension FynnCloudRootView {
    internal func trashTabView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let trashed = store.trashedFiles

        return VStack(alignment: .center, spacing: 14) {
            if trashed.isEmpty {
                Spacer()
                Icon(.trash, size: 36)
                    .foregroundColor(theme.mutedInk)
                Text("Trash Not Implemented")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryInk)
                    .multilineTextAlignment(.center)
                Text("Trash is not implemented yet")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryInk)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(trashed.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { Divider() }
                            HStack(alignment: .center, spacing: 12) {
                                Icon(item.iconName, size: 20)
                                    .foregroundColor(theme.dangerColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(theme.primaryInk)
                                    Text("\(item.fileKind) • \(item.formattedSize)")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.secondaryInk)
                                }
                                .expand(true, fill: true)

                                Button("Restore") {
                                    store.restoreFromTrash(fileId: item.id)
                                }
                                .buttonStyle(.capsule)
                                .controlSize(.mini)
                            }
                            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }
                .expand(true, fill: true)
            }
        }
        .expand(true, fill: true)
    }
}

// MARK: - Debug Tab (Ported 1:1 from DebugTab.swift)

extension FynnCloudRootView {
    internal func debugTabView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Instance & Branding
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Instance & Branding", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                iosSettingsRowLabel(
                                    title: "Instance Name",
                                    icon: .pencil,
                                    badgeColor: .plumPurple,
                                    theme: theme
                                )
                                Spacer()
                                Text(store.instanceName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(theme.secondaryInk)
                                    .expand(false, fill: false)
                            }

                            HStack(alignment: .center, spacing: 8) {
                                ForEach(["FynnCloud", "Acme Cloud", "NextBox", "Studio Drive"], id: \.self) { preset in
                                    let isCurrent = (store.instanceName == preset)
                                    Button(preset) {
                                        store.instanceName = preset
                                        store.savePersistedState()
                                        store.notifyUI()
                                    }
                                    .buttonStyle(isCurrent ? .borderedProminent : .capsule)
                                    .controlSize(.mini)
                                    .cornerRadius(999)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        Divider()

                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Show Logo & Name Together",
                                icon: .star,
                                badgeColor: .royalBlue,
                                theme: theme
                            )
                            Spacer()
                            Button(store.showLogoAndName ? "On" : "Off") {
                                store.showLogoAndName.toggle()
                                store.savePersistedState()
                                store.notifyUI()
                            }
                            .buttonStyle(store.showLogoAndName ? .borderedProminent : .capsule)
                            .controlSize(.mini)
                            .cornerRadius(999)
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        Divider()

                        Button(action: {
                            store.instanceName = "FynnCloud"
                            store.brandColorName = "blue"
                            store.savePersistedState()
                            store.notifyUI()
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                iosSettingsRowLabel(
                                    title: "Reset Branding from Server",
                                    icon: .refresh,
                                    badgeColor: .slateMuted,
                                    theme: theme
                                )
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }

                // Section 2: Theme Palette
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Theme Palette", theme: theme)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Primary Brand Color",
                                icon: .sliders,
                                badgeColor: theme.brandAccent,
                                theme: theme
                            )
                            Spacer()
                            Text(store.brandColorName.capitalized)
                                .font(.system(size: 13))
                                .foregroundColor(theme.secondaryInk)
                                .expand(false, fill: false)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            ForEach(["blue", "teal", "emerald", "amber", "rose", "purple", "slate"], id: \.self) { colorName in
                                Button(colorName.capitalized) {
                                    store.brandColorName = colorName
                                    store.savePersistedState()
                                    store.notifyUI()
                                }
                                .buttonStyle(store.brandColorName == colorName ? .borderedProminent : .capsule)
                                .controlSize(.mini)
                                .cornerRadius(999)
                            }
                        }
                    }
                    .padding(16)
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }

                // Section 3: Mock Data & Scenarios
                VStack(alignment: .leading, spacing: 4) {
                    iosSectionHeader("Mock Data & Scenarios", theme: theme)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center, spacing: 12) {
                            iosSettingsRowLabel(
                                title: "Enable Mock Data",
                                icon: .bolt,
                                badgeColor: .amberGold,
                                theme: theme
                            )
                            Spacer()
                            Button(store.isMockDataEnabled ? "Enabled" : "Off") {
                                store.isMockDataEnabled.toggle()
                                if store.isMockDataEnabled {
                                    store.applyMockData()
                                }
                                store.savePersistedState()
                                store.notifyUI()
                            }
                            .buttonStyle(store.isMockDataEnabled ? .borderedProminent : .capsule)
                            .controlSize(.mini)
                            .cornerRadius(999)
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            iosSettingsRowLabel(
                                title: "Activity Feed Scenario",
                                icon: .clock,
                                badgeColor: .royalBlue,
                                theme: theme
                            )
                            HStack(alignment: .center, spacing: 8) {
                                ForEach(MockActivityScenario.allCases, id: \.rawValue) { scenario in
                                    let shortTitle: String = {
                                        switch scenario {
                                        case .standard: return "Populated"
                                        case .heavySharing: return "Sharing"
                                        case .cleanup: return "Moves & Trash"
                                        case .empty: return "Empty"
                                        }
                                    }()
                                    Button(shortTitle) {
                                        store.isMockDataEnabled = true
                                        store.mockScenario = scenario
                                        store.applyMockData()
                                        store.notifyUI()
                                    }
                                    .buttonStyle(store.mockScenario == scenario ? .borderedProminent : .capsule)
                                    .controlSize(.mini)
                                    .cornerRadius(999)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            iosSettingsRowLabel(
                                title: "Storage Quota Preset",
                                icon: .server,
                                badgeColor: .tealAccent,
                                theme: theme
                            )
                            HStack(alignment: .center, spacing: 8) {
                                ForEach(MockQuotaPreset.allCases, id: \.rawValue) { preset in
                                    let shortTitle: String = {
                                        switch preset {
                                        case .low: return "12%"
                                        case .normal: return "65%"
                                        case .almostFull: return "92%"
                                        case .full: return "100%"
                                        case .unlimited: return "Unlimited"
                                        }
                                    }()
                                    Button(shortTitle) {
                                        store.isMockDataEnabled = true
                                        store.mockQuotaPreset = preset
                                        store.applyMockData()
                                        store.notifyUI()
                                    }
                                    .buttonStyle(store.mockQuotaPreset == preset ? .borderedProminent : .capsule)
                                    .controlSize(.mini)
                                    .cornerRadius(999)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                        Divider()

                        HStack(alignment: .center, spacing: 10) {
                            iosSettingsRowLabel(
                                title: "Sync Status",
                                icon: .refresh,
                                badgeColor: .forestGreen,
                                theme: theme
                            )
                            Spacer()
                            Button("Up to Date") {
                                store.syncStatus = .synced
                                store.notifyUI()
                            }
                            .buttonStyle(store.syncStatus == .synced ? .borderedProminent : .capsule)
                            .controlSize(.mini)
                            .cornerRadius(999)

                            Button("Syncing") {
                                store.syncStatus = .syncing(progress: 0.64)
                                store.notifyUI()
                            }
                            .buttonStyle(.capsule)
                            .controlSize(.mini)

                            Button("Offline") {
                                store.syncStatus = .offline
                                store.notifyUI()
                            }
                            .buttonStyle(store.syncStatus == .offline ? .borderedProminent : .capsule)
                            .controlSize(.mini)
                            .cornerRadius(999)
                        }
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                    .background(theme.cardBg, cornerRadius: 16)
                    .border(theme.borderSubtle, width: 1, cornerRadius: 16)
                }
            }
        }
        .expand(true, fill: true)
    }
}

// MARK: - Files Browser Sheet & Action Modals (Opened from "Files" Toolbar Button or "Open in Files")

extension FynnCloudRootView {
    internal func filesBrowserSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let items = store.visibleFiles

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(FilesFilterMode.allCases, id: \.rawValue) { mode in
                    let isSelected = (store.filesFilter == mode)
                    Button(mode.rawValue) {
                        store.filesFilter = mode
                        store.selectedFileId = store.visibleFiles.first?.id
                        store.notifyUI()
                    }
                    .buttonStyle(isSelected ? .borderedProminent : .capsule)
                    .controlSize(.mini)
                    .cornerRadius(999)
                }

                Spacer()

                Button(action: {
                    newFolderNameInput = ""
                    showNewFolderSheet = true
                }) {
                    HStack(spacing: 6) {
                        Icon(.plus, size: 14)
                        Text("New Folder")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .buttonStyle(.capsule)
                .controlSize(.mini)
            }

            if store.filesFilter == .all {
                HStack(alignment: .center, spacing: 8) {
                    Icon(.folder, size: 16)
                        .foregroundColor(theme.brandAccent)
                    ForEach(Array(store.folderBreadcrumbs.enumerated()), id: \.offset) { idx, crumb in
                        if idx > 0 {
                            Text("/")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.mutedInk)
                                .expand(false, fill: false)
                        }
                        Button(crumb.name) {
                            store.navigateToBreadcrumb(index: idx)
                        }
                        .buttonStyle(.capsule)
                        .controlSize(.mini)
                    }
                    Spacer()
                }
            }

            if let banner = store.filesStatusBanner {
                HStack(alignment: .center, spacing: 10) {
                    Icon(.check, size: 16)
                        .foregroundColor(theme.successColor)
                    Text(banner)
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryInk)
                        .expand(true, fill: true)
                    Button("OK") {
                        store.filesStatusBanner = nil
                        store.notifyUI()
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.mini)
                }
                .padding(10)
                .background(theme.brandSoftTint, cornerRadius: 12)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 { Divider() }
                        let isSelected = (store.selectedFile?.id == entry.id)
                        Button(action: {
                            if store.selectedFileId == entry.id && entry.isDirectory {
                                store.openFolder(entry)
                            } else {
                                store.selectedFileId = entry.id
                                store.notifyUI()
                            }
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                Icon(entry.iconName, size: 20)
                                    .foregroundColor(entry.isDirectory ? theme.brandAccent : theme.secondaryInk)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(theme.primaryInk)
                                        .lineLimit(1)
                                    Text("\(entry.fileKind) • \(entry.formattedSize)")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.secondaryInk)
                                }
                                .expand(true, fill: true)

                                if isSelected {
                                    Icon(.check, size: 16)
                                        .foregroundColor(theme.brandAccent)
                                } else {
                                    Icon(.chevronRight, size: 13)
                                        .foregroundColor(theme.mutedInk)
                                }
                            }
                            .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
                            .background(isSelected ? theme.brandSoftTint : theme.cardBg)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(theme.cardBg, cornerRadius: 14)
                .border(theme.borderSubtle, width: 1, cornerRadius: 14)
            }
            .frame(height: 360)

            if let selected = store.selectedFile {
                HStack(alignment: .center, spacing: 8) {
                    if selected.isDirectory {
                        Button("Open Folder") {
                            store.openFolder(selected)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .cornerRadius(999)
                    } else {
                        Button("Save to Kindle") {
                            store.downloadFileToKindle(selected)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .cornerRadius(999)
                    }

                    Button(selected.isFavorite ? "Unstar" : "Star") {
                        store.toggleFavorite(fileId: selected.id)
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.small)

                    Button("Share") {
                        shareTargetFileId = selected.id
                        shareCollaboratorInput = ""
                        shareLinkLabelInput = ""
                        showShareSheet = true
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.small)

                    Button("Rename") {
                        renameTargetFileId = selected.id
                        renameFileInput = selected.name
                        showRenameSheet = true
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.small)

                    Spacer()

                    Button("Done") {
                        showFilesSheet = false
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.small)
                }
            } else {
                HStack {
                    Spacer()
                    Button("Done") {
                        showFilesSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .cornerRadius(999)
                }
            }
        }
        .padding(14)
    }

    internal func shareSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        let file = store.files.first { $0.id == shareTargetFileId }
        let fileName = file?.name ?? "Selected Item"
        let internalShares = store.internalSharesByFile[shareTargetFileId] ?? []
        let links = store.shareLinksByFile[shareTargetFileId] ?? []

        return VStack(alignment: .leading, spacing: 14) {
            Text("Sharing \"\(fileName)\"")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(theme.primaryInk)

            HStack(alignment: .center, spacing: 10) {
                TextField("Username (e.g. sarah)…", text: $shareCollaboratorInput, onCommit: {
                    store.addInternalShare(fileId: shareTargetFileId, username: shareCollaboratorInput, permission: shareRoleSelection)
                    shareCollaboratorInput = ""
                })

                Button(shareRoleSelection == "edit" ? "Can Edit" : "Can View") {
                    shareRoleSelection = (shareRoleSelection == "edit") ? "view" : "edit"
                }
                .buttonStyle(.capsule)
                .controlSize(.small)

                Button("Share") {
                    store.addInternalShare(fileId: shareTargetFileId, username: shareCollaboratorInput, permission: shareRoleSelection)
                    shareCollaboratorInput = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .cornerRadius(999)
            }

            ForEach(internalShares) { sh in
                HStack(alignment: .center, spacing: 10) {
                    Icon(.user, size: 16)
                        .foregroundColor(theme.brandAccent)
                    Text("@\(sh.sharedWithUsername) (\(sh.permission.uppercased()))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.primaryInk)
                        .expand(true, fill: true)
                    Button("Remove") {
                        store.removeInternalShare(fileId: shareTargetFileId, shareId: sh.id)
                    }
                    .buttonStyle(.capsule)
                    .controlSize(.mini)
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 10) {
                Text("Public Share Links (\(links.count))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.secondaryInk)
                Spacer()
                Button("Create Link") {
                    store.createShareLink(
                        fileId: shareTargetFileId,
                        label: "Public Link",
                        hasPassword: false,
                        allowDownload: true
                    )
                }
                .buttonStyle(.capsule)
                .controlSize(.small)
            }

            HStack {
                Spacer()
                Button("Done") {
                    showShareSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .cornerRadius(999)
            }
        }
        .padding(14)
    }

    internal func newFolderSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .leading, spacing: 14) {
            Text("Enter a name for the new folder:")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.primaryInk)

            TextField("Folder name…", text: $newFolderNameInput, onCommit: {
                store.createNewFolder(name: newFolderNameInput)
                showNewFolderSheet = false
            })

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    showNewFolderSheet = false
                }
                .buttonStyle(.capsule)
                .controlSize(.regular)

                Button("Create") {
                    store.createNewFolder(name: newFolderNameInput)
                    showNewFolderSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .cornerRadius(999)
            }
        }
        .padding(14)
    }

    internal func renameFileSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .leading, spacing: 14) {
            Text("Enter a new name:")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.primaryInk)

            TextField("New name…", text: $renameFileInput, onCommit: {
                store.renameFile(fileId: renameTargetFileId, newName: renameFileInput)
                showRenameSheet = false
            })

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    showRenameSheet = false
                }
                .buttonStyle(.capsule)
                .controlSize(.regular)

                Button("Save") {
                    store.renameFile(fileId: renameTargetFileId, newName: renameFileInput)
                    showRenameSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .cornerRadius(999)
            }
        }
        .padding(14)
    }

    internal func debugTokenSheetView(theme: FynnCloudTheme) -> some View {
        let store = FynnCloudStore.shared
        return VStack(alignment: .leading, spacing: 12) {
            Text("Manual Access & Refresh Token Configuration")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.primaryInk)

            Text("Server URL:")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.secondaryInk)
            TextField("https://cloud.fynncloud.ch", text: $serverUrlField)

            Text("Bearer Access Token (JWT):")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.secondaryInk)
            TextField("Paste accessToken…", text: $tokenField)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") {
                    showDebugTokenSheet = false
                }
                .buttonStyle(.capsule)
                .controlSize(.regular)

                Button("Save & Authenticate") {
                    if !tokenField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        store.completeAuthentication(
                            serverUrl: serverUrlField,
                            accessToken: tokenField,
                            refreshToken: nil
                        )
                    }
                    showDebugTokenSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .cornerRadius(999)
            }
        }
        .padding(14)
    }
}
