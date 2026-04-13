import SwiftUI

/// First-launch screen where the user picks Parent or Child mode.
/// This choice is persisted in @AppStorage and determines the root view for all future launches.
/// It can be changed later from Settings.
struct RoleSelectionView: View {
    @Binding var selectedRole: String

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Mom Alarm Clock")
                    .font(.largeTitle.bold())

                Text("Who is using this device?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                roleButton(
                    title: "I'm the Parent",
                    subtitle: "Set alarms, monitor wake-ups, manage rewards",
                    icon: "person.badge.shield.checkmark.fill",
                    color: .blue
                ) {
                    selectedRole = "parent"
                }

                roleButton(
                    title: "I'm the Child",
                    subtitle: "Receive alarms, complete verification, earn rewards",
                    icon: "person.fill",
                    color: .green
                ) {
                    selectedRole = "child"
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text("You can change this later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 32)
        }
    }

    private func roleButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView(selectedRole: .constant(""))
}
