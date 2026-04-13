import SwiftUI

/// Edit a child's profile (name, age). Guardian-only.
struct ChildProfileEditorView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    let child: ChildProfile

    @State private var name: String = ""
    @State private var age: Int = 8
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                Picker("Age", selection: $age) {
                    ForEach(4...18, id: \.self) { a in
                        Text("\(a) years old").tag(a)
                    }
                }
            }

            Section("Stats") {
                LabeledContent("Streak", value: "\(child.stats.currentStreak) days")
                LabeledContent("Best Streak", value: "\(child.stats.bestStreak) days")
                LabeledContent("Points", value: "\(child.stats.rewardPoints)")
                LabeledContent("On-time", value: "\(child.stats.onTimeCount)")
            }

            if let voice = child.voiceAlarm, voice.enabled {
                Section("Voice Alarm") {
                    Label("Active", systemImage: "mic.fill")
                        .foregroundStyle(.pink)
                    Text("Updated: \(voice.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(name.isEmpty || isSaving)
            }

            Section {
                Button("Remove Child", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit \(child.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            name = child.name
            age = child.age
        }
        .confirmationDialog("Remove \(child.name)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task { await vm.removeChild(child.id) }
                dismiss()
            }
        } message: {
            Text("This will remove the child's profile, alarms, and history. This cannot be undone.")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        await vm.updateChildProfile(childID: child.id, name: name, age: age)
        dismiss()
    }
}
