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

/// Pure, stateless fuzzy scoring.
///
/// Both query and app names are reduced to `[Unicode.Scalar]` before scoring:
///   - app names are pre-normalised once at index time (see `AppEntry.searchScalars`)
///   - the query is normalised once per search, not per app
///
/// All tier helpers use Int indexing on contiguous scalar arrays, avoiding
/// O(n) `String.Index` walks that dominated the old `O(n²)` fuzzy path.
public enum FuzzyMatcher {

    /// Returns entries ranked by score, highest first. Empty when query is blank.
    public static func search(query: String, in apps: [AppEntry]) -> [AppEntry] {
        rank(query: query, in: apps).map(\.entry)
    }

    /// Same as `search` but returns full `MatchResult` (score + tier) for diagnostics.
    public static func rank(query: String, in apps: [AppEntry]) -> [MatchResult] {
        let q = normalizeScalars(query)
        guard !q.isEmpty else { return [] }

        var results: [MatchResult] = []
        results.reserveCapacity(min(apps.count, 64))
        for app in apps {
            if let m = match(q, app: app) { results.append(m) }
        }
        results.sort { $0.score > $1.score }
        return results
    }

    // MARK: - Internal (exposed for unit tests / CLI)

    static func match(_ query: [Unicode.Scalar], app: AppEntry) -> MatchResult? {
        guard let (score, tier) = scoreAndTier(query, name: app.searchScalars) else { return nil }
        return MatchResult(entry: app, score: score, tier: tier)
    }

    /// Case/diacritic/width-folded, lowercased, whitespace-trimmed scalar form.
    /// Called once per app at index time and once per query at search time.
    public static func normalizeScalars(_ text: String) -> [Unicode.Scalar] {
        let folded = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: .current)
            .lowercased()
        return Array(folded.unicodeScalars)
    }

    // MARK: - Scoring tiers

    /// Returns (score, tier) or nil if no match at all.
    static func scoreAndTier(_ query: [Unicode.Scalar],
                             name: [Unicode.Scalar]) -> (Int, MatchResult.Tier)? {
        // Tier 1 – exact
        if name == query {
            return (1_000_000, .exact)
        }

        // Tier 2 – full prefix  ("spot" → "Spotify")
        if hasPrefix(query, in: name) {
            return (500_000 + query.count * 1_000, .prefix)
        }

        // Tier 3 – word-start prefix  ("sc" → "Screen Saver", "ms" → "Microsoft Word")
        if let ws = wordStartScore(query, in: name) {
            return (200_000 + ws, .wordStart)
        }

        // Tier 4 – substring  ("tify" → "Spotify")
        if containsSeq(query, in: name) {
            return (50_000 + query.count * 500, .substring)
        }

        // Tier 5 – fuzzy subsequence  ("sptfy" → "Spotify")
        if let fs = fuzzyScore(query, in: name) {
            return (fs, .fuzzy)
        }

        return nil
    }

    // MARK: - Scalar-array primitives

    private static func hasPrefix(_ prefix: [Unicode.Scalar],
                                  in s: [Unicode.Scalar]) -> Bool {
        let n = prefix.count
        guard n <= s.count else { return false }
        for i in 0..<n where prefix[i] != s[i] { return false }
        return true
    }

    private static func containsSeq(_ needle: [Unicode.Scalar],
                                    in s: [Unicode.Scalar]) -> Bool {
        let n = needle.count
        let m = s.count
        if n == 0 { return true }
        if n > m  { return false }
        let last = m - n
        let first = needle[0]
        var i = 0
        while i <= last {
            if s[i] == first {
                var j = 1
                while j < n && s[i + j] == needle[j] { j += 1 }
                if j == n { return true }
            }
            i += 1
        }
        return false
    }

    // MARK: - Word-start scoring

    private static let separators: Set<Unicode.Scalar> = [" ", "-", ".", "_"]

    /// Returns a bonus when `query` is a prefix of any word in `name`.
    /// Words are separated by space, hyphen, dot, or underscore.
    private static func wordStartScore(_ query: [Unicode.Scalar],
                                       in name: [Unicode.Scalar]) -> Int? {
        let nameLen = name.count
        let qLen    = query.count
        guard qLen > 0, qLen <= nameLen else { return nil }

        var start = 0
        while start <= nameLen - qLen {
            let atWordStart = (start == 0) || separators.contains(name[start - 1])
            if atWordStart {
                var ok = true
                for k in 0..<qLen where name[start + k] != query[k] {
                    ok = false; break
                }
                if ok {
                    var end = start
                    while end < nameLen && !separators.contains(name[end]) { end += 1 }
                    let wordLen = end - start
                    return qLen * 800 + max(0, 50 - wordLen)
                }
            }
            start += 1
        }
        return nil
    }

    // MARK: - Fuzzy scoring

    /// All query scalars must appear in `name` in order.
    /// Score: position bonus (earlier = higher) + consecutive bonus.
    private static func fuzzyScore(_ query: [Unicode.Scalar],
                                   in name: [Unicode.Scalar]) -> Int? {
        let nameLen = name.count
        var cursor  = 0
        var total   = 0
        var prev    = -2 // impossible adjacency so the first char never triggers the consecutive bonus

        for char in query {
            var found = -1
            var i = cursor
            while i < nameLen {
                if name[i] == char { found = i; break }
                i += 1
            }
            if found == -1 { return nil }
            total += max(5, 40 - found * 2)
            if prev + 1 == found { total += 80 }
            prev   = found
            cursor = found + 1
        }

        return total > 0 ? total : nil
    }
}
