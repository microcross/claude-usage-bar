import AppKit
import SwiftUI
import Combine
import UsageWidgetUI

// Owns the NSStatusItem. Left-click toggles the frosted NSPopover panel;
// right-click pops a context menu with Refresh and Quit.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let model: UsageModel
    private var cancellables = Set<AnyCancellable>()

    init(model: UsageModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DetailView(model: model))

        if let button = statusItem.button {
            button.image = MenuBarIcon.image(session: nil, weekly: nil)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.$session.combineLatest(model.$weekly)
            .receive(on: RunLoop.main)
            .sink { [weak self] session, weekly in
                guard let self else { return }
                Task { @MainActor in
                    self.statusItem.button?.image = MenuBarIcon.image(
                        session: session?.utilizationPct,
                        weekly: weekly?.utilizationPct)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Assigning statusItem.menu makes the NEXT click open the menu, so set it,
    // synthesize that click, then clear it to keep left-click on the popover.
    private func showContextMenu() {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit UsageWidget", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshAction() { model.refresh() }
    @objc private func quitAction() { NSApplication.shared.terminate(nil) }
}
