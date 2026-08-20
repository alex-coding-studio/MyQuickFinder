import AppKit
import Carbon.HIToolbox
import MyQuickFinderKit

extension HotKeyBinding {
    static let optionSpace = HotKeyBinding(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey)
    )
}

@MainActor
final class GlobalHotKey {
    private static let signature = OSType(0x4D51_4644)
    private static let identifier: UInt32 = 1

    private nonisolated(unsafe) static var action: (@MainActor @Sendable () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @discardableResult
    func register(
        keyCode: UInt32 = HotKeyBinding.optionSpace.keyCode,
        modifiers: UInt32 = HotKeyBinding.optionSpace.carbonModifiers,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        unregister()
        Self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installed = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                if let action = GlobalHotKey.action {
                    Task { @MainActor in action() }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        guard installed == noErr else {
            return false
        }

        let registered = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: Self.identifier),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return registered == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        Self.action = nil
    }
}
