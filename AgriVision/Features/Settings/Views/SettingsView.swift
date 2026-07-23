import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showEditProfile = false
    @State private var showSensorSetup = false

    init(viewModel: SettingsViewModel, onBack: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), AppColors.limeGreen.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                settingsHeader
                List {
                    profileSection
                    fieldSection
                    preferencesSection
                    integrationsSection
                    accountActionsSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 16, for: .scrollContent)
                .refreshable { await viewModel.refreshAll() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            toastOverlay.padding(.top, 72).padding(.horizontal)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(initialName: viewModel.accountName, isSaving: viewModel.isLoading) { name in
                await viewModel.updateDisplayName(name)
            }
        }
        .sheet(isPresented: $showSensorSetup) {
            SensorPairingSheet(
                fieldName: viewModel.currentFieldName,
                isPairing: viewModel.isPairingSensor
            ) { code, name in
                await viewModel.pairAndAssignSensor(deviceID: code, name: name)
            }
        }
        .confirmationDialog("Permanently delete \(viewModel.currentFieldName)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Field Permanently", role: .destructive) {
                if let id = viewModel.activeFieldId { viewModel.deleteField(id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. The field, assigned sensors and readings, satellite imagery, recommendations, chats, and attached photos will be removed.")
        }
    }

    private var settingsHeader: some View {
        HStack {
            Button(action: navigateBack) {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to dashboard")

            Spacer()
            Text(viewModel.title).font(.title2.weight(.bold))
            Spacer()

            Button { Task { await viewModel.refreshAll() } } label: {
                if viewModel.isRefreshing {
                    ProgressView().tint(.white).frame(width: 44, height: 44)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .accessibilityLabel("Refresh settings")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 64)
        .background(AppColors.mediumGreen)
        .background(AppColors.mediumGreen.ignoresSafeArea(edges: .top))
    }

    private var profileSection: some View {
        Section("Account") {
            Button { showEditProfile = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppColors.mediumGreen.opacity(0.14))
                        Text(String(viewModel.accountName.prefix(1)).uppercased())
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.mediumGreen)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.accountName).font(.headline).foregroundStyle(.primary)
                        Text(viewModel.accountEmail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "pencil").foregroundStyle(AppColors.mediumGreen)
                }
            }
            .buttonStyle(.plain)

            SettingsInfoRow(
                icon: "checkmark.shield",
                label: "Authentication",
                value: viewModel.isGoogleLinked ? "Google linked" : "Firebase account"
            )
        }
    }

    private var fieldSection: some View {
        Section("Active Field") {
            Menu {
                ForEach(viewModel.fields) { field in
                    Button {
                        viewModel.selectField(field.id)
                    } label: {
                        if field.id == viewModel.activeFieldId {
                            Label(field.name, systemImage: "checkmark")
                        } else {
                            Text(field.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Label("Current Field", systemImage: "leaf")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(viewModel.currentFieldName).foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(viewModel.fields.isEmpty)

            if let field = viewModel.activeField {
                SettingsInfoRow(icon: "square.dashed", label: "Area", value: field.areaHa.map { String(format: "%.2f ha", $0) } ?? "Calculating")
                SettingsInfoRow(icon: "camera.macro", label: "Crop", value: field.cropType ?? "Not specified")
            }
        }
    }

    private var preferencesSection: some View {
        Section("Dashboard") {
            Picker("Auto-refresh", selection: Binding(
                get: { viewModel.refreshInterval },
                set: viewModel.setRefreshInterval
            )) {
                Text("15 seconds").tag(TimeInterval(15))
                Text("30 seconds").tag(TimeInterval(30))
                Text("60 seconds").tag(TimeInterval(60))
            }
            .pickerStyle(.menu)

            SettingsInfoRow(icon: "arrow.triangle.2.circlepath", label: "Data source", value: "Backend snapshots")
        }
    }

    private var integrationsSection: some View {
        Section("Integrations") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Satellite", systemImage: "globe.americas.fill")
                    Spacer()
                    StatusPill(status: viewModel.satelliteStatus)
                }
                Text(viewModel.satelliteSummary).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("IoT Sensors", systemImage: "sensor.tag.radiowaves.forward.fill")
                    Spacer()
                    StatusPill(status: viewModel.sensorStatus)
                }
                Text(viewModel.sensorSummary).font(.caption).foregroundStyle(.secondary)

                ForEach(viewModel.sensors) { sensor in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sensor.name ?? sensor.deviceId).font(.subheadline.weight(.medium))
                            Text(sensor.sensorType.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sensor.lastSeen?.formatted(.relative(presentation: .named)) ?? "Never seen")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.leading, 28)
                }

                Button { showSensorSetup = true } label: {
                    Label(viewModel.sensors.isEmpty ? "Pair a Sensor" : "Pair Another Sensor", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.activeFieldId == nil)
            }
            .padding(.vertical, 3)
        }
    }

    private var accountActionsSection: some View {
        Section("Account Actions") {
            if viewModel.canLinkGoogle {
                Button { viewModel.linkGoogleAccount() } label: {
                    HStack {
                        Label("Link Google Account", systemImage: "link")
                        Spacer()
                        if viewModel.isLoading { ProgressView() }
                    }
                }
                .disabled(viewModel.isLoading)
            }

            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label("Delete Current Field", systemImage: "trash")
            }
            .disabled(viewModel.activeFieldId == nil || viewModel.isLoading)

            Button(role: .destructive) { viewModel.signOut() } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            SettingsInfoRow(icon: "info.circle", label: "AgriVision", value: "Version \(viewModel.appVersion)")
            Text("Field data is isolated by your Firebase account. IoT sensors are optional; satellite and AI features remain field-scoped.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let error = viewModel.errorMessage {
            ToastView(message: error, type: .error).transition(.move(edge: .top).combined(with: .opacity))
        } else if let success = viewModel.successMessage {
            ToastView(message: success, type: .success).transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func navigateBack() {
        if let onBack { onBack() } else { dismiss() }
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

private struct StatusPill: View {
    let status: String

    private var color: Color {
        switch status {
        case "available": return .green
        case "pending", "stale": return .orange
        case "not_configured": return .secondary
        default: return .red
        }
    }

    var body: some View {
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct EditProfileSheet: View {
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

private struct SensorPairingSheet: View {
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

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            authService: MockAuthService(isLoggedIn: true),
            dataService: MockAgriDataRepository(mockCropType: "Rice"),
            preferencesService: MockPreferencesService()
        )
    )
}
