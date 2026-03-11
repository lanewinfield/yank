import SwiftUI
import ServiceManagement

struct ContentView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var actionStore: ActionStore
    @ObservedObject var actionExecutor: ActionExecutor
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var showingAddAction = false
    @State private var editingAction: YankAction?
    @State private var loginItemEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            connectionHeader
            Divider()

            if actionStore.actions.isEmpty {
                emptyState
            } else {
                Text("On Yank...")
                    .font(.system(size: 11).italic())
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                actionsList
            }

            Divider()
            footer
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var connectionHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(bleManager.connectionState.rawValue)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            if let battery = bleManager.batteryLevel {
                HStack(spacing: 3) {
                    Image(systemName: batteryIcon(level: battery, powerState: bleManager.powerState))
                        .font(.system(size: 11))
                    Text(batteryText(level: battery, powerState: bleManager.powerState))
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        Button(action: { showingAddAction = true }) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No actions configured")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Add an action to get started")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .contentShape(Rectangle())
            .padding()
        }
        .buttonStyle(.plain)
    }

    private var actionsList: some View {
        VStack(spacing: 6) {
            ForEach(actionStore.actions) { action in
                ActionRowView(
                    action: action,
                    onToggle: { actionStore.toggleAction(action) },
                    onDelete: { actionStore.removeAction(action) },
                    onEdit: action.type.hasEditableConfig ? { editingAction = action } : nil
                )
                .popover(isPresented: Binding(
                    get: { editingAction?.id == action.id },
                    set: { if !$0 { editingAction = nil } }
                )) {
                    AddActionView(actionStore: actionStore, editingAction: action)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
        .padding(.horizontal, 8)
    }

    private var footer: some View {
        HStack {
            Button(action: { showingAddAction = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text("Add Action")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .popover(isPresented: $showingAddAction) {
                AddActionView(actionStore: actionStore)
            }

            Spacer()

            settingsMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        switch bleManager.connectionState {
        case .connected: return .green
        case .scanning, .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private func batteryIcon(level: Int, powerState: BLEManager.PowerState) -> String {
        if powerState == .charging {
            return "battery.100percent.bolt"
        } else if powerState == .charged {
            return "battery.100percent.bolt"
        }
        switch level {
        case 0..<20: return "battery.0percent"
        case 20..<50: return "battery.25percent"
        case 50..<75: return "battery.50percent"
        case 75..<100: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func batteryText(level: Int, powerState: BLEManager.PowerState) -> String {
        switch powerState {
        case .charging: return "Charging"
        case .charged: return "Charged"
        case .battery: return "\(level)%"
        }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle("Open at Login", isOn: Binding(
                get: { loginItemEnabled },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {}
                    loginItemEnabled = SMAppService.mainApp.status == .enabled
                }
            ))

            #if DEBUG
            Button("Test Pull") {
                bleManager.simulatePull()
            }
            #endif

            Divider()

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")

            Button("Visit Yank! Online") {
                if let url = URL(string: "https://yank.computer") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("Quit Yank!") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
