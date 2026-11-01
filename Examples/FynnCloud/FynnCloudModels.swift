import Foundation
import KindleUI

// MARK: - Credentials & Account Models

public struct FynnCloudCredentials: Codable, Equatable, Identifiable, Sendable {
    public var accountId: String
    public var username: String?
    public var email: String?
    public var serverUrl: String
    public var authToken: String
    public var refreshToken: String?

    public var id: String { accountId }

    public var displayLabel: String {
        if let username = username, !username.isEmpty {
            return username
        }
        if let email = email, !email.isEmpty {
            return email
        }
        let host = URL(string: serverUrl)?.host ?? serverUrl
        return host
    }

    public var serverHostLabel: String {
        URL(string: serverUrl)?.host ?? serverUrl
    }

    public init(
        accountId: String = UUID().uuidString,
        username: String? = nil,
        email: String? = nil,
        serverUrl: String,
        authToken: String,
        refreshToken: String? = nil
    ) {
        self.accountId = accountId
        self.username = username
        self.email = email
        self.serverUrl = serverUrl
        self.authToken = authToken
        self.refreshToken = refreshToken
    }
}

public struct UserInfo: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let email: String
    public let displayName: String?
    public let avatarUpdatedAt: String?
    public let currentStorageUsage: Int64?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case displayName = "display_name"
        case avatarUpdatedAt = "avatar_updated_at"
        case currentStorageUsage = "current_storage_usage"
    }

    public init(
        id: String,
        username: String,
        email: String,
        displayName: String? = nil,
        avatarUpdatedAt: String? = nil,
        currentStorageUsage: Int64? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.displayName = displayName
        self.avatarUpdatedAt = avatarUpdatedAt
        self.currentStorageUsage = currentStorageUsage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        username = (try? container.decode(String.self, forKey: .username)) ?? "user"
        email = (try? container.decode(String.self, forKey: .email)) ?? ""

        let dynamic = try decoder.container(keyedBy: AnyCodingKey.self)
        displayName = (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? (try? dynamic.decodeIfPresent(String.self, forKey: AnyCodingKey("displayName")))
        avatarUpdatedAt = (try? container.decodeIfPresent(String.self, forKey: .avatarUpdatedAt))
            ?? (try? dynamic.decodeIfPresent(String.self, forKey: AnyCodingKey("avatarUpdatedAt")))
        currentStorageUsage = (try? container.decodeIfPresent(Int64.self, forKey: .currentStorageUsage))
            ?? (try? dynamic.decodeIfPresent(Int64.self, forKey: AnyCodingKey("currentStorageUsage")))
    }

    public var effectiveName: String {
        if let displayName = displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return username
    }

    public var initials: String {
        let parts = effectiveName.split(separator: " ")
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(effectiveName.prefix(2)).uppercased()
    }
}

public struct UserQuota: Codable, Equatable, Sendable {
    public let limit: Int64
    public let used: Int64
    public let percentage: Double
    public let tierName: String

    public init(limit: Int64, used: Int64, percentage: Double, tierName: String) {
        self.limit = limit
        self.used = used
        self.percentage = percentage
        self.tierName = tierName
    }

    public var isUnlimited: Bool {
        tierName.lowercased().contains("unlimited") || limit <= 0 || limit >= 1_000_000_000_000_000
    }

    public var formattedUsed: String {
        FynnCloudFormatting.formatBytes(used)
    }

    public var formattedLimit: String {
        if isUnlimited { return "Unlimited" }
        return FynnCloudFormatting.formatBytes(limit)
    }
}

// MARK: - Activity Models

public struct ActivityUser: Codable, Equatable, Sendable {
    public let id: String?
    public let username: String?
    public let displayName: String?
    public let avatarUpdatedAt: String?

    public init(
        id: String? = nil,
        username: String? = nil,
        displayName: String? = nil,
        avatarUpdatedAt: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarUpdatedAt = avatarUpdatedAt
    }

    public var effectiveName: String {
        if let display = displayName, !display.isEmpty {
            return display
        }
        if let user = username, !user.isEmpty {
            return user
        }
        return "You"
    }
}

