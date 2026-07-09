import Foundation

public struct UsageWindow: Equatable {
    public var utilizationPct: Double // 0...100
    public var resetsAt: Date?

    public init(utilizationPct: Double, resetsAt: Date?) {
        self.utilizationPct = utilizationPct
        self.resetsAt = resetsAt
    }
}

public enum UsageParseError: Error, Equatable {
    case auth(String)
}

// Pure, platform-agnostic parsing logic for claude.ai usage responses.
public enum UsageParser {
    // Reads a usage window ({"utilization": Double, "resets_at": ISO8601 string})
    // into a `UsageWindow`. Returns nil for missing/garbage input.
    public static func parseWindow(from dict: [String: Any]?) -> UsageWindow? {
        guard let dict else { return nil }
        let pct = (dict["utilization"] as? NSNumber)?.doubleValue
            ?? (dict["utilization"] as? Double)
            ?? 0
        var reset: Date?
        if let s = dict["resets_at"] as? String {
            // The default ISO8601 formatter drops fractional seconds, so try a
            // fractional-seconds formatter first and fall back to the plain one.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            reset = formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return UsageWindow(utilizationPct: pct, resetsAt: reset)
    }

    // Accounts can have multiple orgs (e.g. an API-only org alongside the
    // claude.ai chat/Pro org). Usage limits only apply to the chat org, so pick
    // the org whose capabilities contain "chat", else fall back to the first.
    public static func selectChatOrgUUID(from orgs: [[String: Any]]) -> String? {
        let chatOrg = orgs.first { ($0["capabilities"] as? [String])?.contains("chat") == true }
        return (chatOrg ?? orgs.first)?["uuid"] as? String
    }

    // Both endpoints return {"type": "error", ...} bodies for auth problems.
    // Returns the error message when the payload is an error, else nil.
    public static func apiErrorMessage(in json: [String: Any]) -> String? {
        guard json["type"] as? String == "error" else { return nil }
        return (json["error"] as? [String: Any])?["message"] as? String ?? "Session expired."
    }
}
