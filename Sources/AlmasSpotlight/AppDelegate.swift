import AppKit
import AlmasSpotlightCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var searchPanel: SearchPanel?
    private var hotkeyManager: HotkeyManager?
    private var indexWatcher: AppIndexWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        AppIndexer.shared.indexNow()

        let panel = SearchPanel()
        self.searchPanel = panel

        // Option+Space: keyCode 49, modifiers = optionKey (2048)
        // To use Cmd+Space instead, set modifiers to cmdKey (256)
        // after disabling the system Spotlight shortcut in System Settings > Keyboard.
        hotkeyManager = HotkeyManager(keyCode: 49, modifiers: 2048) { [weak panel] in
            panel?.toggle()
        }

        let watcher = AppIndexWatcher(paths: AppIndexer.searchRootPaths) {
            AppIndexer.shared.reindexInBackground {
                NotificationCenter.default.post(
                    name: AppIndexWatcher.indexDidChange, object: nil)
            }
        }
        watcher.start()
        self.indexWatcher = watcher
    }
}
