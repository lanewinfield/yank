import Foundation
import AVFoundation
import CoreAudio
import AppKit

class ActionExecutor: ObservableObject {
    private var audioPlayers: [AVAudioPlayer] = []

    private static let bundledSoundMap: [String: (resource: String, ext: String)] = [
        "switch": ("pull-switch", "mp3"),
        "boom": ("boom", "wav"),
        "fart": ("fart", "wav"),
        "toilet": ("toilet", "wav"),
        "whistle": ("whistle", "wav"),
        "pull-switch": ("pull-switch", "mp3"),
    ]

    func executeAll(actions: [YankAction]) {
        let enabledActions = actions.filter { $0.isEnabled }
        var hasNotification = false

        for action in enabledActions {
            if action.type == .displayNotification {
                hasNotification = true
            } else {
                execute(action)
            }
        }

        if hasNotification {
            let summaryLines = enabledActions
                .filter { $0.type != .displayNotification }
                .map { actionSummary($0) }
            let message = summaryLines.isEmpty ? "Yank!" : summaryLines.joined(separator: "\n")
            DispatchQueue.main.async {
                HUDNotification.shared.show(message: message)
            }
        }
    }

    private func actionSummary(_ action: YankAction) -> String {
        switch action.type {
        case .playPauseMusic: return "Play/Pause"
        case .muteUnmuteAudio: return "Mute/Unmute Audio"
        case .muteUnmuteMic: return "Mute/Unmute Mic"
        case .playSound: return "Played sound"
        case .endVideoCalls: return "End Video Calls"
        case .pressKeyCommand: return action.config.keyDescription ?? "Key Command"
        case .typeText: return "Typed text"
        case .runCustomScript: return "Ran script"
        case .displayNotification: return ""
        }
    }

    func execute(_ action: YankAction) {
        switch action.type {
        case .playSound:
            playSound(config: action.config)
        case .playPauseMusic:
            togglePlayPause()
        case .pressKeyCommand:
            pressKeyCommand(config: action.config)
        case .displayNotification:
            break
        case .muteUnmuteAudio:
            toggleSystemMute()
        case .muteUnmuteMic:
            toggleMicMute()
        case .typeText:
            typeText(config: action.config)
        case .runCustomScript:
            runScript(config: action.config)
        case .endVideoCalls:
            endVideoCalls(config: action.config)
        }
    }

    // MARK: - Play Sound

    private func playSound(config: ActionConfig) {
        if let soundName = config.soundName {
            if soundName == "custom", let path = config.soundFilePath {
                playSoundFile(path: path)
            } else if let info = Self.bundledSoundMap[soundName],
                      let path = Bundle.main.path(forResource: info.resource, ofType: info.ext) {
                playSoundFile(path: path)
            }
        } else if let path = config.soundFilePath {
            playSoundFile(path: path)
        }
    }

