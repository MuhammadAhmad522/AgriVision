import SwiftUI

/**
 `DashboardView` is what the user actually sees on their screen.
 It is a passive view: it only renders state provided by the ViewModel and calls
 ViewModel methods in response to user interaction. It contains no business logic
 (Single Responsibility Principle).
 */
struct DashboardView: View {

    /// `@StateObject` owns the ViewModel and keeps it alive as long as this View is on screen.
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        List {
            // Welcome Section
            if let userName = viewModel.userName {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Welcome back,")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(userName)
                                .font(.headline)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Account Settings
            Section(header: Text("Account Settings")) {
                Button(action: {
                    viewModel.linkGoogleAccount()
                }) {
                    Label("Link Google Account", systemImage: "link")
                        .foregroundColor(AppColors.authGreen)
                }
            }

            Section(header: Text("Live Sensor Data")) {
                if viewModel.isLoading {
                    ProgressView("Updating...")
                } else {
                    ForEach(viewModel.readings) { reading in
                        SensorReadingRow(reading: reading)
                    }
                }
            }
        }
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") {
                    viewModel.signOut()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshData()
            }
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .overlay(alignment: .top) {
            Group {
                if let errorMessage = viewModel.errorMessage {
                    ToastView(message: errorMessage, type: .error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if let successMessage = viewModel.successMessage {
                    ToastView(message: successMessage, type: .success)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Add padding to ensure it doesn't touch the top edge
            // and has side padding from the screen edges
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.errorMessage)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.successMessage)
        }
    }
}

struct SensorReadingRow: View {
    let reading: SensorReading

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.type)
                    .font(.headline)

                Text(reading.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(String(format: "%.1f", reading.value)) \(reading.unit)")
                .fontWeight(.bold)
                .foregroundColor(AppColors.mediumGreen)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DashboardView(viewModel: DashboardViewModel(dataService: MockAgriDataRepository(), authService: MockAuthService(isLoggedIn: true)))
    }
}
