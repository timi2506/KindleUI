import Foundation

#if canImport(Observation)
@_exported import Observation
#endif

/// Central reactive state registry and runtime coordinator for KindleUI.
public final class KindleStateRegistry: @unchecked Sendable {
    public static let shared = KindleStateRegistry()

    private var namedSlots: [String: AnyObject] = [:]
    private var scopeStack: [String] = ["root"]
    /// Parallel to `scopeStack`: `scopeKeys[i]` is `scopeStack[0...i].joined(separator: "/")`, maintained
    /// incrementally so per-site key construction is O(1) instead of re-joining the whole stack each time.
    private var scopeKeys: [String] = ["root"]
    private var currentScopeKey: String { scopeKeys[scopeKeys.count - 1] }
    private var scopeSiteCounters: [String: Int] = [:]
    private var environmentStack: [EnvironmentValues] = [EnvironmentValues()]

    public private(set) var isEvaluatingBody: Bool = false
    internal private(set) var renderPassID: UInt64 = 0
    public var suppressSideEffects: Bool = false
    public var colorScheme: KindleColorScheme = .light
    internal var pendingFullRefresh: Bool = false
    public var onStateDidChange: (() -> Void)?

    // Lifecycle & side-effect tracking across render passes
    private var appearedIDs: Set<String> = []
    private var currentPassIDs: Set<String> = []
    private var disappearHandlers: [String: () -> Void] = [:]
    private var taskTokens: [String: AnyHashable] = [:]
    private var activeAsyncTasks: [String: Task<Void, Never>] = [:]
    private var onChangeStorage: [String: Any] = [:]
    private var preferenceStack: [[ObjectIdentifier: Any]] = [[:]]
    private var preferenceStorage: [String: Any] = [:]
    internal var activeDismissActions: [() -> Void] = []
    internal var activeModalOverlays: [(alignment: Alignment, node: RenderNode, isFullScreen: Bool, hasScrim: Bool)] = []
    internal var scrollRequestHandler: ((AnyHashable) -> Void)?
    internal var defaultEditMode: EditMode = .inactive
    internal var defaultModelContainer: ModelContainer? = nil

    /// Active application identifier declared by `App.applicationID` or `WindowGroup(id:)`.
    public private(set) var applicationID: String = "org.kindlemodding.default"
    private var hasCustomAppStoragePath: Bool = false
    private var resolvedAppStoragePath: String? = nil

    /// Configures the application identifier used to scope persistent storage on disk.
    public func configureApplicationID(_ rawID: String) {
        let cleaned = rawID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
        guard !cleaned.isEmpty, cleaned != applicationID else { return }
        applicationID = cleaned
        if !hasCustomAppStoragePath {
            resolvedAppStoragePath = nil
            appStorageLoaded = false
            appStorageCache.removeAll()
        }
    }

