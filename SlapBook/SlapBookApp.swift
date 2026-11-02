import AppKit
import SwiftUI

@main
struct SlapBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = SlapBookApp.makeModel()

    private static func makeModel() -> AppModel {
        // UI tests use a disposable preference suite and never overwrite a
        // person's sound library, counters, or settings in the real app.
        if ProcessInfo.processInfo.environment["SLAPBOOK_UI_TESTS"] == "1",
           let defaults = UserDefaults(suiteName: "com.nazardydyn.SlapBook.ui-tests") {
            defaults.removePersistentDomain(forName: "com.nazardydyn.SlapBook.ui-tests")
            return AppModel(defaults: defaults)
        }
        return AppModel()
    }

    var body: some Scene {
        Window("SlapBook Pro", id: "main") {
            ContentView(model: model)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 1060, height: 800)
        .windowResizability(.contentMinSize)
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
            Label("SlapBook Pro", systemImage: model.settings.muted ? "speaker.slash" : "laptopcomputer")
                .accessibilityLabel("SlapBook Pro")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
