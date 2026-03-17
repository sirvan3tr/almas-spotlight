import Foundation
import AlmasSpotlightCore

// MARK: - Entry point

let args = CommandLine.arguments.dropFirst()

if args.isEmpty {
    runInteractive()
} else {
    let query = args.joined(separator: " ")
    runOnce(query: query)
}

// MARK: - Modes

func runOnce(query: String) {
    let apps = AppIndexer.shared.indexSync()
    printResults(for: query, in: apps)
}

func runInteractive() {
    let apps = AppIndexer.shared.indexSync()
    print("Indexed \(apps.count) apps. Type a query (empty line to quit):\n")

    while let line = readLine(strippingNewline: true), !line.isEmpty {
        printResults(for: line, in: apps)
        print()
    }
}

// MARK: - Display

func printResults(for query: String, in apps: [AppEntry]) {
    let results = FuzzyMatcher.rank(query: query, in: apps)

    if results.isEmpty {
        print("  (no matches for \"\(query)\")")
        return
    }

    let header = "Results for \"\(query)\" — \(results.count) match(es)"
    print(header)
    print(String(repeating: "─", count: header.count))

    let top = results.prefix(10)
    for (i, r) in top.enumerated() {
        let rank  = String(format: "%2d", i + 1)
        let name  = r.entry.name.padding(toLength: 30, withPad: " ", startingAt: 0)
        let score = String(format: "%8d", r.score)
        let tier  = "[\(r.tier.rawValue)]"
        print("  \(rank). \(name) \(score)  \(tier)")
    }

    if results.count > 10 {
        print("  … and \(results.count - 10) more")
    }
}
