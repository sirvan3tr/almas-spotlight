import AppKit
import SwiftUI
import AlmasSpotlightCore

// MARK: - Root view

struct SearchView: View {
    @ObservedObject var model: SearchViewModel
    let onHeightChange: (CGFloat) -> Void

    private let searchBarHeight:  CGFloat = 66
    private let rowHeight:        CGFloat = 54
    private let headerHeight:     CGFloat = 28
    private let noResultsHeight:  CGFloat = 54
    private let maxVisible:       Int     = 8

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            listContent
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onAppear { onHeightChange(currentHeight()) }
        .onChange(of: model.results) { _, _ in onHeightChange(currentHeight()) }
        .onChange(of: model.query)   { _, _ in onHeightChange(currentHeight()) }
        .onChange(of: model.recents) { _, _ in onHeightChange(currentHeight()) }
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        if model.query.isEmpty {
            if !model.recents.isEmpty {
                Divider().opacity(0.25)
                sectionHeader("Recent")
                appRows(model.recents)
            }
        } else if model.results.isEmpty {
            Divider().opacity(0.25)
            noResultsView
        } else {
            Divider().opacity(0.25)
            appRows(Array(model.results.prefix(maxVisible)))
        }
    }

    @ViewBuilder
    private func appRows(_ apps: [AppEntry]) -> some View {
        VStack(spacing: 0) {
            ForEach(apps) { app in
                let isSelected = model.displayItems.firstIndex(of: app) == model.selectedIndex
                AppRow(app: app, isSelected: isSelected)
                    .contentShape(Rectangle())
                    .onTapGesture { model.launch(app) }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: headerHeight)
    }

    private var noResultsView: some View {
        Text("No apps found")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: noResultsHeight)
    }

    // MARK: - Search bar

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

    // MARK: - Height calculation

    private func currentHeight() -> CGFloat {
        if model.query.isEmpty {
            guard !model.recents.isEmpty else { return searchBarHeight }
            return searchBarHeight + 1 + headerHeight + CGFloat(model.recents.count) * rowHeight
        } else if model.results.isEmpty {
            return searchBarHeight + 1 + noResultsHeight
        } else {
            let count = min(model.results.count, maxVisible)
            return searchBarHeight + 1 + CGFloat(count) * rowHeight
        }
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
