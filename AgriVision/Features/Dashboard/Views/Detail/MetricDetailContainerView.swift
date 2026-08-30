import SwiftUI

struct MetricDetailContainerView: View {
    let type: MetricDetailType
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                
                Group {
                    switch type {
                    case .weather, .forecast:
                        WeatherDetailView(weather: viewModel.weatherSoil?.weather)
                    case .health:
                        AIFieldHealthDetailView(
                            healthScore: viewModel.healthSummary?.score,
                            healthLabel: viewModel.healthSummary?.label ?? "insufficient_data",
                            rationale: viewModel.healthSummary?.rationale,
                            updatedAt: viewModel.healthSummary?.updatedAt,
                            cropType: viewModel.currentCropType,
                            recommendations: viewModel.recommendations,
                            advisorStatus: viewModel.advisorStatus
                        )
                    case .ndvi:
                        HealthNDVIDetailView(
                            cropType: viewModel.currentCropType,
                            statistics: viewModel.satellite?.data?.statistics
                        )
                    case .moisture:
                        MoistureDetailView(
                            moisture: viewModel.weatherSoil?.soil.moisture.map { Int($0 * 100) },
                            cropType: viewModel.currentCropType,
                            historicalReadings: viewModel.readings
                        )
                    case .phLevel:
                        SoilPHDetailView(
                            phLevel: viewModel.readings.first?.ph,
                            sensorStatus: viewModel.sensorStatus,
                            cropType: viewModel.currentCropType,
                            readings: viewModel.readings
                        )
                    case .liveSensor:
                        LiveSensorDetailView(
                            reading: viewModel.readings.first,
                            sensorStatus: viewModel.sensorStatus,
                            readings: viewModel.readings
                        )
                    case .vegetationIndices:
                        VegetationIndicesDetailView(
                            statistics: viewModel.satellite?.data?.statistics
                        )
                    case .uvIndex:
                        UVIndexDetailView(
                            snapshot: viewModel.uvi?.data,
                            status: viewModel.uvi?.status
                        )
                    case .soilChemistry:
                        SoilChemistryDetailView(
                            reading: viewModel.readings.first,
                            sensorStatus: viewModel.sensorStatus,
                            cropType: viewModel.currentCropType
                        )
                    case .soilTemp:
                        SoilTempDetailView(
                            surfaceTemp: viewModel.weatherSoil?.soil.surfaceTempC,
                            depthTemp: viewModel.weatherSoil?.soil.depthTempC,
                            cropType: viewModel.currentCropType
                        )
                    }
                }
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