public enum ActivityEventType: String, Codable, CaseIterable, Sendable {
    case create
    case modify
    case rename
    case move
    case trash
    case restore
    case versionRestored = "version_restored"
    case delete
    case favorite
    case unfavorite
    case share
    case unshare
    case sharedInternal = "shared_internal"
    case unsharedInternal = "unshared_internal"
    case shareRoleChanged = "share_role_changed"
    case shareLinkCreated = "share_link_created"
    case shareLinkRevoked = "share_link_revoked"
    case publicDownload = "public_download"
    case upsert
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "unknown"
        self = ActivityEventType(rawValue: raw) ?? .unknown
    }

    public var label: String {
        switch self {
        case .create: return "Created"
        case .modify, .upsert: return "Edited"
        case .rename: return "Renamed"
        case .move: return "Moved"
        case .trash: return "Moved to Trash"
        case .restore: return "Restored"
        case .versionRestored: return "Restored version of"
        case .delete: return "Permanently deleted"
        case .favorite: return "Starred"
        case .unfavorite: return "Unstarred"
        case .share, .sharedInternal: return "Shared"
        case .unshare, .unsharedInternal: return "Unshared"
        case .shareRoleChanged: return "Updated access to"
        case .shareLinkCreated: return "Created share link for"
        case .shareLinkRevoked: return "Removed share link for"
        case .publicDownload: return "Downloaded via public link"
        case .unknown: return "Updated"
        }
    }

    public var icon: KindleIconName {
        switch self {
        case .create: return .plus
        case .modify, .upsert: return .pencil
        case .rename: return .pencil
        case .move: return .chevronRight
        case .trash, .delete: return .trash
        case .restore, .versionRestored: return .refresh
        case .favorite, .unfavorite: return .star
        case .share, .sharedInternal, .shareRoleChanged: return .user
        case .unshare, .unsharedInternal: return .close
        case .shareLinkCreated, .shareLinkRevoked: return .link
        case .publicDownload: return .download
        case .unknown: return .document
        }
    }

    public var isSharingEvent: Bool {
        switch self {
        case .share, .unshare, .sharedInternal, .unsharedInternal,
             .shareRoleChanged, .shareLinkCreated, .shareLinkRevoked, .publicDownload:
            return true
        default:
            return false
        }
    }

    public func accentColor(theme: FynnCloudTheme) -> EInkColor {
        if !theme.isColorEnabled {
            return theme.isDark ? .shade13 : .shade3
        }
        switch self {
        case .create, .restore:
            return .forestGreen
        case .modify, .upsert, .versionRestored:
            return .royalBlue
        case .rename, .favorite, .unfavorite:
            return .amberGold
        case .move, .publicDownload:
            return .tealAccent
        case .trash, .delete, .unshare, .unsharedInternal, .shareLinkRevoked:
            return .crimsonRed
        case .share, .sharedInternal, .shareRoleChanged, .shareLinkCreated:
            return .plumPurple
        case .unknown:
            return .slateMuted
        }
    }

    public func badgeTint(theme: FynnCloudTheme) -> EInkColor {
        if theme.isDark {
            return .darkNavyCard
        }
        if !theme.isColorEnabled {
            return .shade14
        }
        switch self {
        case .create, .restore:
            return .softGreenTint
        case .modify, .upsert, .versionRestored:
            return .softBlueTint
        case .rename, .favorite, .unfavorite:
            return .softAmberTint
        case .move, .publicDownload:
            return .softTealTint
        case .trash, .delete, .unshare, .unsharedInternal, .shareLinkRevoked:
            return .softRoseTint
        case .share, .sharedInternal, .shareRoleChanged, .shareLinkCreated:
            return .softBlueTint
        case .unknown:
            return .shade14
        }
    }
}

