import Foundation
import Combine

struct UsageWindow {
    var utilizationPct: Double // 0...100
    var resetsAt: Date?
}

@MainActor
final class UsageModel: ObservableObject {
    @Published var session: UsageWindow?   // five_hour window
    @Published var weekly: UsageWindow?    // seven_day window
    @Published var weeklyOpus: UsageWindow? // seven_day_opus window
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var needsLogin = false

    private var orgID: String?
    private var timer: Timer?
    private var isLoading = false
    private lazy var fetcher = WebUsageFetcher()
    private let loginWindow = LoginWindow()

    func signIn() {
        loginWindow.show { [weak self] key in
            guard let self else { return }
            if let key {
                SessionKeyStore.write(key)
                self.needsLogin = false
                self.orgID = nil
                self.refresh()
            }
        }
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func refresh() {
        Task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        guard let key = SessionKeyStore.read() else {
            needsLogin = true
            errorMessage = "Not signed in."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let org = try await resolveOrgID(sessionKey: key)
            let usage = try await fetchUsage(orgID: org, sessionKey: key)
            apply(usage)
            errorMessage = nil
            needsLogin = false
            lastUpdated = Date()
            // claude.ai occasionally rotates the session cookie; persist the
            // live one so the on-disk key doesn't go stale.
            if let liveKey = await fetcher.currentSessionKey(), liveKey != key {
                SessionKeyStore.write(liveKey)
            }
        } catch UsageError.auth(let msg) {
            needsLogin = true
            errorMessage = msg
        } catch {
            errorMessage = "\(error.localizedDescription)"
            FileHandle.standardError.write("UsageWidget error: \(error)\n".data(using: .utf8)!)
        }
    }

    // Both endpoints return {"type": "error", ...} bodies for auth problems.
    private func checkForAPIError(_ json: [String: Any]) throws {
        guard json["type"] as? String == "error" else { return }
        let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Session expired."
        throw UsageError.auth(message)
    }

    private func resolveOrgID(sessionKey: String) async throws -> String {
        if let cached = orgID { return cached }
        let url = URL(string: "https://claude.ai/api/organizations")!
        let data = try await fetcher.fetchJSON(url: url, sessionKey: sessionKey)
        if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            try checkForAPIError(errJson)
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw UsageError.parse("Could not find an organization id in response")
        }
        // Accounts can have multiple orgs (e.g. an API-only org alongside the
        // claude.ai chat/Pro org). Usage limits only apply to the chat org.
        let chatOrg = arr.first { ($0["capabilities"] as? [String])?.contains("chat") == true }
        guard let uuid = (chatOrg ?? arr.first)?["uuid"] as? String else {
            throw UsageError.parse("Could not find an organization id in response")
        }
        orgID = uuid
        return uuid
    }

    private func fetchUsage(orgID: String, sessionKey: String) async throws -> [String: Any] {
        let url = URL(string: "https://claude.ai/api/organizations/\(orgID)/usage")!
        let data = try await fetcher.fetchJSON(url: url, sessionKey: sessionKey)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.parse("Unexpected usage response shape")
        }
        try checkForAPIError(json)
        return json
    }

    private func apply(_ json: [String: Any]) {
        session = window(from: json["five_hour"])
        weekly = window(from: json["seven_day"])
        weeklyOpus = window(from: json["seven_day_opus"])
    }

    private func window(from raw: Any?) -> UsageWindow? {
        guard let dict = raw as? [String: Any] else { return nil }
        let pct = (dict["utilization"] as? NSNumber)?.doubleValue
            ?? (dict["utilization"] as? Double)
            ?? 0
        var reset: Date?
        if let s = dict["resets_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            reset = formatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return UsageWindow(utilizationPct: pct, resetsAt: reset)
    }
}

enum UsageError: LocalizedError {
    case http(Int)
    case parse(String)
    case auth(String)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Request failed (HTTP \(code)). Session key may be expired."
        case .parse(let msg): return msg
        case .auth(let msg): return msg
        }
    }
}