    /// Per-app persistent data directory (`/mnt/us/appdata/<applicationID>` on Kindle, `/tmp/kindleui-appdata/<applicationID>` on desktop).
    public var appDataDirectory: String {
        let fm = FileManager.default
        let dir: String
        if fm.fileExists(atPath: "/mnt/us/extensions") {
            dir = "/mnt/us/extensions/\(applicationID)/data"
        } else if fm.fileExists(atPath: "/mnt/us") && fm.isWritableFile(atPath: "/mnt/us") {
            dir = "/mnt/us/appdata/\(applicationID)"
        } else if fm.fileExists(atPath: "/mnt/base-us") && fm.isWritableFile(atPath: "/mnt/base-us") {
            dir = "/mnt/base-us/appdata/\(applicationID)"
        } else {
            dir = "/tmp/kindleui-appdata/\(applicationID)"
        }
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var appDataDirectory: String {
        shared.appDataDirectory
    }

    // Persistent AppStorage backing store (scoped per app via `applicationID`)
    private var appStorageCache: [String: String] = [:]
    private var appStorageLoaded: Bool = false
    public var appStoragePath: String {
        get {
            if let custom = resolvedAppStoragePath {
                return custom
            }
            return "\(appDataDirectory)/storage.json"
        }
        set {
            hasCustomAppStoragePath = true
            resolvedAppStoragePath = newValue
            appStorageLoaded = false
            appStorageCache.removeAll()
        }
    }

    private init() {}

    public var currentEnvironment: EnvironmentValues {
        environmentStack.last ?? EnvironmentValues()
    }

    public func pushScope(_ segment: String) {
        scopeStack.append(segment)
        scopeKeys.append(currentScopeKey + "/" + segment)
    }

    public func popScope() {
        if scopeStack.count > 1 {
            scopeStack.removeLast()
            scopeKeys.removeLast()
        }
    }

    public func pushEnvironment(_ transform: (inout EnvironmentValues) -> Void) {
        var env = currentEnvironment
        transform(&env)
        environmentStack.append(env)
    }

    public func popEnvironment() {
        if environmentStack.count > 1 {
            environmentStack.removeLast()
        }
    }

    public func beginRenderPass() {
        isEvaluatingBody = true
        renderPassID &+= 1
        scopeStack = ["root"]
        scopeKeys = ["root"]
        scopeSiteCounters.removeAll(keepingCapacity: true)
        environmentStack = [EnvironmentValues()]
        preferenceStack = [[:]]
        currentPassIDs.removeAll(keepingCapacity: true)
        activeDismissActions.removeAll(keepingCapacity: true)
        activeModalOverlays.removeAll(keepingCapacity: true)
        KindleKeyboardManager.shared.beginRenderPass()
    }

    internal func emitPreference<K: PreferenceKey>(key: K.Type, value: K.Value) {
        guard !preferenceStack.isEmpty else { return }
        let oid = ObjectIdentifier(key)
        let idx = preferenceStack.count - 1
        if var existing = preferenceStack[idx][oid] as? K.Value {
            K.reduce(value: &existing, nextValue: { value })
            preferenceStack[idx][oid] = existing
        } else {
            var initial = K.defaultValue
            K.reduce(value: &initial, nextValue: { value })
            preferenceStack[idx][oid] = initial
        }
    }

    internal func withPreferenceObservation<K: PreferenceKey>(
        key: K.Type,
        siteID: String,
        evaluateChild: () -> RenderNode,
        perform: (K.Value) -> Void
    ) -> RenderNode where K.Value: Equatable {
        let scopeID = currentScopeKey + "/pref:" + siteID
        preferenceStack.append([:])
        let node = evaluateChild()
        let childFrame = preferenceStack.popLast() ?? [:]
        let oid = ObjectIdentifier(key)
        let resolved = (childFrame[oid] as? K.Value) ?? K.defaultValue

        // Propagate upward to parent frame as well
        if !preferenceStack.isEmpty {
            let parentIdx = preferenceStack.count - 1
            if var parentVal = preferenceStack[parentIdx][oid] as? K.Value {
                K.reduce(value: &parentVal, nextValue: { resolved })
                preferenceStack[parentIdx][oid] = parentVal
            } else if childFrame[oid] != nil {
                preferenceStack[parentIdx][oid] = resolved
            }
        }

        if let prev = preferenceStorage[scopeID] as? K.Value {
            if prev != resolved {
                preferenceStorage[scopeID] = resolved
                if !suppressSideEffects {
                    perform(resolved)
                }
            }
        } else {
            preferenceStorage[scopeID] = resolved
            if resolved != K.defaultValue && !suppressSideEffects {
                perform(resolved)
            }
        }
        return node
    }

    public func endRenderPass() {
        isEvaluatingBody = false
        // Fire .onDisappear and cancel tasks for any tracked view ID that left the render tree
        let disappeared = appearedIDs.subtracting(currentPassIDs)
        for id in disappeared {
            appearedIDs.remove(id)
            taskTokens.removeValue(forKey: id)
            if let runningTask = activeAsyncTasks.removeValue(forKey: id) {
                runningTask.cancel()
            }
            if let handler = disappearHandlers.removeValue(forKey: id) {
                handler()
            }
        }
    }

    /// Evaluates a render tree pass and automatically re-evaluates if `.preferredColorScheme(_:)`
    /// updated the active `KindleTheme` during the pass.
    public func evaluateTree(_ makeTree: () -> RenderNode) -> RenderNode {
        beginRenderPass()
        #if canImport(Observation)
        var tree = withObservationTracking {
            makeTree()
        } onChange: {
            KindleStateRegistry.shared.notifyStateMutation()
        }
        #else
        var tree = makeTree()
        #endif
        endRenderPass()

        if let policy = tree.extractedRefreshPolicy {
            KindleDevice.shared.refreshPolicy = policy
        }

        if let scheme = tree.extractedColorScheme, scheme != colorScheme {
            colorScheme = scheme
            beginRenderPass()
            #if canImport(Observation)
            tree = withObservationTracking {
                makeTree()
            } onChange: {
                KindleStateRegistry.shared.notifyStateMutation()
            }
            #else
            tree = makeTree()
            #endif
            endRenderPass()
        }
        for modal in activeModalOverlays {
            tree = RenderNode.zstack(
                alignment: modal.alignment,
                children: [tree, modal.node],
                style: {
                    var s = ViewStyle()
                    s.expand = true
                    s.fill = true
                    s.isModalOverlay = true
                    s.isFullScreenModal = modal.isFullScreen
                    s.hasModalScrim = modal.hasScrim
                    return s
                }()
            )
        }
        KindleKeyboardManager.shared.endRenderPassCheck()
        return tree
    }

    public func resetAllState() {
        namedSlots.removeAll()
        scopeStack = ["root"]
        scopeKeys = ["root"]
        scopeSiteCounters.removeAll()
        environmentStack = [EnvironmentValues()]
        colorScheme = .light
        pendingFullRefresh = false
        appearedIDs.removeAll()
        currentPassIDs.removeAll()
        disappearHandlers.removeAll()
        taskTokens.removeAll()
        for (_, task) in activeAsyncTasks {
            task.cancel()
        }
        activeAsyncTasks.removeAll()
        onChangeStorage.removeAll()
        preferenceStack = [[:]]
        preferenceStorage.removeAll()
        activeDismissActions.removeAll()
        activeModalOverlays.removeAll()
        defaultEditMode = .inactive
    }

    internal func obtainBox<Value>(siteKey: String = "anon", initialValue: () -> Value) -> StateBox<Value> {
        if isEvaluatingBody {
            let scopePrefix = currentScopeKey + "|" + siteKey
            let idx = scopeSiteCounters[scopePrefix, default: 0]
            scopeSiteCounters[scopePrefix] = idx + 1
            let fullKey = "\(scopePrefix)#\(idx)"
            if let existing = namedSlots[fullKey] as? StateBox<Value> {
                return existing
            }
            let created = StateBox<Value>(initialValue())
            namedSlots[fullKey] = created
            return created
        } else {
            return StateBox<Value>(initialValue())
        }
    }

    internal func registerLifecycle(
        id: String,
        onAppear: (() -> Void)?,
        onDisappear: (() -> Void)?,
        taskID: AnyHashable?,
        taskAction: (() -> Void)?
    ) {
        guard !suppressSideEffects else { return }
        let scopedID = currentScopeKey + "|" + id
        currentPassIDs.insert(scopedID)
        if let onDisappear = onDisappear {
            disappearHandlers[scopedID] = onDisappear
        }
        if !appearedIDs.contains(scopedID) {
            appearedIDs.insert(scopedID)
            onAppear?()
            if let taskAction = taskAction {
                taskTokens[scopedID] = taskID ?? AnyHashable(scopedID)
                taskAction()
            }
        } else if let taskAction = taskAction, let taskID = taskID {
            if taskTokens[scopedID] != taskID {
                taskTokens[scopedID] = taskID
                taskAction()
            }
        }
    }

    internal func registerAsyncTask(
        id: String,
        token: AnyHashable,
        action: @escaping @Sendable () async -> Void
    ) {
        guard !suppressSideEffects else { return }
        let scopedID = currentScopeKey + "|" + id
        currentPassIDs.insert(scopedID)
        let shouldStart: Bool
        if !appearedIDs.contains(scopedID) {
            appearedIDs.insert(scopedID)
            taskTokens[scopedID] = token
            shouldStart = true
        } else if taskTokens[scopedID] != token {
            taskTokens[scopedID] = token
            shouldStart = true
        } else {
            shouldStart = false
        }
        if shouldStart {
            activeAsyncTasks[scopedID]?.cancel()
            activeAsyncTasks[scopedID] = Task {
                await action()
            }
        }
    }

    internal func checkOnChange<V: Equatable>(key: String, value: V, action: @escaping (V) -> Void) {
        let scopedKey = currentScopeKey + "|" + key
        if let prev = onChangeStorage[scopedKey] as? V {
            if prev != value {
                onChangeStorage[scopedKey] = value
                action(value)
            }
        } else {
            onChangeStorage[scopedKey] = value
        }
    }

    public func notifyStateMutation() {
        guard !isEvaluatingBody else { return }
        onStateDidChange?()
    }

    // MARK: - Persistent AppStorage Engine

    private func loadAppStorageIfNeeded() {
        guard !appStorageLoaded else { return }
        appStorageLoaded = true
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: appStoragePath)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return
        }
        appStorageCache = dict
    }

    private func saveAppStorage() {
        guard let data = try? JSONSerialization.data(withJSONObject: appStorageCache, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: appStoragePath), options: .atomic)
    }

    public func appStorageValue(forKey key: String) -> String? {
        loadAppStorageIfNeeded()
        return appStorageCache[key]
    }

    public func setAppStorageValue(_ value: String?, forKey key: String) {
        loadAppStorageIfNeeded()
        if appStorageCache[key] == value { return }
        if let value = value {
            appStorageCache[key] = value
        } else {
            appStorageCache.removeValue(forKey: key)
        }
        saveAppStorage()
        notifyStateMutation()
    }
}

