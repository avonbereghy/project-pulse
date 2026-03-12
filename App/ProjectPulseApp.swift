import SwiftUI
import AppKit

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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 900, height: 700)

        Settings {
            SettingsView()
                .environment(viewModel)
                .frame(minWidth: 500, minHeight: 400)
        }

        MenuBarExtra("ProjectPulse", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarView()
                .environment(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
