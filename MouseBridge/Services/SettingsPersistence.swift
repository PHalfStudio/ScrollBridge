import Foundation

final class SettingsPersistence {
    static let storageKey = "settings.v1"
    static let corruptBackupPrefix = "\(storageKey).corrupt."

    private let defaults: UserDefaults
    private(set) var lastLoadErrorCode: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        lastLoadErrorCode = nil
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .defaults
        }
        do {
            var settings = try JSONDecoder().decode(AppSettings.self, from: data)
            migrate(&settings)
            settings.normalize()
            return settings
        } catch {
            lastLoadErrorCode = "settings_load_corrupt"
            defaults.set(data, forKey: "\(Self.corruptBackupPrefix)\(Int(Date().timeIntervalSince1970))")
            return .defaults
        }
    }

    func save(_ settings: AppSettings) {
        var normalized = settings
        migrate(&normalized)
        normalized.normalize()
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func reset() -> AppSettings {
        defaults.removeObject(forKey: Self.storageKey)
        return .defaults
    }

    private func migrate(_ settings: inout AppSettings) {
        if settings.schemaVersion < AppSettings.currentSchemaVersion {
            settings.schemaVersion = AppSettings.currentSchemaVersion
        }
    }
}

final class RuntimeConfigBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: RuntimeConfigSnapshot = .disabled

    func update(_ newValue: RuntimeConfigSnapshot) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func snapshot() -> RuntimeConfigSnapshot {
        lock.lock()
        let current = value
        lock.unlock()
        return current
    }
}
