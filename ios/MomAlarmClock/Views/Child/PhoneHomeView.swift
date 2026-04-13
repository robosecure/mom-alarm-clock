import SwiftUI

/// Allows the child to send a quick message to their parent during an active alarm session.
/// Messages are synced via CloudKit and appear on the parent's dashboard.
struct PhoneHomeView: View {
    @Environment(ChildViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var messageText = ""
    @State private var isSending = false
    @State private var sent = false

    /// Quick message templates for easy one-tap sending.
    private let quickMessages = [
        "I'm getting up now!",
        "I don't feel well today.",
        "Can I have 5 more minutes?",
        "I'm awake, just getting dressed.",
        "I need help with something.",
    ]

    var body: some View {
        VStack(spacing: 24) {
            if sent {
                sentConfirmation
            } else {
                messageComposer
            }
        }
        .padding()
        .navigationTitle("Message Guardian")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messageComposer: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Send a message to your guardian")
                .font(.headline)
                            .accessibilityAddTraits(.isHeader)

            // Quick message buttons
            VStack(spacing: 8) {
                ForEach(quickMessages, id: \.self) { message in
                    Button {
                        messageText = message
                        sendMessage()
                    } label: {
                        Text(message)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Custom message
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.isEmpty || isSending)
            }
        }
    }

    private var sentConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Message Sent!")
                .font(.title2.bold())
            Text("Your guardian will see this message.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        isSending = true

        Task {
            await vm.sendMessageToParent(messageText)
            sent = true
            isSending = false
        }
    }
}
