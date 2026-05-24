// GlobalHotKey.swift
// A thin wrapper over Carbon's RegisterEventHotKey for a single system-wide hotkey.
// It fires while the app runs (foreground or background) and — unlike global event
// monitors — needs no Accessibility permission. The pressed handler is delivered on
// the main actor.

import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    /// Invoked (on the main actor) when the registered hotkey is pressed.
    var onPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x50525443 // 'PRTC'

    /// Register the given key code + Carbon modifier mask, replacing any current binding.
    func register(keyCode: UInt32, carbonModifiers: UInt32) {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRef = ref }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hotkeys on the main thread; hop to the main actor.
            Task { @MainActor in instance.onPressed?() }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)
    }
}