/// Internal protocol implemented by `@State` and `@FocusState` so `View.buildRenderTree()`
/// can bind state properties to the active structural scope after `.id(_:)` and `.environment(_:)` modifiers run.
public protocol _StateProperty {
    func _bindToCurrentScope()
}

internal final class _StateResolver<Value>: @unchecked Sendable {
    private let siteKey: String
    private let initialValue: () -> Value
    private var resolvedBox: StateBox<Value>?
    private var resolvedPassID: UInt64 = 0

    init(siteKey: String, initialValue: @escaping () -> Value) {
        self.siteKey = siteKey
        self.initialValue = initialValue
    }

    func bindToCurrentScope() {
        if resolvedBox != nil { return }
        let reg = KindleStateRegistry.shared
        guard reg.isEvaluatingBody else { return }
        resolvedBox = reg.obtainBox(siteKey: siteKey, initialValue: initialValue)
        resolvedPassID = reg.renderPassID
    }

    var box: StateBox<Value> {
        if let existing = resolvedBox {
            return existing
        }
        let reg = KindleStateRegistry.shared
        let created = reg.obtainBox(siteKey: siteKey, initialValue: initialValue)
        resolvedBox = created
        resolvedPassID = reg.renderPassID
        return created
    }
}

/// Reference-type storage box backing a `@State` property.
public final class StateBox<Value>: @unchecked Sendable {
    public var value: Value {
        didSet {
            KindleStateRegistry.shared.notifyStateMutation()
        }
    }

    public init(_ initialValue: Value) {
        self.value = initialValue
    }
}
