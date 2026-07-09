import AppKit
import WebKit

// Visible sign-in window for when the stored sessionKey is missing/expired.
// The user logs in to claude.ai normally; we watch the cookie store until a
// sessionKey cookie appears, persist it, and hand control back to the model.
@MainActor
final class LoginWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var pollTimer: Timer?
    private var onComplete: ((String?) -> Void)?

    func show(onComplete: @escaping (String?) -> Void) {
        // Already open: just re-focus it.
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        self.onComplete = onComplete

        let webView = WKWebView(frame: .zero)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Sign in to Claude"
        window.contentView = webView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        self.webView = webView

        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForSessionKey() }
        }
    }

    private func checkForSessionKey() {
        guard let webView else { return }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self,
                  let key = cookies.first(where: { $0.name == "sessionKey" && $0.domain.contains("claude.ai") })?.value,
                  !key.isEmpty
            else { return }
            Task { @MainActor in self.finish(with: key) }
        }
    }

    private func finish(with key: String?) {
        pollTimer?.invalidate()
        pollTimer = nil
        let done = onComplete
        onComplete = nil
        window?.delegate = nil
        window?.close()
        window = nil
        webView = nil
        done?(key)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.finish(with: nil) }
    }
}
