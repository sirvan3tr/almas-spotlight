import AppKit
import AlmasSpotlightCore

final class SearchViewModel: ObservableObject {
    @Published private(set) var query: String = ""
    @Published private(set) var results: [AppEntry] = []
    @Published private(set) var recents: [AppEntry] = []
    @Published private(set) var selectedIndex: Int = 0

    var onDismiss: (() -> Void)?
    private let indexer: AppIndexer

    /// Items currently shown in the list — recents when idle, search results otherwise.
    var displayItems: [AppEntry] {
        query.isEmpty ? recents : results
    }

    init(indexer: AppIndexer = .shared) {
        self.indexer = indexer
        refreshRecents()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(indexDidChange),
            name: AppIndexWatcher.indexDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func indexDidChange() {
        refreshResults()
        refreshRecents()
    }

    /// Called directly by the NSTextField coordinator — no binding indirection.
    func updateQuery(_ newQuery: String) {
        query = newQuery
        selectedIndex = 0
        refreshResults()
    }

    func reset() {
        query         = ""
        results       = []
        selectedIndex = 0
        refreshRecents()
    }

    func moveSelection(_ delta: Int) {
        let items = displayItems
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
    }

    func launchSelected() {
        let items = displayItems
        guard selectedIndex < items.count else { return }
        launch(items[selectedIndex])
    }

    func launch(_ app: AppEntry) {
        RecentsStore.shared.record(app)
        NSWorkspace.shared.open(app.url)
        onDismiss?()
    }

    // MARK: - Private

    private func refreshResults() {
        selectedIndex = 0
        results = FuzzyMatcher.search(query: query, in: indexer.apps)
    }

    private func refreshRecents() {
        recents = RecentsStore.shared.recentEntries(from: indexer.apps)
    }
}
