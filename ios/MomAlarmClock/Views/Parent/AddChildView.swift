import SwiftUI

/// Quick flow to add a new child to the family (up to 4 max).
/// After adding, shows pairing instructions with join code instead of dismissing.
struct AddChildView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var age = 8
    @State private var isAdding = false
    @State private var addedChild: ChildProfile?

    private let maxChildren = 4

    var body: some View {
        if let child = addedChild {
            pairingInstructionsView(child: child)
        } else {
            addChildForm
        }
    }

    // MARK: - Add Child Form

    private var addChildForm: some View {
        Form {
            if vm.children.count >= maxChildren {
                Section {
                    Label("Maximum \(maxChildren) children per family", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } else {
                Section("Child's Info") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    Picker("Age", selection: $age) {
                        ForEach(4...18, id: \.self) { a in
                            Text("\(a) years old").tag(a)
                        }
                    }
                }

                Section {
                    Label {
                        Text("By adding a child, you confirm you are their parent or legal guardian and consent to the collection of their name, age, and verification data as described in our Privacy Policy.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.blue)
                    }
                }

                Section {
                    Button {
                        Task { await add() }
                    } label: {
                        if isAdding {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Add Child")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(name.isEmpty || isAdding)
                }
            }
        }
        .navigationTitle("Add Child")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Pairing Instructions (shown after adding)

    private func pairingInstructionsView(child: ChildProfile) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Success header
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("\(child.name) Added!")
                        .font(.title3.bold())

                    // Join code card
                    if let code = child.pairingCode ?? auth.lastJoinCode {
                        VStack(spacing: 10) {
                            Text("Family Join Code")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(code)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .tracking(4)

                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.string = code
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                ShareLink(item: "Join our family alarm on Mom Alarm Clock! Code: \(code)") {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        Label("Join code not available. Check Settings > Join Code.", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    // Compact instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("On the child's phone:")
                            .font(.subheadline.bold())

                        instructionStep(number: 1, text: "Install Mom Alarm Clock")
                        instructionStep(number: 2, text: "Tap \"I'm the Child\"")
                        instructionStep(number: 3, text: "Enter the code above")
                        instructionStep(number: 4, text: "Allow notifications")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    Text("Code expires in 24 hours. Find it later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }

            // Fixed bottom button — always visible
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Pair Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue, in: Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func add() async {
        isAdding = true
        defer { isAdding = false }
        await vm.addChild(name: name, age: age)
        // Find the child we just added (last one with matching name)
        if let child = vm.children.last(where: { $0.name == name }) {
            withAnimation { addedChild = child }
        } else {
            dismiss()
        }
    }
}
