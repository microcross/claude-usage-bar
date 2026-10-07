import Foundation

// Pure, platform-agnostic semver-ish comparison for GitHub tag names like
// "v1.2.0" (and bare "1.2.0" app version strings, e.g. CFBundleShortVersionString).
public enum VersionCompare {
    // "v1.2.0" -> [1, 2, 0]. Returns nil for anything that isn't a dotted run
    // of integers (pre-release suffixes, branch names used as tags, etc.) so
    // callers can filter out tags that aren't real releases.
    public static func components(_ raw: String) -> [Int]? {
        let trimmed = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.map { $0! }
    }

    public static func isNewer(_ a: String, than b: String) -> Bool {
        guard let ca = components(a), let cb = components(b) else { return false }
        for i in 0..<max(ca.count, cb.count) {
            let x = i < ca.count ? ca[i] : 0
            let y = i < cb.count ? cb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // Highest valid version among a set of raw tag names, ignoring anything
    // that doesn't parse as a dotted integer version.
    public static func latest(of tags: [String]) -> String? {
        var best: String?
        for tag in tags where components(tag) != nil {
            if best == nil || isNewer(tag, than: best!) {
                best = tag
            }
        }
        return best
    }
}
