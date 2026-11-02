import Foundation
import XCTest

final class SlapBookUITests: XCTestCase {
    @MainActor
    func testHardwareIndependentSoundPreview() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SLAPBOOK_UI_TESTS"] = "1"
        app.launchArguments = ["-detectionEnabled", "NO", "-muted", "NO", "-volume", "0.4", "-mode", "dramaticMoans"]
        app.launch()
        app.activate()
        let button = app.buttons["testSoundButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertTrue(button.isEnabled)
        button.click()
        let result = app.staticTexts["lastReaction"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        let reaction = result.value as? String ?? result.label
        XCTAssertFalse(reaction.isEmpty)
        XCTAssertNotEqual(reaction, "Emotionally available. Technically fragile.")
    }

    @MainActor
    func testGlobalShortcutFromFinder() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SLAPBOOK_UI_TESTS"] = "1"
        app.launchArguments = ["-detectionEnabled", "YES", "-shortcutEnabled", "YES", "-experimentalMotionEnabled", "NO", "-muted", "NO", "-volume", "0.2", "-mode", "dramaticMoans"]
        app.launch()
        app.activate()
        app.buttons["nav_Detection"].click()
        XCTAssertTrue(app.staticTexts["⌥⌘S · ready globally"].waitForExistence(timeout: 5), "The actual application must register its global shortcut.")
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        finder.typeKey("s", modifierFlags: [.option, .command])
        app.activate()
        XCTAssertTrue(app.staticTexts["Global shortcut ⌥⌘S"].waitForExistence(timeout: 5), "A shortcut pressed while Finder is active must reach SlapBook.")
    }

    @MainActor
    func testCustomImportCopyAndPlayback() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SLAPBOOK_UI_TESTS"] = "1"
        app.launchArguments = ["-detectionEnabled", "NO", "-muted", "NO", "-volume", "0.2", "-mode", "dramaticMoans"]
        app.launch()
        app.activate()
        app.buttons["nav_Sound Library"].click()
        app.textFields["New pack name"].click()
        app.textFields["New pack name"].typeText(" UI Test")
        app.buttons["importSoundsButton"].click()
        app.typeKey("g", modifierFlags: [.command, .shift])
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SlapBook/Audio/Resources/sb_dramaticMoans_1_1.wav").path
        let pathField = app.dialogs.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 5))
        pathField.typeText(source)
        app.typeKey(.return, modifierFlags: [])
        let open = app.dialogs["open-panel"].buttons["OKButton"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.click()
        XCTAssertTrue(app.staticTexts["sb_dramaticMoans_1_1"].waitForExistence(timeout: 5))
        app.buttons["nav_Playground"].click()
        app.buttons["testSoundButton"].click()
        let result = app.staticTexts["lastReaction"]
        XCTAssertEqual(result.value as? String ?? result.label, "sb_dramaticMoans_1_1")
        app.buttons["nav_Sound Library"].click()
        app.buttons["remove_sb_dramaticMoans_1_1"].click()
        // Restore a built-in personality after removing the imported test copy.
        app.buttons["mode_dramaticMoans"].click()
    }
}
