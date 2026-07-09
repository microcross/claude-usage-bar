import SwiftUI
import ServiceManagement

@main
struct UsageWidgetApp: App {
    @StateObject private var model = UsageModel()

    init() {
        // MenuBarExtra has no onAppear; kick off the first fetch + polling here.
        let m = UsageModel()
        _model = StateObject(wrappedValue: m)
        m.start()

        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            DetailView(model: model)
        } label: {
            MenuBarLabelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