public struct ActivityItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let fileId: String
    public let fileName: String
    public let isFolder: Bool
    public let eventType: ActivityEventType
    public let createdAt: Date
    public let user: ActivityUser?

    public let size: Int64?
    public let mimeType: String?
    public let path: String?

    public let oldName: String?
    public let newName: String?
    public let oldParentId: String?
    public let newParentId: String?
    public let oldPath: String?
    public let newPath: String?
    public let targetUsername: String?
    public let shareRole: String?

    public init(
        id: String,
        fileId: String,
        fileName: String,
        isFolder: Bool,
        eventType: ActivityEventType,
        createdAt: Date,
        user: ActivityUser? = nil,
        size: Int64? = nil,
        mimeType: String? = nil,
        path: String? = nil,
        oldName: String? = nil,
        newName: String? = nil,
        oldParentId: String? = nil,
        newParentId: String? = nil,
        oldPath: String? = nil,
        newPath: String? = nil,
        targetUsername: String? = nil,
        shareRole: String? = nil
    ) {
        self.id = id
        self.fileId = fileId
        self.fileName = fileName
        self.isFolder = isFolder
        self.eventType = eventType
        self.createdAt = createdAt
        self.user = user
        self.size = size
        self.mimeType = mimeType
        self.path = path
        self.oldName = oldName
        self.newName = newName
        self.oldParentId = oldParentId
        self.newParentId = newParentId
        self.oldPath = oldPath
        self.newPath = newPath
        self.targetUsername = targetUsername
        self.shareRole = shareRole
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fileId, file_id
        case fileName, file_name, name
        case isFolder, is_folder, isDirectory
        case eventType, event_type, action, type
        case createdAt, created_at, timestamp
        case user, actor
        case size
        case mimeType, mime_type
        case path
        case details, metadata
    }

    enum DetailsKeys: String, CodingKey {
        case oldName, old_name
        case newName, new_name
        case oldParentId, old_parent_id
        case newParentId, new_parent_id
        case oldPath, old_path
        case newPath, new_path
        case targetUsername, target_username, sharedWith, shared_with
        case shareRole, share_role, role, permission
        case size
        case mimeType, mime_type
        case path
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let s = try? container.decode(String.self, forKey: .id) {
            id = s
        } else if let n = try? container.decode(Int64.self, forKey: .id) {
            id = String(n)
        } else {
            id = UUID().uuidString
        }

        fileId = (try? container.decode(String.self, forKey: .fileId))
            ?? (try? container.decode(String.self, forKey: .file_id))
            ?? id

        fileName = (try? container.decode(String.self, forKey: .fileName))
            ?? (try? container.decode(String.self, forKey: .file_name))
            ?? (try? container.decode(String.self, forKey: .name))
            ?? "Untitled"

        isFolder = (try? container.decode(Bool.self, forKey: .isFolder))
            ?? (try? container.decode(Bool.self, forKey: .is_folder))
            ?? (try? container.decode(Bool.self, forKey: .isDirectory))
            ?? false

        eventType = (try? container.decode(ActivityEventType.self, forKey: .eventType))
            ?? (try? container.decode(ActivityEventType.self, forKey: .event_type))
            ?? (try? container.decode(ActivityEventType.self, forKey: .action))
            ?? (try? container.decode(ActivityEventType.self, forKey: .type))
            ?? .unknown

        let dateString = (try? container.decode(String.self, forKey: .createdAt))
            ?? (try? container.decode(String.self, forKey: .created_at))
            ?? (try? container.decode(String.self, forKey: .timestamp))

        if let str = dateString {
            createdAt = FynnCloudFormatting.parseDate(str) ?? Date()
        } else if let ts = try? container.decode(Double.self, forKey: .timestamp) {
            createdAt = Date(timeIntervalSince1970: ts > 10_000_000_000 ? ts / 1000 : ts)
        } else {
            createdAt = Date()
        }

        user = (try? container.decode(ActivityUser.self, forKey: .user))
            ?? (try? container.decode(ActivityUser.self, forKey: .actor))

        let detailsContainer = (try? container.nestedContainer(keyedBy: DetailsKeys.self, forKey: .details))
            ?? (try? container.nestedContainer(keyedBy: DetailsKeys.self, forKey: .metadata))

        size = (try? container.decode(Int64.self, forKey: .size))
            ?? (try? detailsContainer?.decode(Int64.self, forKey: .size))

        mimeType = (try? container.decode(String.self, forKey: .mimeType))
            ?? (try? container.decode(String.self, forKey: .mime_type))
            ?? (try? detailsContainer?.decode(String.self, forKey: .mimeType))
            ?? (try? detailsContainer?.decode(String.self, forKey: .mime_type))

        path = (try? container.decode(String.self, forKey: .path))
            ?? (try? detailsContainer?.decode(String.self, forKey: .path))

        oldName = (try? detailsContainer?.decode(String.self, forKey: .oldName))
            ?? (try? detailsContainer?.decode(String.self, forKey: .old_name))
        newName = (try? detailsContainer?.decode(String.self, forKey: .newName))
            ?? (try? detailsContainer?.decode(String.self, forKey: .new_name))

        oldParentId = (try? detailsContainer?.decode(String.self, forKey: .oldParentId))
            ?? (try? detailsContainer?.decode(String.self, forKey: .old_parent_id))
        newParentId = (try? detailsContainer?.decode(String.self, forKey: .newParentId))
            ?? (try? detailsContainer?.decode(String.self, forKey: .new_parent_id))

        oldPath = (try? detailsContainer?.decode(String.self, forKey: .oldPath))
            ?? (try? detailsContainer?.decode(String.self, forKey: .old_path))
        newPath = (try? detailsContainer?.decode(String.self, forKey: .newPath))
            ?? (try? detailsContainer?.decode(String.self, forKey: .new_path))

        targetUsername = (try? detailsContainer?.decode(String.self, forKey: .targetUsername))
            ?? (try? detailsContainer?.decode(String.self, forKey: .target_username))
            ?? (try? detailsContainer?.decode(String.self, forKey: .sharedWith))
            ?? (try? detailsContainer?.decode(String.self, forKey: .shared_with))

        shareRole = (try? detailsContainer?.decode(String.self, forKey: .shareRole))
            ?? (try? detailsContainer?.decode(String.self, forKey: .share_role))
            ?? (try? detailsContainer?.decode(String.self, forKey: .role))
            ?? (try? detailsContainer?.decode(String.self, forKey: .permission))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(isFolder, forKey: .isFolder)
        try container.encode(eventType.rawValue, forKey: .eventType)
        try container.encode(createdAt.timeIntervalSince1970, forKey: .timestamp)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(path, forKey: .path)
    }

    public var humanizedSummary: String {
        switch eventType {
        case .create:
            return isFolder ? "Created folder" : "Added new file"
        case .modify, .upsert:
            return "Modified file contents"
        case .rename:
            if let old = oldName, !old.isEmpty {
                return "Renamed from \(old)"
            }
            return "Renamed"
        case .move:
            if let newP = newPath, !newP.isEmpty {
                return "Moved to \(newP)"
            }
            return "Moved to another folder"
        case .trash:
            return "Moved to trash"
        case .restore:
            return "Restored from trash"
        case .versionRestored:
            return "Restored previous version"
        case .delete:
            return "Permanently deleted"
        case .favorite:
            return "Added to favorites"
        case .unfavorite:
            return "Removed from favorites"
        case .share, .sharedInternal:
            if let target = targetUsername, !target.isEmpty {
                let roleText: String
                switch shareRole?.lowercased() {
                case "edit", "editor": roleText = " (Can edit)"
                case "view", "viewer": roleText = " (Can view)"
                default: roleText = ""
                }
                return "Shared with \(target)\(roleText)"
            }
            return "Shared"
        case .unshare, .unsharedInternal:
            if let target = targetUsername, !target.isEmpty {
                return "Removed \(target)'s access"
            }
            return "Unshared"
        case .shareRoleChanged:
            if let target = targetUsername, !target.isEmpty {
                return "Updated \(target)'s access"
            }
            return "Updated share permissions"
        case .shareLinkCreated:
            return "Created public link"
        case .shareLinkRevoked:
            return "Removed public link"
        case .publicDownload:
            return "Downloaded via public link"
        case .unknown:
            return "Updated"
        }
    }

    public func isAuthoredByMe(currentUserId: String?, currentUsername: String?) -> Bool {
        guard let author = user else { return true }
        if let uid = currentUserId, let aid = author.id, uid == aid { return true }
        if let uname = currentUsername?.lowercased(), let aname = author.username?.lowercased(), uname == aname { return true }
        if author.effectiveName == "You" { return true }
        return false
    }

    public func naturalSummary(currentUserId: String?, currentUsername: String?) -> String {
        let isMe = isAuthoredByMe(currentUserId: currentUserId, currentUsername: currentUsername)
        let actor = isMe ? "You" : (user?.effectiveName ?? "Someone")
        let noun = isFolder ? "folder" : "file"
        let time = relativeTimeText.lowercased() == "just now" ? "just now" : relativeTimeText

        let actionPhrase: String
        switch eventType {
        case .create, .upsert:
            actionPhrase = "created this \(noun)"
        case .modify:
            actionPhrase = "modified this \(noun)"
        case .rename:
            actionPhrase = "renamed this \(noun)"
        case .move:
            actionPhrase = "moved this \(noun)"
        case .trash:
            actionPhrase = "moved this \(noun) to the trash"
        case .restore:
            actionPhrase = "restored this \(noun) from the trash"
        case .versionRestored:
            actionPhrase = "restored a previous version of this \(noun)"
        case .delete:
            actionPhrase = "permanently deleted this \(noun)"
        case .favorite:
            actionPhrase = "added this \(noun) to favorites"
        case .unfavorite:
            actionPhrase = "removed this \(noun) from favorites"
        case .share, .sharedInternal:
            if let target = targetUsername, !target.isEmpty {
                actionPhrase = "shared this \(noun) with \(target)"
            } else {
                actionPhrase = "shared this \(noun)"
            }
        case .unshare, .unsharedInternal:
            if let target = targetUsername, !target.isEmpty {
                actionPhrase = "removed \(target)'s access to this \(noun)"
            } else {
                actionPhrase = "unshared this \(noun)"
            }
        case .shareRoleChanged:
            if let target = targetUsername, !target.isEmpty {
                actionPhrase = "updated \(target)'s access to this \(noun)"
            } else {
                actionPhrase = "updated permissions on this \(noun)"
            }
        case .shareLinkCreated:
            actionPhrase = "created a public link for this \(noun)"
        case .shareLinkRevoked:
            actionPhrase = "removed a public link for this \(noun)"
        case .publicDownload:
            return "Downloaded via a public link \(time)"
        case .unknown:
            actionPhrase = "updated this \(noun)"
        }
        return "\(actor) \(actionPhrase) \(time)"
    }

    public var formattedSize: String? {
        guard !isFolder, let bytes = size, bytes >= 0 else { return nil }
        return FynnCloudFormatting.formatBytes(bytes)
    }

    public var fileKind: String {
        FynnCloudFormatting.fileKind(fileName: fileName, isFolder: isFolder, mimeType: mimeType)
    }

    public var relativeTimeText: String {
        FynnCloudFormatting.relativeTime(from: createdAt)
    }

    public var fullDateText: String {
        FynnCloudFormatting.fullDate(from: createdAt)
    }
}

