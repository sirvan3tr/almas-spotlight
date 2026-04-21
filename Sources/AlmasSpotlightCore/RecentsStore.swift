import Foundation

/// Persists the most-recently launched apps across sessions (max 6).
public final class RecentsStore {
    public static let shared = RecentsStore()

    private static let defaultsKey = "com.almas.spotlight.recents"
    private static let maxCount    = 6

    private init() {}

    /// Records a launch, promoting the app to the top of the recents list.
    public func record(_ app: AppEntry) {
        var paths = storedPaths()
        paths.removeAll { $0 == app.url.path }
        paths.insert(app.url.path, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(Self.maxCount)), forKey: Self.defaultsKey)
    }

    /// Returns entries that still exist in the current index, in most-recent-first order.
    public func recentEntries(from index: [AppEntry]) -> [AppEntry] {
        let lookup = Dictionary(uniqueKeysWithValues: index.map { ($0.url.path, $0) })
        return storedPaths().compactMap { lookup[$0] }
    }

    private func storedPaths() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
    }
}
