import SwiftUI
import Charts
import UIKit

private enum DashboardLayout {
    static let collapsedAlertsSheetHeight: CGFloat = 250
}

struct DashboardView: View {
        @Environment(\ .scenePhase) private var scenePhase
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedTab: DashboardTab = .home
    @State private var showingAlerts = false
    @State private var showingNotifications = false
    
    // Grid configuration
    let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.medium),
        GridItem(.flexible(), spacing: Theme.Spacing.medium)
    ]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - HOME TAB
            NavigationStack {
                ZStack {
                    // Background
                    Image("bg-image")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.large) {
                            // Safe area buffer to prevent header from hiding under the top notch/bar
                            Color.clear.frame(height: 60)
                            
                            // Header
                            DashboardHeaderView(
                                userName: viewModel.userName ?? "Farmer",
                                location: viewModel.activeField?.name ?? "No active field",
                                profileImageURL: viewModel.profileImageURL,
                                profileInitial: viewModel.profileInitial,
                                showNotifications: $showingNotifications,
                                notificationCount: 0
                            )
                            .padding(.horizontal, Theme.Spacing.large)
                            
                            if !viewModel.dataAvailability.isEmpty {
                                DataAvailabilityCard(items: viewModel.dataAvailability) {
                                    Task { await viewModel.requestDataRefresh() }
                                }
                                .padding(.horizontal, Theme.Spacing.large)
                            }
                            
                            // AI Recommendations Banner
                            Button(action: { showingAlerts = true }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(Theme.Colors.primaryLight)
                                    Text("AI Recommendations")
                                        .textStyle(.bodyStrong)
                                        .foregroundColor(Theme.Colors.primary)
                                    Spacer()
                                    if !viewModel.recommendations.isEmpty {
                                        Text("\(viewModel.recommendations.count)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Theme.Colors.error)
                                            .clipShape(Circle())
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Theme.Spacing.large)
                            
                            // Overview Section
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                Text("Overview")
                                    .textStyle(.title3)
                                    .padding(.horizontal, Theme.Spacing.large)
                                
                                HStack(spacing: Theme.Spacing.medium) {
                                    WeatherCardView(weather: viewModel.weatherSoil?.weather)
                                    HealthCardView(healthScore: viewModel.healthSummary?.score, cropType: viewModel.currentCropType)
                                        .padding(.trailing, Theme.Spacing.large)
                                }
                            }
                            
                            // Metrics Grid
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                Text("Field Metrics")
                                    .textStyle(.title3)
                                    .padding(.horizontal, Theme.Spacing.large)
                                
                                LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                                    MoistureCardView(moisture: viewModel.weatherSoil?.soil.moisture.map { Int($0 * 100) })
                                    PHLevelCardView(phLevel: viewModel.readings.first?.ph, sensorStatus: viewModel.sensorStatus)
                                    SensorLiveCardView(reading: viewModel.readings.first, sensorStatus: viewModel.sensorStatus)
                                    NDVICardView(ndvi: viewModel.satellite?.data?.statistics?["ndvi"]?.mean ?? viewModel.healthSummary?.score)
                                    VegetationIndicesCardView(statistics: viewModel.satellite?.data?.statistics)
                                    UVIndexCardView(snapshot: viewModel.uvi?.data, status: viewModel.uvi?.status)
                                    ForecastCardView(days: viewModel.weatherSoil?.weather.forecastDays ?? [])
                                    SensorChemistryCardView(reading: viewModel.readings.first, sensorStatus: viewModel.sensorStatus)
                                    SoilTempCardView(surfaceTemp: viewModel.weatherSoil?.soil.surfaceTempC, depthTemp: viewModel.weatherSoil?.soil.depthTempC)
                                }
                                .padding(.horizontal, Theme.Spacing.large)
                            }
                            

                            Spacer(minLength: 100)
                        }
                    }
                    .refreshable { await viewModel.refreshData() }
                }
                .navigationBarHidden(true)
                .sheet(isPresented: $showingAlerts) {
                    NavigationStack {
                        AlertsBottomSheet(
                            viewModel: viewModel,
                            onShowAll: { }, // no longer needed for sheet height
                            onAskAI: {
                                showingAlerts = false
                                selectedTab = .advisor
                            }
                        )
                        .navigationTitle("AI Recommendations")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingAlerts = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showingNotifications) {
                    NavigationStack {
                        VStack {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .padding(.bottom, 8)
                            Text("No new notifications")
                                .textStyle(.body)
                                .foregroundColor(.secondary)
                        }
                        .navigationTitle("Notifications")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingNotifications = false }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(DashboardTab.home)
            
            // MARK: - FIELDS TAB
            NavigationStack {
                FieldsView(
                    fieldStore: viewModel.fieldSessionStore,
                    satellite: viewModel.satellite,
                    satelliteImageData: viewModel.satelliteImageData,
                    sensorCount: viewModel.sensorCount,
                    snapshotFieldId: viewModel.loadedFieldId,
                    isLoadingSnapshot: viewModel.isLoading,
                    profileImageURL: viewModel.profileImageURL,
                    profileInitial: viewModel.profileInitial,
                    onAddField: viewModel.addField
                )
            }
            .tabItem { Label("Fields", systemImage: "leaf.fill") }
            .tag(DashboardTab.fields)
            
            // MARK: - AI ADVISOR TAB
            NavigationStack {
                if let activeFieldId = viewModel.fieldSessionStore.activeFieldId {
                    AIChatView(viewModel: AIChatViewModel(
                        dataService: viewModel.dataService,
                        fieldId: activeFieldId
                    ))
                    .id(activeFieldId)
                } else {
                    ContentUnavailableView(
                        "No Field Selected",
                        systemImage: "leaf",
                        description: Text("Select or add a field to chat with the AI Advisor.")
                    )
                }
            }
            .tabItem { Label("Advisor", systemImage: "sparkles") }
            .tag(DashboardTab.advisor)
            
            // MARK: - SETTINGS TAB
            NavigationStack {
                SettingsView(
                    viewModel: settingsViewModel,
                    onBack: { selectedTab = .home }
                )
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(DashboardTab.settings)
        }
        .tint(Theme.Colors.primaryMedium)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.pollUntilCancelled()
        }
        .task(id: viewModel.fieldSessionStore.activeFieldId) {
            await viewModel.refreshData()
        }
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage {
                ToastView(message: error, type: .error).padding(.top, 56).padding(.horizontal)
            } else if let success = viewModel.successMessage {
                ToastView(message: success, type: .success).padding(.top, 56).padding(.horizontal)
            }
        }
    }

}


private enum DashboardTab: Hashable {
    case home
    case fields
    case advisor
    case settings
}

// MARK: - Components


// Custom slanted shape sticking to the left




// MARK: - Metric Cards












// MARK: - Bottom Alerts Card


