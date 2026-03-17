import Foundation

/// An immutable record of a discovered application bundle.
public struct AppEntry: Identifiable, Hashable {
    public var id: URL { url }
    public let name: String
    public let url: URL

    public func hash(into hasher: inout Hasher) { hasher.combine(url) }
    public static func == (lhs: AppEntry, rhs: AppEntry) -> Bool { lhs.url == rhs.url }
}

/// Scans well-known app directories and builds a deduplicated, sorted index.
public final class AppIndexer {
    public static let shared = AppIndexer()

    public private(set) var apps: [AppEntry] = []

    private static let searchRoots: [URL] = {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            home.appendingPathComponent("Applications"),
        ]
    }()

    private init() {}

    /// Synchronous indexing for app startup — fail-fast, fully loaded state.
    public func indexNow() {
        apps = buildIndex()
    }

    /// Returns the index without storing it. Used by the CLI.
    public func indexSync() -> [AppEntry] {
        buildIndex()
    }

    private func buildIndex() -> [AppEntry] {
        var discovered: [AppEntry] = []
        let fm = FileManager.default
        for root in Self.searchRoots {
            scan(dir: root, into: &discovered, fm: fm, depth: 0)
        }
        var seen = Set<URL>()
        return discovered
            .filter { seen.insert($0.url).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scan(dir: URL, into result: inout [AppEntry], fm: FileManager, depth: Int) {
        guard depth < 3,
              let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        for url in contents {
            if url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                result.append(AppEntry(name: name, url: url))
            } else {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDir { scan(dir: url, into: &result, fm: fm, depth: depth + 1) }
            }
        }
    }
}
