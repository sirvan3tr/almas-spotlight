import AppKit
import SwiftUI
import AlmasSpotlightCore

/// Floating, borderless panel that hosts the search UI.
final class SearchPanel: NSPanel {
    private let viewModel = SearchViewModel()
    private var previousApp: NSRunningApplication?

    private let panelWidth: CGFloat  = 640
    private let topOffset: CGFloat   = 280

    // MARK: - Init

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 66),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    // MARK: - Configuration

    private func configure() {
        isFloatingPanel     = true
        level               = .floating
        backgroundColor     = .clear
        isOpaque            = false
        hasShadow           = true
        animationBehavior   = .utilityWindow
        collectionBehavior  = [.canJoinAllSpaces, .fullScreenAuxiliary]

        viewModel.onDismiss = { [weak self] in self?.hide() }

        let rootView = SearchView(model: viewModel) { [weak self] height in
            self?.resize(to: height)
        }
        contentView = NSHostingView(rootView: rootView)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Show / Hide / Toggle

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        viewModel.reset()
        position()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    func hide() {
        orderOut(nil)
        previousApp?.activate(options: [])
        previousApp = nil
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Layout

    private func position() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x  = sf.midX - panelWidth / 2
        let y  = sf.maxY - frame.height - topOffset
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resize(to height: CGFloat) {
        let origin = NSPoint(x: frame.minX, y: frame.maxY - height)
        setFrame(NSRect(origin: origin, size: NSSize(width: panelWidth, height: height)),
                 display: true, animate: false)
    }
}
