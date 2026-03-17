# Almas Spotlight

A minimal macOS app launcher to replace Spotlight's broken app search. Fuzzy-searches all your installed applications, indexed at startup. No Electron, no daemons, no telemetry — 313 KB native Swift binary.

## What it looks like

Open with **Option+Space**, type to filter, ↩ to launch, ⎋ or click away to dismiss.

## Requirements

- macOS 14 Sonoma or later
- Xcode Command Line Tools: `xcode-select --install`

## Install

```sh
git clone https://github.com/sirvan3tr/almas-spotlight.git
cd almas-spotlight
make install
open ~/Applications/AlmasSpotlight.app
```

The app runs silently in the background with no dock icon.

## Hotkey

Default is **Option+Space**. To use **Cmd+Space** instead:

1. System Settings → Keyboard → Keyboard Shortcuts → Spotlight → uncheck "Show Spotlight search"
2. In `Sources/AlmasSpotlight/AppDelegate.swift` change `modifiers: 2048` → `modifiers: 256`
3. `make restart`

## Keyboard shortcuts

| Key             | Action                      |
| --------------- | --------------------------- |
| Type            | Fuzzy-search installed apps |
| ↑ / ↓           | Move selection              |
| ↩               | Launch                      |
| ⎋ or click away | Dismiss                     |

## Make targets

```sh
make install    # build release + copy to ~/Applications
make restart    # rebuild, reinstall, and relaunch
make kill       # force-quit the running instance
make run        # debug run (logs to terminal)
make search     # interactive fuzzy-search CLI tester
make search q=spotify   # single query against your real app index
make clean      # remove build artefacts
```

## How the fuzzy search works

Results are ranked in tiers — the score increases the more you type, so the right app always surfaces:

| Tier       | Example query → match | Score                 |
| ---------- | --------------------- | --------------------- |
| Exact      | `"spotify"` → Spotify | 1 000 000             |
| Prefix     | `"spot"` → Spotify    | 500 000 + len × 1 000 |
| Word-start | `"sc"` → Screen Saver | 200 000 + len × 800   |
| Substring  | `"tify"` → Spotify    | 50 000 + len × 500    |
| Fuzzy      | `"sptfy"` → Spotify   | position-weighted     |

Use `make search` to inspect scores interactively against your real app index.

## Project layout

```
Sources/
├── AlmasSpotlightCore/     # shared library (no UI)
│   ├── AppIndexer.swift    # scans /Applications etc., deduped + sorted
│   └── FuzzyMatcher.swift  # pure scoring functions
├── AlmasSpotlight/         # macOS app
│   ├── main.swift
│   ├── AppDelegate.swift
│   ├── HotkeyManager.swift # Carbon RegisterEventHotKey (no Accessibility needed)
│   ├── SearchPanel.swift   # floating NSPanel
│   ├── SearchViewModel.swift
│   └── SearchView.swift    # SwiftUI + NSTextField delegate
└── almas-search/           # CLI fuzzy-search tester
    └── main.swift
```

See [docs/architecture.md](docs/architecture.md) for a full data-flow diagram.

## License

MIT
