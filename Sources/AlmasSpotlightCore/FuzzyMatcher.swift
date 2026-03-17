import Foundation

/// Scored match result exposing the tier for diagnostics.
public struct MatchResult {
    public let entry: AppEntry
    public let score: Int
    public let tier: Tier

    public enum Tier: String {
        case exact       = "exact"
        case prefix      = "prefix"
        case wordStart   = "word-start"
        case substring   = "substring"
        case fuzzy       = "fuzzy"
    }
}

/// Pure, stateless fuzzy scoring. All methods are O(n·m) worst case.
public enum FuzzyMatcher {

    /// Returns entries ranked by score, highest first. Empty when query is blank.
    public static func search(query: String, in apps: [AppEntry]) -> [AppEntry] {
        rank(query: query, in: apps).map(\.entry)
    }

    /// Same as `search` but returns full `MatchResult` (score + tier) for diagnostics.
    public static func rank(query: String, in apps: [AppEntry]) -> [MatchResult] {
        let q = normalize(query)
        guard !q.isEmpty else { return [] }
        return apps
            .compactMap { match(q, app: $0) }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Internal (exposed for unit tests / CLI)

    static func match(_ query: String, app: AppEntry) -> MatchResult? {
        let name = normalize(app.name)
        guard let (score, tier) = scoreAndTier(query, name: name) else { return nil }
        return MatchResult(entry: app, score: score, tier: tier)
    }

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: .current)
            .lowercased()
    }

    // MARK: - Scoring tiers

    /// Returns (score, tier) or nil if no match at all.
    static func scoreAndTier(_ query: String, name: String) -> (Int, MatchResult.Tier)? {
        // Tier 1 – exact
        if name == query {
            return (1_000_000, .exact)
        }

        // Tier 2 – full prefix  ("spot" → "Spotify")
        // Score reward: each additional typed character raises score,
        // so longer queries correctly outrank shorter ones for the same app.
        if name.hasPrefix(query) {
            return (500_000 + query.count * 1_000, .prefix)
        }

        // Tier 3 – word-start prefix  ("sc" → "Screen Saver", "ms" → "Microsoft Word")
        if let ws = wordStartScore(query, in: name) {
            return (200_000 + ws, .wordStart)
        }

        // Tier 4 – substring  ("tify" → "Spotify")
        if name.contains(query) {
            return (50_000 + query.count * 500, .substring)
        }

        // Tier 5 – fuzzy subsequence  ("sptfy" → "Spotify")
        if let fs = fuzzyScore(query, in: name) {
            return (fs, .fuzzy)
        }

        return nil
    }

    // MARK: - Word-start scoring

    /// Returns a bonus when `query` is a prefix of any word in `name`.
    /// Words are separated by spaces, hyphens, dots, underscores, or CamelCase transitions.
    private static func wordStartScore(_ query: String, in name: String) -> Int? {
        for start in wordStarts(of: name) {
            let suffix = name[start...]
            if suffix.hasPrefix(query) {
                // Prefer matches that cover a larger fraction of the word.
                let wordLen = wordLength(from: start, in: name)
                return query.count * 800 + max(0, 50 - wordLen)
            }
        }
        return nil
    }

    /// Indices at which a new "word" begins.
    private static func wordStarts(of name: String) -> [String.Index] {
        guard !name.isEmpty else { return [] }
        var starts: [String.Index] = [name.startIndex]
        let separators: Set<Character> = [" ", "-", ".", "_"]

        var prev: Character = name[name.startIndex]
        var idx = name.index(after: name.startIndex)
        while idx < name.endIndex {
            let ch = name[idx]
            if separators.contains(prev) && !separators.contains(ch) {
                starts.append(idx)
            }
            prev = ch
            idx  = name.index(after: idx)
        }
        return starts
    }

    private static func wordLength(from start: String.Index, in name: String) -> Int {
        let separators: Set<Character> = [" ", "-", ".", "_"]
        var idx = start
        var len = 0
        while idx < name.endIndex && !separators.contains(name[idx]) {
            len += 1
            idx  = name.index(after: idx)
        }
        return len
    }

    // MARK: - Fuzzy scoring

    /// All query chars must appear in `name` in order.
    /// Score: position bonus (chars earlier = higher) + consecutive bonus.
    private static func fuzzyScore(_ query: String, in name: String) -> Int? {
        var nameIdx = name.startIndex
        var total   = 0
        var prev: String.Index? = nil

        for char in query {
            guard let found = name[nameIdx...].firstIndex(of: char) else { return nil }
            let pos = name.distance(from: name.startIndex, to: found)
            total += max(5, 40 - pos * 2) // earlier match → higher per-char score
            if let p = prev, name.index(after: p) == found { total += 80 } // consecutive
            prev    = found
            nameIdx = name.index(after: found)
        }

        return total > 0 ? total : nil
    }
}
