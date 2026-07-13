import SwiftUI

/// The Settings tab's view layer. Existing account and field actions are preserved while the
/// remaining rows intentionally expose presentation-only placeholders for the next iteration.
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    var onBack: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var pushNotificationsEnabled = true

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
                    accountSection
                    preferencesSection
                    integrationsSection
                    supportSection
                    accountActionsSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.top, 16, for: .scrollContent)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            toastOverlay
                .padding(.top, 72)
                .padding(.horizontal)
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

            Text(viewModel.title)
                .font(.title2.weight(.bold))

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: 64)
        .background(AppColors.mediumGreen)
        .background(AppColors.mediumGreen.ignoresSafeArea(edges: .top))
    }

    private var accountSection: some View {
        Section {
            SettingsValueRow(
                label: "Account",
                value: viewModel.accountName,
                emphasized: true,
                action: placeholderAction
            )

            SettingsNavigationRow(label: "Edit Profile", action: placeholderAction)

            SettingsValueRow(
                label: "Current Field",
                value: viewModel.currentFieldName,
                action: placeholderAction
            )
        }
    }

    private var preferencesSection: some View {
        Section("App Preferences") {
            SettingsValueRow(
                label: "Units of Measurement",
                value: "Metric",
                action: placeholderAction
            )

            Toggle("Push Notifications", isOn: $pushNotificationsEnabled)
                .tint(AppColors.mediumGreen)
        }
    }

    private var integrationsSection: some View {
        Section("Sensors & Satellite Integrations") {
            SettingsValueRow(
                label: "Auto-Refresh",
                value: "Daily",
                action: placeholderAction
            )

            SettingsNavigationRow(label: "IoT Sensors", action: placeholderAction)
            SettingsNavigationRow(label: "Import Soil Test Report", action: placeholderAction)
        }
    }

    private var supportSection: some View {
        Section("Help & Support") {
            SettingsNavigationRow(label: "Help Center", action: placeholderAction)
            SettingsNavigationRow(label: "FAQs", action: placeholderAction)
            SettingsNavigationRow(label: "Privacy Policy", action: placeholderAction)
        }
    }

    private var accountActionsSection: some View {
        Section("Account Actions") {
            Button {
                viewModel.linkGoogleAccount()
            } label: {
                HStack {
                    Label("Link Google Account", systemImage: "link")
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isLoading)

            Button(role: .destructive) {
                viewModel.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let errorMessage = viewModel.errorMessage {
            ToastView(message: errorMessage, type: .error)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if let successMessage = viewModel.successMessage {
            ToastView(message: successMessage, type: .success)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func navigateBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func placeholderAction() {
        // TODO: Connect this row to its coordinator destination.
    }
}

private struct SettingsNavigationRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow: View {
    let label: String
    let value: String
    var emphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .fontWeight(emphasized ? .semibold : .regular)
                    .foregroundStyle(Color.primary)

                Spacer()

                Text(value)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