// MARK: - Cloud File & Sharing Models (Ported from DomainService + ShareAPIClient)

public struct CloudFileEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var parentID: String?
    public var isDirectory: Bool
    public var size: Int64?
    public var mimeType: String?
    public var updatedAt: Date
    public var isFavorite: Bool
    public var isShared: Bool
    public var isTrashed: Bool
    public var ownerUsername: String?
    public var path: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        parentID: String? = nil,
        isDirectory: Bool = false,
        size: Int64? = nil,
        mimeType: String? = nil,
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        isShared: Bool = false,
        isTrashed: Bool = false,
        ownerUsername: String? = nil,
        path: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.isDirectory = isDirectory
        self.size = size
        self.mimeType = mimeType
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isShared = isShared
        self.isTrashed = isTrashed
        self.ownerUsername = ownerUsername
        self.path = path
    }

    enum CodingKeys: String, CodingKey {
        case id, name, parentID, parent_id, isDirectory, is_directory, isFolder
        case size, mimeType, mime_type, updatedAt, updated_at
        case isFavorite, is_favorite, isShared, is_shared, isTrashed, is_trashed
        case ownerUsername, owner_username
        case path
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Untitled"
        parentID = (try? c.decodeIfPresent(String.self, forKey: .parentID))
            ?? (try? c.decodeIfPresent(String.self, forKey: .parent_id))
        isDirectory = (try? c.decode(Bool.self, forKey: .isDirectory))
            ?? (try? c.decode(Bool.self, forKey: .is_directory))
            ?? (try? c.decode(Bool.self, forKey: .isFolder))
            ?? false
        size = try? c.decodeIfPresent(Int64.self, forKey: .size)
        mimeType = (try? c.decodeIfPresent(String.self, forKey: .mimeType))
            ?? (try? c.decodeIfPresent(String.self, forKey: .mime_type))
        if let dateStr = (try? c.decodeIfPresent(String.self, forKey: .updatedAt))
            ?? (try? c.decodeIfPresent(String.self, forKey: .updated_at)),
           let parsed = FynnCloudFormatting.parseDate(dateStr) {
            updatedAt = parsed
        } else {
            updatedAt = Date()
        }
        isFavorite = (try? c.decode(Bool.self, forKey: .isFavorite))
            ?? (try? c.decode(Bool.self, forKey: .is_favorite))
            ?? false
        isShared = (try? c.decode(Bool.self, forKey: .isShared))
            ?? (try? c.decode(Bool.self, forKey: .is_shared))
            ?? false
        isTrashed = (try? c.decode(Bool.self, forKey: .isTrashed))
            ?? (try? c.decode(Bool.self, forKey: .is_trashed))
            ?? false
        ownerUsername = (try? c.decodeIfPresent(String.self, forKey: .ownerUsername))
            ?? (try? c.decodeIfPresent(String.self, forKey: .owner_username))
        path = try? c.decodeIfPresent(String.self, forKey: .path)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(parentID, forKey: .parentID)
        try c.encode(isDirectory, forKey: .isDirectory)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encodeIfPresent(mimeType, forKey: .mimeType)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(isShared, forKey: .isShared)
        try c.encode(isTrashed, forKey: .isTrashed)
        try c.encodeIfPresent(ownerUsername, forKey: .ownerUsername)
        try c.encodeIfPresent(path, forKey: .path)
    }

    public var formattedSize: String {
        if isDirectory { return "Folder" }
        guard let bytes = size else { return "—" }
        return FynnCloudFormatting.formatBytes(bytes)
    }

    public var fileKind: String {
        FynnCloudFormatting.fileKind(fileName: name, isFolder: isDirectory, mimeType: mimeType)
    }

    public var iconName: KindleIconName {
        if isDirectory { return .folder }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "epub", "mobi", "azw3", "kfx", "pdf":
            return .book
        default:
            return .document
        }
    }
}

