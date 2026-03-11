import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private var pulledIconTimer: Timer?
    private var eventMonitor: Any?

    let bleManager = BLEManager()
    let actionStore = ActionStore()
    let actionExecutor = ActionExecutor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        copyBundledSounds()

        bleManager.onPullEvent = { [weak self] in
            guard let self = self else { return }
            self.actionExecutor.executeAll(actions: self.actionStore.actions)
            self.showPulledIcon()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = menuBarImage(named: "MenuBarDefault")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = ContentView(
            bleManager: bleManager,
            actionStore: actionStore,
            actionExecutor: actionExecutor
        )
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        bleManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarIcon() }
            .store(in: &cancellables)

        bleManager.$batteryLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarIcon() }
            .store(in: &cancellables)

        bleManager.$powerState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarIcon() }
            .store(in: &cancellables)
    }

    private func menuBarImage(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func updateMenuBarIcon() {
        if pulledIconTimer != nil { return }

        guard let button = statusItem.button else { return }

        if bleManager.connectionState != .connected {
            button.image = menuBarImage(named: "MenuBarDisconnected")
            button.alphaValue = 0.3
        } else if bleManager.powerState == .charging || bleManager.powerState == .charged {
            button.image = menuBarImage(named: "MenuBarCharging")
            button.alphaValue = 1.0
        } else if bleManager.powerState == .battery, let battery = bleManager.batteryLevel, battery < 10 {
            button.image = menuBarImage(named: "MenuBarLowBattery")
            button.alphaValue = 1.0
        } else {
            button.image = menuBarImage(named: "MenuBarDefault")
            button.alphaValue = 1.0
        }
    }

    private func showPulledIcon() {
        guard let button = statusItem.button else { return }

        pulledIconTimer?.invalidate()

        button.image = menuBarImage(named: "MenuBarPulled")
        button.alphaValue = 1.0

        pulledIconTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.pulledIconTimer = nil
            self?.updateMenuBarIcon()
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func copyBundledSounds() {
        let fileManager = FileManager.default
        guard let resourcePath = Bundle.main.resourcePath else { return }

        let sounds = ["pull-switch.mp3"]
        for sound in sounds {
            let source = (resourcePath as NSString).appendingPathComponent(sound)
            if !fileManager.fileExists(atPath: source) {
                // Sound should be bundled in the app's Resources — nothing to copy at runtime.
            }
        }
    }
}
