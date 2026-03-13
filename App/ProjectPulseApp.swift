import SwiftUI
import AppKit

@MainActor
class MenuBarManager {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: RepoListViewModel

    init(viewModel: RepoListViewModel) {
        self.viewModel = viewModel
    }

    var isVisible: Bool {
        statusItem != nil
    }

    func show() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "ProjectPulse")
        item.button?.action = #selector(togglePopover)
        item.button?.target = self

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 340, height: 500)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environment(viewModel)
        )

        statusItem = item
        popover = pop
    }

    func hide() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        popover = nil
    }

    func update(visible: Bool) {
        if visible {
            show()
        } else {
            hide()
        }
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ProjectPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = RepoListViewModel()
    @State private var menuBarManager: MenuBarManager?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    let manager = MenuBarManager(viewModel: viewModel)
                    menuBarManager = manager
                    manager.update(visible: viewModel.settings.showMenuBar)
                }
                .onChange(of: viewModel.settings.showMenuBar) { _, newValue in
                    menuBarManager?.update(visible: newValue)
                }
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .environment(viewModel)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}
