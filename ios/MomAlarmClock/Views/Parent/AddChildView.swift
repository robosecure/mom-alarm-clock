import SwiftUI

/// Quick flow to add a new child to the family (up to 4 max).
struct AddChildView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var age = 8
    @State private var isAdding = false

    private let maxChildren = 4

    var body: some View {
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
                        ForEach(4...18, id: \.self) { age in
                            Text("\(age) years old").tag(age)
                        }
                    }
                }

                Section {
                    Text("After adding, you'll get a join code to pair their device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func add() async {
        isAdding = true
        defer { isAdding = false }
        await vm.addChild(name: name, age: age)
        dismiss()
    }
}
