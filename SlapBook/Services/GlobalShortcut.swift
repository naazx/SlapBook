import Carbon
import Foundation

/// RegisterEventHotKey receives only the chosen shortcut, not arbitrary keystrokes.
/// It needs neither Accessibility nor Input Monitoring permission.
@MainActor
final class GlobalShortcut {
    var onTrigger: (() -> Void)?
    private(set) var status = "Shortcut is off"
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isPressed = false

    isolated deinit { stop() }

    func start() {
        stop()
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x534c4150, identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            // Carbon application event handlers run on the application's main thread.
            MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    owner.isPressed = false
                } else if !owner.isPressed {
                    owner.isPressed = true
                    owner.onTrigger?()
                }
            }
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else {
            status = "Shortcut handler failed (\(installed)). Use the on-screen buttons."
            return
        }
        let identifier = EventHotKeyID(signature: 0x534c4150, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(optionKey | cmdKey), identifier,
                                         GetApplicationEventTarget(), 0, &hotKey)
        if result == noErr {
            status = "⌥⌘S · ready globally"
        } else {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            if result == eventHotKeyExistsErr {
                status = "⌥⌘S is already in use. Use the on-screen buttons."
            } else {
                status = "macOS could not register ⌥⌘S (\(result)). Use the on-screen buttons."
            }
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        isPressed = false
        status = "Shortcut is off"
    }
}
