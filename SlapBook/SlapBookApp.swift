import AppKit
import SwiftUI

@main
struct SlapBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = SlapBookApp.makeModel()

    private static func makeModel() -> AppModel {
        // UI tests use a disposable preference suite and never overwrite a
        // person's sound library, counters, or settings in the real app.
        let model: AppModel
        if ProcessInfo.processInfo.environment["SLAPBOOK_UI_TESTS"] == "1",
           let defaults = UserDefaults(suiteName: "com.nazardydyn.SlapBook.ui-tests") {
            defaults.removePersistentDomain(forName: "com.nazardydyn.SlapBook.ui-tests")
            model = AppModel(defaults: defaults)
        } else {
            model = AppModel()
        }
        // The window may never appear (menu-bar-only launch), so the delegate
        // cannot rely on a view callback to learn about the model.
        AppDelegate.model = model
        return model
    }

    var body: some Scene {
        Window("SlapBook Pro", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(width: 1060, height: 800)
        .windowResizability(.contentMinSize)
        .launchBehavior(presented: model.settings.openWindowAtLaunch)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appSettings) {
                Button("Test Sound") { model.testSound() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarLabel(muted: model.settings.muted)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar label is the one view that exists even while no window is
/// open, so it hands the delegate a way to show the main window on reopen.
private struct MenuBarLabel: View {
    let muted: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Label("SlapBook Pro", systemImage: muted ? "speaker.slash" : "laptopcomputer")
            .accessibilityLabel("SlapBook Pro")
            .onAppear {
                AppDelegate.openMainWindow = {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}

private extension Scene {
    /// macOS 15 can suppress a window before it appears. On macOS 14 the
    /// delegate closes it right after launch instead.
    func launchBehavior(presented: Bool) -> some Scene {
        if #available(macOS 15.0, *) {
            return defaultLaunchBehavior(presented ? .presented : .suppressed)
        } else {
            return self
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: AppModel?
    static var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard #unavailable(macOS 15.0), Self.model?.settings.openWindowAtLaunch == false else { return }
        DispatchQueue.main.async {
            NSApp.windows.filter { $0.identifier?.rawValue.hasPrefix("main") == true }.forEach { $0.close() }
        }
    }

    /// With no Dock icon, opening the app again from Finder or Spotlight is
    /// the only visible way back to a closed window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.openMainWindow?() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { Self.model?.shutdown() }
}
