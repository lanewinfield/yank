import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AddActionView: View {
    @ObservedObject var actionStore: ActionStore
    var editingAction: YankAction? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: YankActionType?

    // Sound config
    @State private var selectedSound: String = "switch"
    @State private var customSoundPath: String = ""

    // Key command config
    @State private var keyDescription: String = ""
    @State private var capturedKeyCode: Int?
    @State private var capturedModifiers: Int = 0
    @State private var isCapturing: Bool = false

    // Script config
    @State private var scriptCommand: String = ""
    @State private var scriptPath: String = ""
    @State private var useScriptFile: Bool = false

    // Type text config
    @State private var typeTextContent: String = ""
    @FocusState private var typeTextFocused: Bool
    @State private var cmdEnterMonitor: Any?

    // End calls config
    @State private var selectedCallApps: Set<String> = []

    private static let soundOptions: [(id: String, displayName: String, resource: String, ext: String)] = [
        ("switch", "Switch", "pull-switch", "mp3"),
        ("boom", "Boom", "boom", "wav"),
        ("fart", "Fart", "fart", "wav"),
        ("toilet", "Toilet", "toilet", "wav"),
        ("whistle", "Whistle", "whistle", "wav"),
    ]

    private let callApps = ["Zoom", "Slack", "Microsoft Teams", "Discord", "Google Meet", "FaceTime"]

    private var isEditing: Bool { editingAction != nil }

    private var headerTitle: String {
        if let type = selectedType {
            return (isEditing ? "Edit " : "Add ") + type.displayName
        }
        return "Add Action"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(headerTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ZStack(alignment: .top) {
                if selectedType == nil {
                    actionTypeList
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    configView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .clipped()
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if let action = editingAction {
                selectedType = action.type
                populateConfig(from: action)
            }
        }
        .onChange(of: selectedType) { newType in
            if newType == .typeText {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    typeTextFocused = true
                }
                installCmdEnterMonitor()
            } else {
                removeCmdEnterMonitor()
            }
        }
        .onDisappear {
            removeCmdEnterMonitor()
        }
    }

    // MARK: - Action Type List

    @ViewBuilder
    private var actionTypeList: some View {
        VStack(spacing: 2) {
            ForEach(availableTypes) { type in
                actionTypeButton(type: type, canAdd: true)
            }

            if !alreadyAddedTypes.isEmpty {
                HStack {
                    Text("Already Added")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                ForEach(alreadyAddedTypes) { type in
                    actionTypeButton(type: type, canAdd: false)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var availableTypes: [YankActionType] {
        YankActionType.allCases.filter { actionStore.canAddActionOfType($0) }
    }

    private var alreadyAddedTypes: [YankActionType] {
        YankActionType.allCases.filter { !actionStore.canAddActionOfType($0) }
    }

    @ViewBuilder
    private func actionTypeButton(type: YankActionType, canAdd: Bool) -> some View {
        Button(action: {
            if canAdd {
                if type == .pressKeyCommand {
                    ActionExecutor.requestAccessibilityPermission()
                }
                if typeNeedsConfig(type) {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedType = type }
                } else {
                    let action = YankAction(type: type)
                    actionStore.addAction(action)
                    dismiss()
                }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: type.sfSymbol)
                    .font(.system(size: 14))
                    .frame(width: 24)
                    .foregroundColor(canAdd ? .accentColor : .secondary)
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if canAdd {
                    Image(systemName: typeNeedsConfig(type) ? "chevron.right" : "plus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
        .opacity(canAdd ? 1 : 0.5)
    }

    // MARK: - Config View

    @ViewBuilder
    private var configView: some View {
        if let type = selectedType {
            VStack(spacing: 0) {
                switch type {
                case .playSound:
                    soundConfig
                case .pressKeyCommand:
                    keyCommandConfig
                case .runCustomScript:
                    scriptConfig
                case .typeText:
                    typeTextConfig
                case .endVideoCalls:
                    endCallsConfig
                default:
                    EmptyView()
                }

                Divider()

                HStack {
                    if !isEditing {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.25)) { selectedType = nil }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                    }

                    Spacer()

                    Button(isEditing ? "Save" : "Add") {
                        saveCurrentConfig()
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isConfigValid(type) ? .accentColor : .secondary)
                    .disabled(!isConfigValid(type))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Selector Rows

    private func radioRow(id: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkboxRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sound Config

    private var soundConfig: some View {
        VStack(spacing: 4) {
            ForEach(Self.soundOptions, id: \.id) { option in
                radioRow(
                    id: option.id,
                    label: option.displayName,
                    isSelected: selectedSound == option.id
                ) {
                    selectedSound = option.id
                    previewSound(option.id)
                    if isEditing { saveCurrentConfig() }
                }
            }

            radioRow(
                id: "custom",
                label: customSoundPath.isEmpty ? "Custom..." : URL(fileURLWithPath: customSoundPath).lastPathComponent,
                isSelected: selectedSound == "custom"
            ) {
                if customSoundPath.isEmpty {
                    openSoundPicker()
                } else {
                    selectedSound = "custom"
                    previewSound("custom")
                }
                if isEditing { saveCurrentConfig() }
            }

            if selectedSound == "custom" && !customSoundPath.isEmpty {
                HStack {
                    Spacer()
                    Button("Change...") {
                        openSoundPicker()
                    }
                    .controlSize(.small)
                    .font(.system(size: 11))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Key Command Config

    private var keyCommandConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Click 'Capture' and press the key combination you want to trigger.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Text(keyDescription.isEmpty ? "No key set" : keyDescription)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )

                Button(isCapturing ? "Press keys..." : "Capture") {
                    isCapturing.toggle()
                    if isCapturing {
                        startKeyCapture()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Script Config

    private var scriptConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use script file", isOn: $useScriptFile)
                .font(.system(size: 12))

            if useScriptFile {
                HStack {
                    Text(scriptPath.isEmpty ? "No file selected" : URL(fileURLWithPath: scriptPath).lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundColor(scriptPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        pinPopover {
                            panel.begin { response in
                                unpinPopover()
                                if response == .OK, let url = panel.url {
                                    scriptPath = url.path
                                }
                            }
                        }
                    }
                    .controlSize(.small)
                }
            } else {
                TextField("Enter command (e.g. echo hello)", text: $scriptCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Type Text Config

    private var typeTextConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text to type on pull:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextEditor(text: $typeTextContent)
                .font(.system(size: 13))
                .focused($typeTextFocused)
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - End Calls Config

    private var endCallsConfig: some View {
        VStack(spacing: 4) {
            ForEach(callApps, id: \.self) { app in
                checkboxRow(
                    label: app,
                    isSelected: selectedCallApps.contains(app)
                ) {
                    if selectedCallApps.contains(app) {
                        selectedCallApps.remove(app)
                    } else {
                        selectedCallApps.insert(app)
                    }
                    if isEditing { saveCurrentConfig() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func typeNeedsConfig(_ type: YankActionType) -> Bool {
        switch type {
        case .playSound, .pressKeyCommand, .typeText, .runCustomScript, .endVideoCalls:
            return true
        default:
            return false
        }
    }

    private func isConfigValid(_ type: YankActionType) -> Bool {
        switch type {
        case .playSound:
            return selectedSound != "custom" || !customSoundPath.isEmpty
        case .pressKeyCommand:
            return capturedKeyCode != nil
        case .typeText:
            return !typeTextContent.isEmpty
        case .runCustomScript:
            return useScriptFile ? !scriptPath.isEmpty : !scriptCommand.isEmpty
        case .endVideoCalls:
            return !selectedCallApps.isEmpty
        default:
            return true
        }
    }

    private func saveCurrentConfig() {
        guard let type = selectedType else { return }
        var config = ActionConfig()

        switch type {
        case .playSound:
            config.soundName = selectedSound
            if selectedSound == "custom" {
                config.soundFilePath = customSoundPath
            }
        case .pressKeyCommand:
            config.keyCode = capturedKeyCode
            config.keyModifiers = capturedModifiers
            config.keyDescription = keyDescription
        case .runCustomScript:
            if useScriptFile {
                config.scriptPath = scriptPath
            } else {
                config.scriptCommand = scriptCommand
            }
        case .typeText:
            config.typeTextContent = typeTextContent
        case .endVideoCalls:
            config.selectedCallApps = Array(selectedCallApps)
        default:
            break
        }

        if isEditing, let editAction = editingAction {
            var updated = editAction
            updated.config = config
            actionStore.updateAction(updated)
        } else {
            let action = YankAction(type: type, config: config)
            actionStore.addAction(action)
        }
    }

    private func populateConfig(from action: YankAction) {
        switch action.type {
        case .playSound:
            if let sounds = action.config.selectedSounds, let first = sounds.first {
                selectedSound = first == "custom" ? "custom" : first
                if first == "custom" {
                    customSoundPath = action.config.soundFilePath ?? ""
                }
            } else if let name = action.config.soundName {
                selectedSound = name
                if name == "custom" {
                    customSoundPath = action.config.soundFilePath ?? ""
                }
            }
        case .pressKeyCommand:
            keyDescription = action.config.keyDescription ?? ""
            capturedKeyCode = action.config.keyCode
            capturedModifiers = action.config.keyModifiers ?? 0
        case .runCustomScript:
            if let path = action.config.scriptPath {
                useScriptFile = true
                scriptPath = path
            } else {
                scriptCommand = action.config.scriptCommand ?? ""
            }
        case .typeText:
            typeTextContent = action.config.typeTextContent ?? ""
        case .endVideoCalls:
            if let apps = action.config.selectedCallApps {
                selectedCallApps = Set(apps)
            }
        default:
            break
        }
    }

    private func openSoundPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        pinPopover {
            panel.begin { [self] response in
                unpinPopover()
                if response == .OK, let url = panel.url {
                    customSoundPath = url.path
                    selectedSound = "custom"
                    previewSound("custom")
                    if isEditing { saveCurrentConfig() }
                } else if selectedSound == "custom" && customSoundPath.isEmpty {
                    selectedSound = "switch"
                }
            }
        }
    }

    private func previewSound(_ soundId: String) {
        if soundId == "custom" {
            if !customSoundPath.isEmpty {
                NSSound(contentsOfFile: customSoundPath, byReference: true)?.play()
            }
        } else if let option = Self.soundOptions.first(where: { $0.id == soundId }),
                  let path = Bundle.main.path(forResource: option.resource, ofType: option.ext) {
            NSSound(contentsOfFile: path, byReference: true)?.play()
        }
    }

    private func installCmdEnterMonitor() {
        removeCmdEnterMonitor()
        cmdEnterMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 36 && event.modifierFlags.contains(.command) {
                if self.selectedType == .typeText && !self.typeTextContent.isEmpty {
                    self.saveCurrentConfig()
                    self.dismiss()
                    return nil
                }
            }
            return event
        }
    }

    private func removeCmdEnterMonitor() {
        if let monitor = cmdEnterMonitor {
            NSEvent.removeMonitor(monitor)
            cmdEnterMonitor = nil
        }
    }

    private func startKeyCapture() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            self.capturedKeyCode = Int(event.keyCode)

            var mods = 0
            if event.modifierFlags.contains(.command) { mods |= 1 }
            if event.modifierFlags.contains(.shift) { mods |= 2 }
            if event.modifierFlags.contains(.option) { mods |= 4 }
            if event.modifierFlags.contains(.control) { mods |= 8 }
            self.capturedModifiers = mods

            var desc = ""
            if event.modifierFlags.contains(.control) { desc += "Ctrl+" }
            if event.modifierFlags.contains(.option) { desc += "Opt+" }
            if event.modifierFlags.contains(.shift) { desc += "Shift+" }
            if event.modifierFlags.contains(.command) { desc += "Cmd+" }

            if let chars = event.charactersIgnoringModifiers?.uppercased() {
                desc += chars
            } else {
                desc += "Key(\(event.keyCode))"
            }
            self.keyDescription = desc
            self.isCapturing = false

            return nil
        }
    }

    private func pinPopover(_ action: @escaping () -> Void) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.popover.behavior = .applicationDefined
        }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            action()
        }
    }

    private func unpinPopover() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.popover.behavior = .transient
        }
    }
}
