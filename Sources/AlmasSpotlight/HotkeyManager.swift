import Carbon

/// Registers a system-wide hotkey via Carbon's EventHotKey API.
/// Does NOT require Accessibility permissions.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var callbackBox: Unmanaged<CallbackBox>?

    /// - Parameters:
    ///   - keyCode: Virtual key code (49 = Space).
    ///   - modifiers: Carbon modifier mask (2048 = optionKey, 256 = cmdKey).
    ///   - callback: Invoked on the main thread when the hotkey fires.
    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        register(keyCode: keyCode, modifiers: modifiers, callback: callback)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Box the callback so we can pass it through a C pointer.
        let box = CallbackBox(callback)
        let retainedBox = Unmanaged.passRetained(box)
        let ptr = retainedBox.toOpaque()
        callbackBox = retainedBox

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return noErr }
                let box = Unmanaged<CallbackBox>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { box.callback() }
                return noErr
            },
            1, &eventSpec, ptr, &eventHandlerRef
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x414C_4D53) // "ALMS"
        hotKeyID.id        = 1

        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let ref = hotKeyRef      { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
        callbackBox?.release()
    }
}

// MARK: - Helpers

private final class CallbackBox {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
}
