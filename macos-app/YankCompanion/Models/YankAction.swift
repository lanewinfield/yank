import Foundation

enum YankActionType: String, Codable, CaseIterable, Identifiable {
    case playPauseMusic = "playPauseMusic"
    case muteUnmuteAudio = "muteUnmuteAudio"
    case muteUnmuteMic = "muteUnmuteMic"
    case playSound = "playSound"
    case displayNotification = "displayNotification"
    case endVideoCalls = "endVideoCalls"
    case pressKeyCommand = "pressKeyCommand"
    case typeText = "typeText"
    case runCustomScript = "runCustomScript"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playSound: return "Play a Sound"
        case .playPauseMusic: return "Play/Pause Music"
        case .pressKeyCommand: return "Press Key Command"
        case .displayNotification: return "Display Notification"
        case .muteUnmuteAudio: return "Mute/Unmute Audio"
        case .muteUnmuteMic: return "Mute/Unmute Mic"
        case .typeText: return "Type Text"
        case .runCustomScript: return "Run Custom Script"
        case .endVideoCalls: return "End Video Calls"
        }
    }

    var sfSymbol: String {
        switch self {
        case .playSound: return "speaker.wave.2"
        case .playPauseMusic: return "playpause"
        case .pressKeyCommand: return "keyboard"
        case .displayNotification: return "bell"
        case .muteUnmuteAudio: return "speaker.slash"
        case .muteUnmuteMic: return "mic.slash"
        case .typeText: return "text.cursor"
        case .runCustomScript: return "terminal"
        case .endVideoCalls: return "video.slash"
        }
    }

    var allowsMultiple: Bool {
        switch self {
        case .playSound, .runCustomScript: return true
        default: return false
        }
    }

    var hasEditableConfig: Bool {
        switch self {
        case .playSound, .pressKeyCommand, .typeText, .runCustomScript, .endVideoCalls:
            return true
        default:
            return false
        }
    }
}

struct YankAction: Codable, Identifiable, Equatable {
    let id: UUID
    let type: YankActionType
    var isEnabled: Bool
    var config: ActionConfig

    init(type: YankActionType, config: ActionConfig = ActionConfig()) {
        self.id = UUID()
        self.type = type
        self.isEnabled = true
        self.config = config
    }

    static func == (lhs: YankAction, rhs: YankAction) -> Bool {
        lhs.id == rhs.id
    }
}

struct ActionConfig: Codable {
    var soundFilePath: String?
    var soundName: String?
    var selectedSounds: [String]?
    var keyCode: Int?
    var keyModifiers: Int?
    var keyDescription: String?
    var notificationMessage: String?
    var scriptPath: String?
    var scriptCommand: String?
    var selectedCallApps: [String]?
    var typeTextContent: String?

    init(
        soundFilePath: String? = nil,
        soundName: String? = nil,
        selectedSounds: [String]? = nil,
        keyCode: Int? = nil,
        keyModifiers: Int? = nil,
        keyDescription: String? = nil,
        notificationMessage: String? = nil,
        scriptPath: String? = nil,
        scriptCommand: String? = nil,
        selectedCallApps: [String]? = nil,
        typeTextContent: String? = nil
    ) {
        self.soundFilePath = soundFilePath
        self.soundName = soundName
        self.selectedSounds = selectedSounds
        self.keyCode = keyCode
        self.keyModifiers = keyModifiers
        self.keyDescription = keyDescription
        self.notificationMessage = notificationMessage
        self.scriptPath = scriptPath
        self.scriptCommand = scriptCommand
        self.selectedCallApps = selectedCallApps
        self.typeTextContent = typeTextContent
    }
}
