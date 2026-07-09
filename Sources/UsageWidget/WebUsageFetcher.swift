import Foundation
import WebKit
import AppKit

// Plain URLSession requests get blocked by Cloudflare's bot challenge, even
// with the right cookie. An embedded WKWebView behaves like a real browser
// (runs the challenge JS) and gets through. We keep it off-screen in a
// borderless, invisible window.
@MainActor
final class WebUsageFetcher: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let window: NSWindow
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 480, height: 480), configuration: config)
        // Must stay within a real NSScreen's frame — far off-screen coordinates
        // (e.g. -4000,-4000) leave WebKit's compositor without a valid surface
        // and navigation silently never finishes (didFinish never fires).
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        window = NSWindow(contentRect: CGRect(x: screenFrame.minX, y: screenFrame.minY, width: 480, height: 480),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = webView
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.setIsVisible(true)
        super.init()
        webView.navigationDelegate = self
    }

    // The live cookie in WebKit's store; claude.ai can rotate it after login.
    func currentSessionKey() async -> String? {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        return cookies.first { $0.name == "sessionKey" && $0.domain.contains("claude.ai") }?.value
    }

    func fetchJSON(url: URL, sessionKey: String) async throws -> Data {
        try await setCookie(sessionKey: sessionKey)
        try await withTimeout(20) { try await self.load(url: url) }
        return try await extractBody()
    }

    private func setCookie(sessionKey: String) async throws {
        let props: [HTTPCookiePropertyKey: Any] = [
            .domain: ".claude.ai",
            .path: "/",
            .name: "sessionKey",
            .value: sessionKey,
            .secure: true
        ]
        guard let cookie = HTTPCookie(properties: props) else { return }
        await webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
    }

    private func load(url: URL) async throws {
        let navigation: Void = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            self.webView.load(URLRequest(url: url))
        }
        _ = navigation
    }

    private func withTimeout<T>(_ seconds: UInt64, _ op: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw UsageError.parse("Timed out waiting for claude.ai to respond")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    private func extractBody() async throws -> Data {
        for attempt in 0..<8 {
            let text = try await evalInnerText()
            let looksLikeChallenge = text.contains("Just a moment") || text.isEmpty
            if !looksLikeChallenge, let data = text.data(using: .utf8) {
                return data
            }
            if attempt == 7 {
                throw UsageError.parse("Blocked by Cloudflare's bot check. Open claude.ai in a real browser, stay signed in, then retry.")
            }
            try await Task.sleep(nanoseconds: 1_200_000_000)
        }
        throw UsageError.parse("Empty response from claude.ai")
    }

    private func evalInnerText() async throws -> String {
        let result = try await webView.evaluateJavaScript("document.body.innerText")
        return (result as? String) ?? ""
    }
}
