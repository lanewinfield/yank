import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentStep = 0

    private let steps: [(icon: String, title: String, description: String)] = [
        ("light.switch.1", "Welcome to Yank!",
         "Yank! Companion connects to your Yank! BLE pull switch and triggers actions when you pull it."),
        ("antenna.radiowaves.left.and.right", "Connect Your Device",
         "Make sure your Yank! device is powered on. The app will automatically scan for and connect to it via Bluetooth."),
        ("gearshape.2", "Configure Actions",
         "Add actions like playing sounds, muting your mic, sending key commands, and more. Each pull triggers all your enabled actions."),
        ("lock.shield", "Permissions",
         "Some actions need special permissions:\n\n- Key Commands need Accessibility access\n- Ending Video Calls needs Automation access\n\nYou'll be prompted when you add these actions.")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .frame(height: 50)

            Text(steps[currentStep].title)
                .font(.system(size: 16, weight: .bold))

            Text(steps[currentStep].description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Spacer()

            // Step indicators
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(24)
        .frame(width: 320, height: 320)
    }
}
