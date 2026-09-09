import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let isSaving: Bool
    let onSave: (String) async -> Bool

    init(initialName: String, isSaving: Bool, onSave: @escaping (String) async -> Bool) {
        _name = State(initialValue: initialName)
        self.isSaving = isSaving
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: $name).textInputAutocapitalization(.words)
                }
                Section {
                    Text("This name is stored in Firebase Authentication and shown throughout AgriVision.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { if await onSave(name) { dismiss() } }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
