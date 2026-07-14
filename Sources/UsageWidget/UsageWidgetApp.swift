import SwiftUI
import ServiceManagement

// The status item is managed in AppKit (StatusItemController) rather than
// SwiftUI's MenuBarExtra because MenuBarExtra can't distinguish left-click
// (open the panel) from right-click (Refresh/Quit context menu).
@main
struct UsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = UsageModel()
        model.start()
        statusController = StatusItemController(model: model)

        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }
}
