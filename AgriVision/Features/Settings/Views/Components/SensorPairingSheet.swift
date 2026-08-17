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
                        Task { if await onPair(code, name) { dismiss() } }
                    }
                    .disabled(isPairing)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