public struct InternalShareDTO: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sharedWithUserId: String
    public let sharedWithUsername: String
    public var permission: String
    public let createdAt: String?

    public init(
        id: String = UUID().uuidString,
        sharedWithUserId: String = UUID().uuidString,
        sharedWithUsername: String,
        permission: String,
        createdAt: String? = nil
    ) {
        self.id = id
        self.sharedWithUserId = sharedWithUserId
        self.sharedWithUsername = sharedWithUsername
        self.permission = permission
        self.createdAt = createdAt
    }
}

public struct ShareLinkDTO: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let token: String
    public var label: String?
    public var hasPassword: Bool
    public var expiresAt: String?
    public var maxDownloads: Int?
    public var downloadCount: Int
    public var allowDownload: Bool
    public let createdAt: String?

    public init(
        id: String = UUID().uuidString,
        token: String,
        label: String? = nil,
        hasPassword: Bool = false,
        expiresAt: String? = nil,
        maxDownloads: Int? = nil,
        downloadCount: Int = 0,
        allowDownload: Bool = true,
        createdAt: String? = nil
    ) {
        self.id = id
        self.token = token
        self.label = label
        self.hasPassword = hasPassword
        self.expiresAt = expiresAt
        self.maxDownloads = maxDownloads
        self.downloadCount = downloadCount
        self.allowDownload = allowDownload
        self.createdAt = createdAt
    }
}

