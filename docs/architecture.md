# Almas Spotlight — Architecture

A minimal macOS app-launcher that replaces Spotlight's app-search with a fast, fuzzy-matched panel.

## Hotkey

Default: **Option+Space** (`keyCode 49, modifiers 2048`).

To use **Cmd+Space** instead:
1. Open **System Settings → Keyboard → Keyboard Shortcuts → Spotlight**
2. Uncheck "Show Spotlight search"
3. Change `modifiers: 2048` → `256` in `AppDelegate.swift`

## Component Map

```
main.swift
  └─ AppDelegate
       ├─ AppIndexer.shared.indexNow()    ← synchronous startup scan
       ├─ AppIndexWatcher                 ← FSEvents watcher on searchRoots
       ├─ HotkeyManager                  ← Carbon RegisterEventHotKey
       └─ SearchPanel (NSPanel)
            ├─ SearchViewModel            ← ObservableObject
            │    ├─ FuzzyMatcher          ← pure scoring functions
            │    └─ AppIndexer.shared     ← app list (plain var, updated via notification)
            └─ SearchView (SwiftUI)
                 ├─ SearchTextField       ← NSViewRepresentable
                 │    └─ Coordinator      ← NSTextFieldDelegate (↑↓↩⎋)
                 └─ AppRow
```

## Data flow

### Keystroke → results

```
HotkeyManager ──fires──▶ SearchPanel.toggle()
                              │
                        show: NSApp.activate
                              │
                   User types ▼
                   SearchTextField ──delegate──▶ SearchViewModel.updateQuery()
                                                       │
                                               FuzzyMatcher.search()
                                                       │
                                               @Published results
                                                       │
                                         SearchView re-renders rows
                                                       │
                                          User presses ↩
                                                       │
                                         NSWorkspace.open(app.url)
                                         SearchPanel.hide()
```

### Live reindex (app install / uninstall)

```
FSEvents kernel stream
  └─ AppIndexWatcher (background DispatchQueue)
       │  debounced 1 s, directory-level events only
       ▼
  AppIndexer.reindexInBackground()
       │  scan runs on DispatchQueue.global(.utility)
       ▼
  DispatchQueue.main: AppIndexer.shared.apps = fresh
       │
       ▼
  NotificationCenter.post(AppIndexWatcher.indexDidChange)
       │
       ▼
  SearchViewModel.indexDidChange()
       └─ refreshResults() — re-ranks current query against updated list
```

## App indexing

`AppIndexer` scans these roots (depth ≤ 3):

| Path | Notes |
|---|---|
| `/Applications` | Third-party apps |
| `/System/Applications` | Apple apps |
| `/System/Applications/Utilities` | System utilities |
| `/System/Library/CoreServices` | Finder, SystemUIServer, etc. |
| `~/Applications` | Per-user installs |

Results are deduplicated by URL and sorted case-insensitively. Search input is trimmed and normalized before ranking. Icons are resolved lazily in the UI, so the background index stays data-only.

## Fuzzy scoring

| Condition | Score |
|---|---|
| Exact match | 1 000 000 |
| Prefix match | 500 000 + `query.count * 1 000` |
| Word-start prefix | 200 000 + word-start bonus |
| Substring match | 50 000 + `query.count * 500` |
| Fuzzy (chars in order) | earlier-position bonus + consecutive bonus |

## Build

```sh
make          # swift build -c release
make app      # wraps binary in AlmasSpotlight.app
make install  # copies .app to ~/Applications
make run      # debug run without .app bundle
```
