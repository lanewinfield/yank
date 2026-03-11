# ***Yank!*** Companion App

A menu bar app that connects to the ***Yank!*** BLE pull switch device and executes configurable actions when the switch is pulled.

## Building

### Prerequisites
- macOS 13.0+
- Xcode 15.0+ (with command line tools)

### Build from CLI

```bash
cd macos-app
xcodebuild -project YankCompanion.xcodeproj -scheme YankCompanion -configuration Debug build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/YankCompanion-*/Build/Products/Debug/Yank Companion.app`.

### Build Release

```bash
xcodebuild -project YankCompanion.xcodeproj -scheme YankCompanion -configuration Release build
```

## Usage

1. **Launch** - The app runs as a menu bar-only app (no dock icon). Look for the switch icon in the menu bar.
2. **Connect** - The app automatically scans for a ***Yank!*** BLE device. Make sure your device is powered on.
3. **Configure Actions** - Click the menu bar icon and use "Add Action" to configure what happens on each pull.
4. **Test** - Use the "Test" button to simulate a pull event without the physical device.

## Available Actions

| Action | SF Symbol | Multiple Allowed |
|--------|-----------|-----------------|
| Play a Sound | speaker.wave.2 | Yes |
| Play/Pause Music | playpause | No |
| Press Key Command | keyboard | No |
| Display Notification | bell | No |
| Mute/Unmute Audio | speaker.slash | No |
| Mute/Unmute Mic | mic.slash | No |
| Run Custom Script | terminal | Yes |
| End Video Calls | video.slash | No |

## Permissions

- **Bluetooth** - Required for BLE connection to the ***Yank!*** device
- **Accessibility** - Required for "Press Key Command" action (simulating keystrokes)
- **Automation** - Required for "End Video Calls" action (controlling other apps via AppleScript)

## BLE Protocol

The app connects to a device advertising as "Yank!" with:
- Service UUID: `b26f59c7-68f1-48c8-a4d1-676648080123`
- Pull Event Characteristic UUID: `b26f59c7-68f1-48c8-a4d1-676648080124`
  - Notify only, 2-byte payload: `[pull_count, elapsed_ds]`
- Battery: Standard BLE Battery Service (0x180F / 0x2A19)

## Project Structure

```
macos-app/
├── YankCompanion.xcodeproj/
│   └── project.pbxproj
├── YankCompanion/
│   ├── YankCompanionApp.swift      # App entry point
│   ├── AppDelegate.swift           # Menu bar setup, BLE + action wiring
│   ├── Info.plist                  # App config (LSUIElement, BT usage)
│   ├── YankCompanion.entitlements  # Permissions
│   ├── Models/
│   │   ├── YankAction.swift        # Action type definitions
│   │   └── ActionStore.swift       # Persistence (UserDefaults)
│   ├── BLE/
│   │   └── BLEManager.swift        # CoreBluetooth scanning/connection
│   ├── Actions/
│   │   └── ActionExecutor.swift    # Action execution logic
│   ├── Views/
│   │   ├── ContentView.swift       # Main popover view
│   │   ├── ActionRowView.swift     # Individual action row
│   │   ├── AddActionView.swift     # Action type picker + config
│   │   ├── OnboardingView.swift    # First-launch walkthrough
│   │   └── HUDNotification.swift   # macOS-style HUD overlay
│   └── Resources/
│       ├── pull-switch.mp3         # Pull switch sound
│       ├── boom.wav                # Bundled sound
│       ├── fart.wav                # Bundled sound
│       ├── toilet.wav              # Bundled sound
│       └── whistle.wav             # Bundled sound
└── README.md
```