// MARK: - Sync, Navigation & Debug Enums

public enum SyncStatus: Equatable, Sendable {
    case synced
    case syncing(progress: Double)
    case offline
    case error(String)

    public var label: String {
        switch self {
        case .synced: return "All files in sync"
        case .syncing(let pct): return "Syncing (\(Int(pct * 100))%)..."
        case .offline: return "Offline"
        case .error(let msg): return "Sync error: \(msg)"
        }
    }

    public var shortBadgeText: String {
        switch self {
        case .synced: return "Synced"
        case .syncing(let pct): return "\(Int(pct * 100))%"
        case .offline: return "Offline"
        case .error: return "Error"
        }
    }
}

public enum DashboardTab: String, CaseIterable, Sendable {
    case activity = "Activity"
    case account = "Account"
    case settings = "Settings"
    case trash = "Trash"
    case debug = "Debug"

    public var icon: KindleIconName {
        switch self {
        case .activity: return .clock
        case .account: return .user
        case .settings: return .gear
        case .trash: return .trash
        case .debug: return .bug
        }
    }
}

public enum SetupWizardStep: Int, Codable, Sendable {
    case welcome = 0
    case login = 1
    case folderSetup = 2
}

public enum FilesFilterMode: String, CaseIterable, Sendable {
    case all = "All Files"
    case favorites = "Starred"
    case shared = "Shared with Me"
    case kindleDocs = "Kindle Books"
}

