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
        ZStack {
            // Background
            Color(AppColors.cream).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Card
                    if let userName = viewModel.userName {
                        GlassCard {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.limeGreen.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColors.charcoalGreen)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome back,")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.charcoalGreen.opacity(0.7))
                                    Text(userName)
                                        .font(.title3.bold())
                                        .foregroundColor(AppColors.charcoalGreen)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    // Account Settings Card
                    GlassCard(title: "Account Settings") {
                        Button(action: {
                            viewModel.linkGoogle()
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    
                                    Image(systemName: "link")
                                        .foregroundColor(AppColors.mediumGreen)
                                        .font(.system(size: 16))
                                }
                                
                                Text("Link Google Account")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColors.charcoalGreen)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppColors.limeGreen)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Sensor Data Card
                    GlassCard(title: "Live Sensor Data") {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(AppColors.mediumGreen)
                                Spacer()
                            }
                            .padding()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.readings) { reading in
                                    SensorReadingRow(reading: reading)
                                    if reading.id != viewModel.readings.last?.id {
                                        Divider()
                                            .background(AppColors.limeGreen.opacity(0.3))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.openSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(AppColors.mediumGreen)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.refreshData()
            }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(reading.type)
                    .font(.headline)
                    .foregroundColor(AppColors.charcoalGreen)
                Text(reading.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(AppColors.charcoalGreen.opacity(0.6))
            }
            Spacer()
            Text(String(format: "%.1f", reading.value))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.mediumGreen)
            Text(reading.unit)
                .font(.caption)
                .bold()
                .foregroundColor(AppColors.limeGreen)
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
