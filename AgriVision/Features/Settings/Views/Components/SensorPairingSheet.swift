import SwiftUI

struct SensorPairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var code = ""
    let fieldName: String
    let isPairing: Bool
    let onPair: (String, String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Assign to \(fieldName)") {
                    TextField("Sensor name", text: $name)
                    TextField("ESP32 pairing code", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                if name.count > 50 || code.count > 36 {
                    Section {
                        Text(name.count > 50 ? "Sensor name cannot exceed 50 characters." : "Pairing code cannot exceed 36 characters.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Section {
                    Text("The sensor must be powered on and reporting to MQTT before it can be paired.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Pair Sensor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pair") {
                        Task { if await onPair(code.trimmingCharacters(in: .whitespacesAndNewlines), name.trimmingCharacters(in: .whitespacesAndNewlines)) { dismiss() } }
                    }
                    .disabled(isPairing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 50 || code.count > 36)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
