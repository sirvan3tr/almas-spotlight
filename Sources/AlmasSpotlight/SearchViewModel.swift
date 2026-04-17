import AppKit
import AlmasSpotlightCore

final class SearchViewModel: ObservableObject {
    @Published private(set) var query: String = ""
    @Published private(set) var results: [AppEntry] = []
    @Published private(set) var selectedIndex: Int = 0

    var onDismiss: (() -> Void)?
    private let indexer: AppIndexer

    init(indexer: AppIndexer = .shared) {
        self.indexer = indexer
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
    }

    /// Called directly by the NSTextField coordinator — no binding indirection.
    func updateQuery(_ newQuery: String) {
        query = newQuery
        refreshResults()
    }

    func reset() {
        query         = ""
        results       = []
        selectedIndex = 0
    }

    func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
    }

    func launchSelected() {
        guard selectedIndex < results.count else { return }
        launch(results[selectedIndex])
    }

    func launch(_ app: AppEntry) {
        NSWorkspace.shared.open(app.url)
        onDismiss?()
    }

    // MARK: - Private

    private func refreshResults() {
        selectedIndex = 0
        results = FuzzyMatcher.search(query: query, in: indexer.apps)
    }
}
