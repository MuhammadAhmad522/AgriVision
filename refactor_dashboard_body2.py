import re

with open("AgriVision/Features/Dashboard/Views/DashboardView.swift", "r") as f:
    content = f.read()

# 1. Replace DashboardView body
new_body = """    @Environment(\\ .scenePhase) private var scenePhase
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedTab: DashboardTab = .home
    @State private var showingAlerts = false
    
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
                            // Header
                            DashboardHeaderView(
                                userName: viewModel.userName ?? "Farmer",
                                location: viewModel.activeField?.name ?? "No active field",
                                profileImageURL: viewModel.profileImageURL,
                                profileInitial: viewModel.profileInitial,
                                showAlerts: $showingAlerts,
                                alertCount: viewModel.recommendations.count
                            )
                            .padding(.horizontal, Theme.Spacing.large)
                            .padding(.top, Theme.Spacing.large)
                            
                            if !viewModel.dataAvailability.isEmpty {
                                DataAvailabilityCard(items: viewModel.dataAvailability) {
                                    Task { await viewModel.requestDataRefresh() }
                                }
                                .padding(.horizontal, Theme.Spacing.large)
                            }
                            
                            // Overview Section
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                Text("Overview")
                                    .textStyle(.title3)
                                    .padding(.horizontal, Theme.Spacing.large)
                                
                                HStack(spacing: Theme.Spacing.medium) {
                                    WeatherCardView(weather: viewModel.weatherSoil?.weather)
                                    HealthCardView(healthScore: viewModel.healthSummary?.score, cropType: viewModel.currentCropType)
                                }
                                .padding(.horizontal, Theme.Spacing.large)
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
                            
                            // Imagery Section
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                Text("Satellite Imagery")
                                    .textStyle(.title3)
                                    .padding(.horizontal, Theme.Spacing.large)
                                
                                SatelliteImageCardView(imageData: viewModel.truecolorImageData)
                                    .padding(.horizontal, Theme.Spacing.large)
                                SatelliteQualityCardView(snapshot: viewModel.satellite?.data)
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
                            onShowAll: { } // no longer needed for sheet height
                        )
                        .navigationTitle("Alerts")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingAlerts = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
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
                AIChatView(viewModel: AIChatViewModel(
                    dataService: viewModel.dataService,
                    fieldId: viewModel.activeField?.id ?? UUID()
                ))
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
"""

dashboard_pattern = r'(@Environment\(\\\.scenePhase\).*?ToastView\(message: success, type: \.success\)\.padding\(\.top, 56\)\.padding\(\.horizontal\)\n            \}\n        \}\n    \})'

content = re.sub(dashboard_pattern, new_body, content, flags=re.DOTALL)

# Add .advisor to DashboardTab
content = content.replace("case fields", "case fields\n    case advisor")

# 2. Fix DashboardHeaderView
header_pattern = r'(struct DashboardHeaderView: View \{\n    var userName: String\n    var location: String\n    var profileImageURL: URL\?\n    var profileInitial: String)(.*?)(var body: some View \{)'
new_header_vars = r'\1\n    @Binding var showAlerts: Bool\n    var alertCount: Int\n    \3'
content = re.sub(header_pattern, new_header_vars, content, flags=re.DOTALL)

# Specifically inject the bell icon right after the Avatar block inside DashboardHeaderView
bell_icon = """                
                Button(action: { showAlerts = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                        
                        if alertCount > 0 {
                            Text("\\(alertCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)"""

# Locate the Avatar block
avatar_block = """                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 32))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    // Fallback to user initials if no profile picture
                    Text(profileInitial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.Colors.primaryMedium)
                        .clipShape(Circle())
                }"""

content = content.replace(avatar_block, avatar_block + bell_icon)

with open("AgriVision/Features/Dashboard/Views/DashboardView.swift", "w") as f:
    f.write(content)
