import MyQuickFinderKit
import SwiftUI

struct KeyBindingSettings: View {
    @State private var isRecording = false
    @State private var recording: PanelCommand?
    @State private var conflict: (chord: KeyChord, taken: PanelCommand)?

    let binding: HotKeyBinding
    let registrationFailed: Bool
    let store: KeyBindingStore
    let onRecord: (HotKeyBinding) -> Void

    private var panelMessage: String {
        guard let conflict else {
            return String(localized: "settings.keys.hint")
        }
        let chord = KeyChordFormatter.display(conflict.chord)
        let taken = PanelCommandCopy.title(conflict.taken)
        return String(localized: "settings.keys.conflict \(chord) \(taken)")
    }

    private var statusMessage: String {
        if registrationFailed {
            return String(localized: "settings.keys.taken")
        }
        if isRecording {
            return String(localized: "settings.keys.recording")
        }
        return String(localized: "settings.keys.idle")
    }

    var body: some View {
        SettingsSection {
            Section {
                HStack(alignment: .center) {
                    Text("settings.keys.openPanel")
                    Spacer(minLength: DesignTokens.Settings.rowSpacing)
                    Button {
                        isRecording.toggle()
                    } label: {
                        HotKeyRecorderField(
                            binding: binding,
                            isRecording: isRecording,
                            onRecord: { recorded in
                                isRecording = false
                                onRecord(recorded)
                            }
                        )
                        .frame(
                            width: DesignTokens.Settings.fieldWidth,
                            height: DesignTokens.Settings.fieldHeight
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                }
            } header: {
                Text("settings.keys.global")
            } footer: {
                SettingsNote(statusMessage, isWarning: registrationFailed)
            }

            Section {
                ForEach(PanelCommandCopy.customizable, id: \.self) { command in
                    HStack(alignment: .center) {
                        Text(PanelCommandCopy.title(command))
                        Spacer(minLength: DesignTokens.Settings.rowSpacing)
                        if store.overrides[command] != nil {
                            Button("settings.keys.reset") { store.reset(command) }
                                .buttonStyle(.link)
                                .controlSize(.small)
                        }
                        Button {
                            recording = recording == command ? nil : command
                            conflict = nil
                        } label: {
                            ChordRecorderField(
                                chord: store.bindings.chord(for: command),
                                isRecording: recording == command,
                                onRecord: { chord in record(chord, for: command) }
                            )
                            .frame(
                                width: DesignTokens.Settings.fieldWidth,
                                height: DesignTokens.Settings.fieldHeight
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                    }
                }
            } header: {
                Text("settings.keys.panel")
            } footer: {
                SettingsNote(panelMessage, isWarning: conflict != nil)
            }

            if store.hasCustomBindings {
                Section {
                    Button("settings.keys.resetAll") { store.resetAll() }
                }
            }
        }
    }

    private func record(_ chord: KeyChord, for command: PanelCommand) {
        recording = nil
        guard let taken = store.rebind(command, to: chord) else {
            conflict = nil
            return
        }
        conflict = (chord, taken)
    }
}
