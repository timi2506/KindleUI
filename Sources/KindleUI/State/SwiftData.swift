import Foundation

// MARK: - Declarative Model Persistence (@Query, ModelContainer, ModelContext)

/// Sort order for `@Query` results.
public enum SortOrder: Sendable, Equatable {
    case forward
    case reverse
}

/// Protocol adopted by persistent models stored in `ModelContainer` and queried via `@Query`.
public protocol PersistentModel: Codable, Identifiable, Equatable, Sendable {}

/// Manages persistent storage of `PersistentModel` collections on Kindle (`/mnt/us/extensions/kindleui_models.json`).
public final class ModelContainer: @unchecked Sendable {
    public static let shared = ModelContainer()

    private let customStoragePath: String?
    public var storagePath: String {
        customStoragePath ?? "\(KindleStateRegistry.appDataDirectory)/models.json"
    }
    private var rawCollections: [String: Data] = [:]
    private var isLoaded: Bool = false

    public lazy var mainContext: ModelContext = ModelContext(container: self)

    public init(storagePath: String? = nil) {
        self.customStoragePath = storagePath
    }

    private func typeKey<M: PersistentModel>(for type: M.Type) -> String {
        String(reflecting: type)
    }

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: storagePath)),
              let dict = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return
        }
        rawCollections = dict
    }

    public func save() {
        loadIfNeeded()
        if let encoded = try? JSONEncoder().encode(rawCollections) {
            try? encoded.write(to: URL(fileURLWithPath: storagePath), options: .atomic)
        }
    }

    public func clearAll() {
        isLoaded = true
        rawCollections.removeAll()
        try? FileManager.default.removeItem(atPath: storagePath)
        KindleStateRegistry.shared.notifyStateMutation()
    }

    internal func fetchModels<M: PersistentModel>(_ type: M.Type) -> [M] {
        loadIfNeeded()
        let key = typeKey(for: type)
        guard let data = rawCollections[key],
              let decoded = try? JSONDecoder().decode([M].self, from: data) else {
            return []
        }
        return decoded
    }

    internal func storeModels<M: PersistentModel>(_ models: [M], for type: M.Type) {
        loadIfNeeded()
        let key = typeKey(for: type)
        if let data = try? JSONEncoder().encode(models) {
            rawCollections[key] = data
            save()
            KindleStateRegistry.shared.notifyStateMutation()
        }
    }
}

/// Provides CRUD operations (`insert`, `delete`, `fetch`, `save`) for `PersistentModel` instances.
public final class ModelContext: @unchecked Sendable {
    public unowned let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch<M: PersistentModel>(
        _ type: M.Type = M.self,
        predicate: ((M) -> Bool)? = nil,
        sortBy: ((M, M) -> Bool)? = nil
    ) -> [M] {
        var items = container.fetchModels(type)
        if let predicate = predicate {
            items = items.filter(predicate)
        }
        if let sortBy = sortBy {
            items.sort(by: sortBy)
        }
        return items
    }

    public func insert<M: PersistentModel>(_ model: M) {
        var items = container.fetchModels(M.self)
        if let idx = items.firstIndex(where: { $0.id == model.id }) {
            items[idx] = model
        } else {
            items.append(model)
        }
        container.storeModels(items, for: M.self)
    }

    public func delete<M: PersistentModel>(_ model: M) {
        var items = container.fetchModels(M.self)
        items.removeAll { $0.id == model.id }
        container.storeModels(items, for: M.self)
    }

    public func delete<M: PersistentModel>(model type: M.Type, where predicate: ((M) -> Bool)? = nil) {
        if let predicate = predicate {
            var items = container.fetchModels(type)
            items.removeAll(where: predicate)
            container.storeModels(items, for: type)
        } else {
            container.storeModels([], for: type)
        }
    }

    public func save() {
        container.save()
    }
}

/// A property wrapper that fetches and automatically observes a collection of `PersistentModel` items from the active `ModelContainer`.
@propertyWrapper
public struct Query<Element: PersistentModel>: @unchecked Sendable {
    private let filter: ((Element) -> Bool)?
    private let sorter: ((Element, Element) -> Bool)?

    public init(
        filter: ((Element) -> Bool)? = nil,
        sortBy: ((Element, Element) -> Bool)? = nil
    ) {
        self.filter = filter
        self.sorter = sortBy
    }

    public init<Value: Comparable>(
        filter: ((Element) -> Bool)? = nil,
        sort keyPath: KeyPath<Element, Value>,
        order: SortOrder = .forward
    ) {
        self.filter = filter
        self.sorter = { a, b in
            let va = a[keyPath: keyPath]
            let vb = b[keyPath: keyPath]
            return order == .forward ? (va < vb) : (va > vb)
        }
    }

    public var wrappedValue: [Element] {
        KindleStateRegistry.shared.currentEnvironment.modelContext.fetch(
            Element.self,
            predicate: filter,
            sortBy: sorter
        )
    }
}



extension View {
    public func modelContainer(_ container: ModelContainer) -> some View {
        KindleStateRegistry.shared.defaultModelContainer = container
        return _EnvironmentModifiedView(content: self) { env in
            env.modelContext = container.mainContext
        }
    }

    /// Configures and injects a `ModelContainer` for the given `PersistentModel` type.
    public func modelContainer<M: PersistentModel>(
        for modelType: M.Type,
        storagePath: String? = nil
    ) -> some View {
        let container = storagePath != nil ? ModelContainer(storagePath: storagePath) : ModelContainer.shared
        return modelContainer(container)
    }
}