public enum MockActivityScenario: String, CaseIterable, Sendable {
    case standard = "Standard Mix (10 items)"
    case heavySharing = "Collaboration & Sharing"
    case cleanup = "Renames, Moves & Trash"
    case empty = "Empty Activity State"
}

public enum MockQuotaPreset: String, CaseIterable, Sendable {
    case low = "12% Used (6 GB / 50 GB)"
    case normal = "65% Used (32.5 GB / 50 GB)"
    case almostFull = "92% Used (46 GB / 50 GB)"
    case full = "100% Full (50 GB / 50 GB)"
    case unlimited = "Unlimited Plan (128.4 GB used)"
}

// MARK: - FynnCloud Theme & Tailwind Brand Color Mapping for Kindle E-Ink / Colorsoft

public struct FynnCloudTheme: Sendable {
    public let isDark: Bool
    public let isColorEnabled: Bool
    public let brandColorName: String

    public init(isDark: Bool, isColorEnabled: Bool, brandColorName: String = "blue") {
        self.isDark = isDark
        self.isColorEnabled = isColorEnabled
        self.brandColorName = brandColorName
    }

    public static let availableBrandColors: [(name: String, label: String)] = [
        ("blue", "Blue"),
        ("sky", "Sky"),
        ("cyan", "Cyan"),
        ("teal", "Teal"),
        ("emerald", "Emerald"),
        ("green", "Green"),
        ("lime", "Lime"),
        ("yellow", "Yellow"),
        ("amber", "Amber"),
        ("orange", "Orange"),
        ("red", "Red"),
        ("rose", "Rose"),
        ("pink", "Pink"),
        ("fuchsia", "Fuchsia"),
        ("purple", "Purple"),
        ("violet", "Violet"),
        ("indigo", "Indigo"),
        ("slate", "Slate"),
        ("gray", "Gray"),
        ("zinc", "Zinc"),
        ("neutral", "Neutral"),
        ("stone", "Stone")
    ]

    /// Maps FynnCloud's 22 Tailwind brand colors to Kaleido 3 Colorsoft tokens.
    public static func colorToken(for brand: String, isDark: Bool, isColorEnabled: Bool) -> EInkColor {
        if !isColorEnabled {
            return isDark ? .shade14 : .shade1
        }
        switch brand.lowercased() {
        case "blue", "sky", "indigo":
            return .royalBlue
        case "cyan", "teal":
            return .tealAccent
        case "emerald", "green", "lime":
            return .forestGreen
        case "yellow", "amber", "orange":
            return .amberGold
        case "red", "rose", "pink":
            return .crimsonRed
        case "fuchsia", "purple", "violet":
            return .plumPurple
        case "slate", "gray", "zinc", "neutral", "stone":
            return .slateMuted
        default:
            return .royalBlue
        }
    }

    public static func softTintToken(for brand: String, isDark: Bool, isColorEnabled: Bool) -> EInkColor {
        if isDark {
            return isColorEnabled ? .darkNavyCard : .shade2
        }
        if !isColorEnabled {
            return .shade14
        }
        switch brand.lowercased() {
        case "blue", "sky", "indigo", "fuchsia", "purple", "violet":
            return .softBlueTint
        case "cyan", "teal":
            return .softTealTint
        case "emerald", "green", "lime":
            return .softGreenTint
        case "yellow", "amber", "orange":
            return .softAmberTint
        case "red", "rose", "pink":
            return .softRoseTint
        default:
            return .shade14
        }
    }

