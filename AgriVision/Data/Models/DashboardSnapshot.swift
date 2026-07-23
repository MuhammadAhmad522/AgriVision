import Foundation

struct SourceState<Value: Decodable>: Decodable {
    let status: String
    let lastUpdated: Date?
    let data: Value?
    let message: String?
    let retryable: Bool?
    let configuredCount: Int?
    let reportingCount: Int?

    var availability: DataSourceStatus { DataSourceStatus(rawValue: status) ?? .unavailable }
    var canRetry: Bool { retryable ?? false }

    init(
        status: String,
        lastUpdated: Date?,
        data: Value?,
        message: String?,
        retryable: Bool? = nil,
        configuredCount: Int? = nil,
        reportingCount: Int? = nil
    ) {
        self.status = status
        self.lastUpdated = lastUpdated
        self.data = data
        self.message = message
        self.retryable = retryable
        self.configuredCount = configuredCount
        self.reportingCount = reportingCount
    }

    enum CodingKeys: String, CodingKey {
        case status, data, message, retryable
        case lastUpdated = "last_updated"
        case configuredCount = "configured_count"
        case reportingCount = "reporting_count"
    }
}

enum DataSourceStatus: String, Decodable {
    case available, pending, stale, unavailable, unsupported
    case notConfigured = "not_configured"
}

struct DataAvailabilityItem: Identifiable {
    let id: String
    let title: String
    let status: DataSourceStatus
    let lastUpdated: Date?
    let message: String?
    let retryable: Bool
}

struct DashboardSnapshot: Decodable {
    let field: Field
    let sources: DashboardSources
    let advisor: AdvisorSnapshot?
    let recommendations: [FieldRecommendation]
}

struct AdvisorSnapshot: Decodable {
    let status: String
    let lastUpdated: Date?
    let message: String?
    let retryable: Bool?
    let dataQuality: String?

    enum CodingKeys: String, CodingKey {
        case status, message, retryable
        case lastUpdated = "last_updated"
        case dataQuality = "data_quality"
    }
}

struct DashboardSources: Decodable {
    let satellite: SourceState<SatelliteSnapshot>
    let soil: SourceState<FieldWeatherSoil.SoilData>
    let weather: SourceState<FieldWeatherSoil.WeatherData>
    let uvi: SourceState<UVISnapshot>
    let sensors: SourceState<[SensorReading]>
}

struct SatelliteSnapshot: Decodable {
    let sceneId: UUID
    let acquiredAt: Date
    let cloudPercent: Double?
    let coveragePercent: Double?
    let statistics: [String: VegetationStatistics]?
    let ndviImageURL: String?
    let truecolorImageURL: String?

    enum CodingKeys: String, CodingKey {
        case statistics
        case sceneId = "scene_id"
        case acquiredAt = "acquired_at"
        case cloudPercent = "cloud_percent"
        case coveragePercent = "coverage_percent"
        case ndviImageURL = "ndvi_image_url"
        case truecolorImageURL = "truecolor_image_url"
    }
}

struct VegetationStatistics: Decodable {
    let mean: Double?
    let median: Double?
    let min: Double?
    let max: Double?
    let standardDeviation: Double?

    enum CodingKeys: String, CodingKey {
        case mean, median, min, max
        case standardDeviation = "std"
    }
}

struct UVISnapshot: Decodable {
    let uvi: Double?
    let dt: Int?
}
