import Foundation
import CoreServices

/// Watches the app search roots and fires `onChange` (debounced) when any
/// mutation occurs — install, uninstall, rename, move.
///
/// Single responsibility: emit a signal. It does not touch the index itself.
public final class AppIndexWatcher {
    /// Posted on the main queue after the index has been refreshed by the
    /// callback wired up in `AppDelegate`. Consumers re-rank their current query.
    public static let indexDidChange = Notification.Name("AlmasSpotlight.indexDidChange")

    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.almas.spotlight.indexwatcher")
    private var debounce: DispatchWorkItem?

    public init(paths: [String], onChange: @escaping () -> Void) {
        self.paths = paths
        self.onChange = onChange
    }

    /// Starts the FSEvents stream. Fail-fast: if creation fails the caller
    /// keeps running with the startup index only; no silent half-state.
    @discardableResult
    public func start() -> Bool {
        guard stream == nil else { return true }

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            Unmanaged<AppIndexWatcher>.fromOpaque(info)
                .takeUnretainedValue()
                .schedule()
        }

        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &ctx,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagNoDefer |
                kFSEventStreamCreateFlagIgnoreSelf
            )
        ) else {
            return false
        }

        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        stream = s
        return true
    }

    private func schedule() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        queue.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    deinit {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
    }
}
