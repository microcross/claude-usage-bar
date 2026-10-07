import Foundation
import UsageWidgetCore

// Checks GitHub's tags API (no releases are published for this repo, just
// tags — see build.sh/README) for a newer version than the running build.
// Plain URLSession is fine here, unlike claude.ai: api.github.com isn't
// behind Cloudflare's bot check.
struct UpdateChecker {
    private let tagsURL = URL(string: "https://api.github.com/repos/microcross/claude-usage-bar/tags")!

    func latestVersion() async -> String? {
        var request = URLRequest(url: tagsURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let tags = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        let names = tags.compactMap { $0["name"] as? String }
        return VersionCompare.latest(of: names)
    }
}
