import AppKit
import SwiftUI
import AlmasSpotlightCore

// MARK: - Root view

struct SearchView: View {
    @ObservedObject var model: SearchViewModel
    let onHeightChange: (CGFloat) -> Void

    private let searchBarHeight: CGFloat = 66
    private let rowHeight: CGFloat       = 54
    private let maxVisible: Int          = 8

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !displayedResults.isEmpty {
                Divider().opacity(0.25)

                VStack(spacing: 0) {
                    ForEach(displayedResults) { app in
                        let isSelected = (model.results.firstIndex(of: app) == model.selectedIndex)
                        AppRow(app: app, isSelected: isSelected)
                            .contentShape(Rectangle())
                            .onTapGesture { model.launch(app) }
                    }
                }
                .frame(height: CGFloat(displayedResults.count) * rowHeight)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onChange(of: model.results) { _, newResults in
            onHeightChange(totalHeight(for: newResults.count))
        }
    }

    /// Cap visible results — simple Array slice, no LazyVStack or ScrollViewReader.
    private var displayedResults: [AppEntry] {
        Array(model.results.prefix(maxVisible))
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            SearchTextField(model: model)
                .frame(height: 34)

            if !model.query.isEmpty {
                Button {
                    model.updateQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: searchBarHeight)
    }

    // MARK: Helpers

    private func totalHeight(for count: Int) -> CGFloat {
        let divider: CGFloat = count > 0 ? 1 : 0
        return searchBarHeight + divider + CGFloat(min(count, maxVisible)) * rowHeight
    }
}

// MARK: - App row

struct AppRow: View {
    let app: AppEntry
    let isSelected: Bool

    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: app.url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)

            Text(app.name)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.18)
                : Color.clear
        )
    }
}

// MARK: - NSTextField wrapper — coordinator writes directly to ViewModel

struct SearchTextField: NSViewRepresentable {
    let model: SearchViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled          = false
        field.drawsBackground    = false
        field.focusRingType      = .none
        field.font               = .systemFont(ofSize: 22, weight: .light)
        field.placeholderString  = "Search apps…"
        field.cell?.wraps        = false
        field.cell?.isScrollable = true
        field.delegate           = context.coordinator
        context.coordinator.field = field
        context.coordinator.observeWindowKey(field)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        let modelQuery = model.query
        if modelQuery.isEmpty && !nsView.stringValue.isEmpty {
            nsView.stringValue = ""
        }
    }
}

// MARK: Coordinator

final class Coordinator: NSObject, NSTextFieldDelegate {
    private let model: SearchViewModel
    weak var field: NSTextField?
    private var windowObserver: NSObjectProtocol?

    init(model: SearchViewModel) {
        self.model = model
    }

    func observeWindowKey(_ field: NSTextField) {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak field] _ in
            guard let f = field else { return }
            DispatchQueue.main.async {
                f.window?.makeFirstResponder(f)
            }
        }
    }

    deinit {
        if let o = windowObserver { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        model.updateQuery(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            model.moveSelection(-1); return true
        case #selector(NSResponder.moveDown(_:)):
            model.moveSelection(1); return true
        case #selector(NSResponder.insertNewline(_:)):
            model.launchSelected(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            model.onDismiss?(); return true
        default:
            return false
        }
    }
}
