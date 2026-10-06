import Foundation
import Combine
import UsageWidgetCore
import UsageWidgetUI

@MainActor
final class UsageModel: ObservableObject {
    @Published var session: UsageWindow?   // five_hour window
    @Published var weekly: UsageWindow?    // seven_day window
    @Published var weeklyOpus: UsageWindow? // seven_day_opus window
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var needsLogin = false
    @Published var updateAvailable: String?

    private var orgID: String?
    private var timer: Timer?
    private var updateTimer: Timer?
    private var isLoading = false
    private lazy var fetcher = WebUsageFetcher()
    private let updateChecker = UpdateChecker()

    func logOut() {
        SessionKeyStore.delete()
        session = nil
        weekly = nil
        weeklyOpus = nil
        lastUpdated = nil
        orgID = nil
        needsLogin = true
        errorMessage = "Not signed in."
    }

    // Connect by pasting the sessionKey cookie value copied from the browser's
    // DevTools. (An embedded login window can't be used because Google/SSO
    // providers block OAuth inside embedded WebViews.)
    func saveManualKey(_ raw: String) {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        SessionKeyStore.write(key)
        needsLogin = false
        orgID = nil
        refresh()
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }

        checkForUpdate()
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.checkForUpdate() }
        }
    }

    func refresh() {
        Task { await load() }
    }

    // Once per launch and once a day after that; a stale "update available"
    // notice for days isn't useful, but there's no need to hammer the GitHub
    // API either.
    private func checkForUpdate() {
        Task {
            guard let latest = await updateChecker.latestVersion() else { return }
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            if VersionCompare.isNewer(latest, than: current) {
                updateAvailable = latest
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        guard let storedKey = SessionKeyStore.read() else {
            needsLogin = true
            errorMessage = "Not signed in."
            return
        }
        isLoading = true
        defer { isLoading = false }

        // A fresh paste can race claude.ai rotating the cookie (or just hit a
        // slow first pass through Cloudflare's challenge), so an auth failure
        // gets one immediate retry using whatever key is actually live in the
        // WKWebView's cookie jar — which may differ from what's on disk —
        // before we surface it as a real failure.
        for attempt in 0..<2 {
            let key = attempt == 0 ? storedKey : (await fetcher.currentSessionKey() ?? storedKey)
            do {
                try await attemptLoad(key: key)
                return
            } catch UsageError.auth(let msg) {
                orgID = nil
                if attempt == 0 { continue }
                needsLogin = true
                errorMessage = msg
            } catch {
                errorMessage = "\(error.localizedDescription)"
                FileHandle.standardError.write("UsageWidget error: \(error)\n".data(using: .utf8)!)
                return
            }
        }
    }

    // claude.ai occasionally rotates the session cookie mid-flow. Each
    // fetchJSON call pins the WKWebView's cookie to whatever key we pass it,
    // so re-using the on-disk key for the second request would clobber a
    // rotation picked up during the first and fail auth with a stale key.
    // Re-read the live cookie after every request and thread it forward
    // instead.
    private func attemptLoad(key initialKey: String) async throws {
        var key = initialKey
        let org = try await resolveOrgID(sessionKey: key)
        key = await fetcher.currentSessionKey() ?? key
        let usage = try await fetchUsage(orgID: org, sessionKey: key)
        key = await fetcher.currentSessionKey() ?? key
        apply(usage)
        errorMessage = nil
        needsLogin = false
        lastUpdated = Date()
        if key != SessionKeyStore.read() {
            SessionKeyStore.write(key)
        }
    }

    // Both endpoints return {"type": "error", ...} bodies for auth problems.
    private func checkForAPIError(_ json: [String: Any]) throws {
        if let message = UsageParser.apiErrorMessage(in: json) {
            throw UsageError.auth(message)
        }
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
        guard let uuid = UsageParser.selectChatOrgUUID(from: arr) else {
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
        session = UsageParser.parseWindow(from: json["five_hour"] as? [String: Any])
        weekly = UsageParser.parseWindow(from: json["seven_day"] as? [String: Any])
        weeklyOpus = UsageParser.parseWindow(from: json["seven_day_opus"] as? [String: Any])
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
