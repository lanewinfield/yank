import Foundation
import Combine

class ActionStore: ObservableObject {
    @Published var actions: [YankAction] = []

    private let saveKey = "yankActions"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([YankAction].self, from: data) else {
            return
        }
        actions = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    func addAction(_ action: YankAction) {
        actions.append(action)
        save()
    }

    func removeAction(_ action: YankAction) {
        actions.removeAll { $0.id == action.id }
        save()
    }

    func removeAction(at offsets: IndexSet) {
        actions.remove(atOffsets: offsets)
        save()
    }

    func updateAction(_ action: YankAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
            save()
        }
    }

    func toggleAction(_ action: YankAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index].isEnabled.toggle()
            save()
        }
    }

    func hasActionOfType(_ type: YankActionType) -> Bool {
        actions.contains { $0.type == type }
    }

    func canAddActionOfType(_ type: YankActionType) -> Bool {
        if type.allowsMultiple { return true }
        return !hasActionOfType(type)
    }
}
