import Foundation

// Session key is read from ~/.claude-usage-widget/session_key — a plain text
// file containing the `sessionKey` cookie value copied from claude.ai
// (DevTools → Application → Cookies → claude.ai → sessionKey).
public enum SessionKeyStore {
    public static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-usage-widget/session_key")
    }

    public static func read(from url: URL = fileURL) -> String? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func write(_ key: String, to url: URL = fileURL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        try? key.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