    // iOS .systemGroupedBackground (light gray #EEEEEE) vs .secondarySystemGroupedBackground (white #FFFFFF)
    public var pageBg: EInkColor { isDark ? .shade0 : .shade14 }
    public var cardBg: EInkColor { isDark ? .shade1 : .shade15 }
    public var elevatedBg: EInkColor {
        if isDark { return isColorEnabled ? .darkNavyCard : .shade2 }
        return .shade13
    }
    public var headerBg: EInkColor {
        if isDark { return isColorEnabled ? .darkNavyCard : .shade1 }
        return isColorEnabled ? .softBlueTint : .shade14
    }

    public var primaryInk: EInkColor { isDark ? .shade15 : .shade0 }
    public var secondaryInk: EInkColor { isDark ? .shade12 : .shade4 }
    public var mutedInk: EInkColor {
        if isColorEnabled && !isDark { return .slateMuted }
        return isDark ? .shade9 : .shade6
    }

    public var borderSubtle: EInkColor {
        return isDark ? .shade3 : .shade12
    }
    public var borderStrong: EInkColor {
        if isColorEnabled && !isDark { return brandAccent }
        return isDark ? .shade11 : .shade3
    }

    public var brandAccent: EInkColor {
        Self.colorToken(for: brandColorName, isDark: isDark, isColorEnabled: isColorEnabled)
    }

    public var brandSoftTint: EInkColor {
        Self.softTintToken(for: brandColorName, isDark: isDark, isColorEnabled: isColorEnabled)
    }

    public var successColor: EInkColor {
        isColorEnabled ? .forestGreen : (isDark ? .shade13 : .shade2)
    }
    public var warningColor: EInkColor {
        isColorEnabled ? .amberGold : (isDark ? .shade12 : .shade4)
    }
    public var dangerColor: EInkColor {
        isColorEnabled ? .crimsonRed : (isDark ? .shade13 : .shade2)
    }
}

// MARK: - Formatting Helpers

public enum FynnCloudFormatting {
    public static func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1.0 { return "\(bytes) B" }
        let mb = kb / 1024.0
        if mb < 1.0 { return String(format: "%.1f KB", kb) }
        let gb = mb / 1024.0
        if gb < 1.0 { return String(format: "%.1f MB", mb) }
        let tb = gb / 1024.0
        if tb < 1.0 { return String(format: "%.2f GB", gb) }
        return String(format: "%.2f TB", tb)
    }

    public static func fileKind(fileName: String, isFolder: Bool, mimeType: String?) -> String {
        if isFolder { return "Folder" }
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "PDF Document"
        case "epub": return "EPUB eBook"
        case "mobi", "azw3", "kfx": return "Kindle eBook"
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "heic": return "Image (\(ext.uppercased()))"
        case "mp4", "mov", "mkv", "webm": return "Video (\(ext.uppercased()))"
        case "mp3", "wav", "m4a", "flac": return "Audio (\(ext.uppercased()))"
        case "zip", "tar", "gz", "7z", "rar": return "Archive (\(ext.uppercased()))"
        case "md", "txt", "rtf": return "Text Document"
        case "doc", "docx": return "Word Document"
        case "xls", "xlsx", "csv": return "Spreadsheet"
        case "ppt", "pptx", "key": return "Presentation"
        case "swift", "ts", "js", "py", "go", "rs", "json", "yaml", "html", "css":
            return "Source Code (\(ext.uppercased()))"
        default:
            if let mime = mimeType, !mime.isEmpty {
                return mime
            }
            return ext.isEmpty ? "File" : "\(ext.uppercased()) File"
        }
    }

    public static func relativeTime(from date: Date) -> String {
        let delta = Int(Date().timeIntervalSince(date))
        if delta < 45 { return "Just now" }
        if delta < 3600 {
            let mins = max(1, delta / 60)
            return "\(mins)m ago"
        }
        if delta < 86400 {
            let hrs = max(1, delta / 3600)
            return "\(hrs)h ago"
        }
        let days = max(1, delta / 86400)
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days)d ago" }
        return fullDate(from: date)
    }

    public static func fullDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return formatter.string(from: date)
    }

    public static func parseDate(_ str: String) -> Date? {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: str) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return df.date(from: str)
    }
}

internal struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
