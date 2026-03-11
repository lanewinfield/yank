import SwiftUI

struct ActionRowView: View {
    let action: YankAction
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onEdit: (() -> Void)? = nil

    private var canEdit: Bool { action.type.hasEditableConfig }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.type.sfSymbol)
                .font(.system(size: 14))
                .foregroundColor(action.isEnabled ? .accentColor : .secondary)
                .frame(width: 20)

            // Name area — tap to edit (editable) or toggle (non-editable)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(action.isEnabled ? .primary : .secondary)

                if let detail = actionDetail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if canEdit { onEdit?() }
                else { onToggle() }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { action.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 44)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.15))
        )
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    private var actionDetail: String? {
        switch action.type {
        case .playSound:
            if let name = action.config.soundName {
                return name == "custom"
                    ? action.config.soundFilePath?.components(separatedBy: "/").last
                    : name.capitalized
            }
            return nil
        case .pressKeyCommand:
            return action.config.keyDescription
        case .displayNotification:
            return nil
        case .runCustomScript:
            if let path = action.config.scriptPath {
                return path.components(separatedBy: "/").last
            }
            return action.config.scriptCommand
        case .typeText:
            if let text = action.config.typeTextContent, !text.isEmpty {
                let preview = text.count > 30 ? String(text.prefix(30)) + "..." : text
                return "\"\(preview)\""
            }
            return nil
        case .endVideoCalls:
            if let apps = action.config.selectedCallApps {
                return apps.joined(separator: ", ")
            }
            return nil
        default:
            return nil
        }
    }
}
