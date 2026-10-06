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
        // Belt-and-suspenders for LSUIElement: if the app ever runs without
        // Info.plist (e.g. `swift run` during development), SwiftUI has
        // nothing to show but the empty `Settings` scene and opens it as a
        // blank "UsageWidget Settings" window on launch. Setting the
        // activation policy in code keeps it an accessory app either way.
        NSApp.setActivationPolicy(.accessory)
        let model = UsageModel()
        model.start()
        statusController = StatusItemController(model: model)

        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }
}