    private func playSoundFile(path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayers.append(player)
            player.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.5) { [weak self] in
                self?.audioPlayers.removeAll { $0 === player }
            }
        } catch {
            print("Error playing sound: \(error)")
        }
    }

    // MARK: - Play/Pause Music

    private func togglePlayPause() {
        let keyCode: UInt32 = 16 // NX_KEYTYPE_PLAY
        func postMediaKey(down: Bool) {
            let flags: UInt32 = down ? 0xa00 : 0xb00
            let data = Int((Int(keyCode) << 16) | Int(flags))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        postMediaKey(down: true)
        postMediaKey(down: false)
    }

    // MARK: - Press Key Command

    private func pressKeyCommand(config: ActionConfig) {
        guard let keyCode = config.keyCode else { return }
        let modifiers = config.keyModifiers ?? 0

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false) else {
            return
        }

        var cgFlags: CGEventFlags = []
        if modifiers & 1 != 0 { cgFlags.insert(.maskCommand) }
        if modifiers & 2 != 0 { cgFlags.insert(.maskShift) }
        if modifiers & 4 != 0 { cgFlags.insert(.maskAlternate) }
        if modifiers & 8 != 0 { cgFlags.insert(.maskControl) }

        keyDown.flags = cgFlags
        keyUp.flags = cgFlags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Mute/Unmute Audio

    private func toggleSystemMute() {
        var defaultOutputID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputID)

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(defaultOutputID, &muteAddress, 0, nil, &muteSize, &muted)

        var newMute: UInt32 = muted == 0 ? 1 : 0
        AudioObjectSetPropertyData(defaultOutputID, &muteAddress, 0, nil, muteSize, &newMute)
    }

    // MARK: - Mute/Unmute Mic

    private func toggleMicMute() {
        var defaultInputID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultInputID)

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(defaultInputID, &muteAddress, 0, nil, &muteSize, &muted)

        var newMute: UInt32 = muted == 0 ? 1 : 0
        AudioObjectSetPropertyData(defaultInputID, &muteAddress, 0, nil, muteSize, &newMute)
    }

    // MARK: - Type Text

    private func typeText(config: ActionConfig) {
        guard let text = config.typeTextContent, !text.isEmpty else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        for char in text {
            let str = String(char)
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                let utf16 = Array(str.utf16)
                event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                event.post(tap: .cghidEventTap)
            }
            if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                eventUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Run Custom Script

    private func runScript(config: ActionConfig) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            if let scriptPath = config.scriptPath {
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [scriptPath]
            } else if let command = config.scriptCommand {
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
            } else {
                return
            }

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Error running script: \(error)")
            }
        }
    }

    // MARK: - End Video Calls

    private func endVideoCalls(config: ActionConfig) {
        let allScripts: [(app: String, script: String)] = [
            ("Zoom", """
                tell application "System Events"
                    if exists (process "zoom.us") then
                        tell process "zoom.us"
                            if exists (menu item "Leave Meeting" of menu "Meeting" of menu bar 1) then
                                click menu item "Leave Meeting" of menu "Meeting" of menu bar 1
                                delay 0.5
                                if exists (button "Leave Meeting" of window 1) then
                                    click button "Leave Meeting" of window 1
                                end if
                            end if
                        end tell
                    end if
                end tell
            """),
            ("Slack", """
                tell application "System Events"
                    if exists (process "Slack") then
                        tell application "Slack"
                            activate
                        end tell
                        delay 0.3
                        key code 4 using {command down, shift down}
                    end if
                end tell
            """),
            ("Microsoft Teams", """
                tell application "System Events"
                    if exists (process "Microsoft Teams") then
                        tell application "Microsoft Teams"
                            activate
                        end tell
                        delay 0.3
                        key code 11 using {command down, shift down}
                    end if
                end tell
            """),
            ("Discord", """
                tell application "System Events"
                    if exists (process "Discord") then
                        tell application "Discord"
                            activate
                        end tell
                        delay 0.3
                        key code 2 using {command down, shift down}
                    end if
                end tell
            """),
            ("Google Meet", """
                tell application "System Events"
                    if exists (process "Google Chrome") then
                        tell application "Google Chrome"
                            set meetTabs to {}
                            repeat with w in windows
                                repeat with t in tabs of w
                                    if URL of t contains "meet.google.com" then
                                        set active tab index of w to (index of t)
                                        set index of w to 1
                                        activate
                                        delay 0.3
                                        tell application "System Events"
                                            key code 2 using {command down}
                                        end tell
                                    end if
                                end repeat
                            end repeat
                        end tell
                    end if
                end tell
            """),
            ("FaceTime", """
                tell application "System Events"
                    if exists (process "FaceTime") then
                        tell process "FaceTime"
                            set frontmost to true
                            keystroke "w" using {command down}
                        end tell
                    end if
                end tell
            """)
        ]

        let selectedApps = config.selectedCallApps ?? allScripts.map { $0.app }
        let filteredScripts = allScripts.filter { selectedApps.contains($0.app) }

        DispatchQueue.global(qos: .userInitiated).async {
            for (_, script) in filteredScripts {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                }
            }
        }
    }

    // MARK: - Permissions

    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
