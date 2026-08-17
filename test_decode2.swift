import Foundation

struct Field: Identifiable, Codable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let coordinates: [PointCoordinates]?
    let areaHa: Double?
    let createdAt: Date
    let cropType: String?
    let plantationDate: Date?
    let expectedHarvestDate: Date?
    var status: String = "active"
    var archivedAt: Date? = nil
    var updatedAt: Date? = nil
    var agromonitoringPolygonId: String? = nil
    var agroStatus: String = "pending"
    var agroError: String? = nil
    var agroRetryable: Bool = true
    let ndviScore: Double?
    let lastSatelliteSync: Date?
    enum CodingKeys: String, CodingKey {
        case id, name, coordinates, status
        case ownerId = "owner_id"
        case areaHa = "area_ha"
        case createdAt = "created_at"
        case cropType = "crop_type"
        case plantationDate = "plantation_date"
        case expectedHarvestDate = "expected_harvest_date"
        case archivedAt = "archived_at"
        case updatedAt = "updated_at"
        case agromonitoringPolygonId = "agromonitoring_polygon_id"
        case agroStatus = "agro_status"
        case agroError = "agro_error"
        case agroRetryable = "agro_retryable"
        case ndviScore = "latest_ndvi"
        case lastSatelliteSync = "last_satellite_sync"
    }
}
struct PointCoordinates: Codable { let latitude: Double; let longitude: Double }
struct DashboardSnapshot: Decodable {
    let field: Field
    let sources: DashboardSources
    let advisor: AdvisorSnapshot?
    let recommendations: [FieldRecommendation]
}
struct DashboardSources: Decodable {
    let satellite: SourceState<SatelliteSnapshot>
    let soil: SourceState<SoilData>
    let weather: SourceState<WeatherData>
    let uvi: SourceState<UVISnapshot>
    let sensors: SourceState<[SensorReading]>
}
struct SourceState<Value: Decodable>: Decodable {
    let status: String
    let lastUpdated: Date?
    let data: Value?
    let message: String?
    let retryable: Bool?
    let configuredCount: Int?
    let reportingCount: Int?
    enum CodingKeys: String, CodingKey {
        case status, data, message, retryable
        case lastUpdated = "last_updated"
        case configuredCount = "configured_count"
        case reportingCount = "reporting_count"
    }
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
    enum CodingKeys: String, CodingKey { case standardDeviation = "std"; case mean, median, min, max }
}
struct SoilData: Codable { let moisture: Double?; let surfaceTempC: Double?; let depthTempC: Double?; let source: String; enum CodingKeys: String, CodingKey { case moisture, source; case surfaceTempC = "surface_temp_c"; case depthTempC = "depth_temp_c" } }
struct WeatherData: Codable { let current: CurrentWeather; let forecastDays: [ForecastDay]; let source: String; enum CodingKeys: String, CodingKey { case current, source; case forecastDays = "forecast_days" } }
struct CurrentWeather: Codable { let tempC: Double?; let humidity: Double?; let description: String?; enum CodingKeys: String, CodingKey { case tempC = "temp_c"; case humidity, description } }
struct ForecastDay: Codable { let date: String; let tempMaxC: Double?; let tempMinC: Double?; let rainMm: Double?; let description: String?; enum CodingKeys: String, CodingKey { case date, description; case tempMaxC = "temp_max_c"; case tempMinC = "temp_min_c"; case rainMm = "rain_mm" } }
struct UVISnapshot: Decodable { let uvi: Double?; let dt: Int? }
struct SensorReading: Codable {}
struct AdvisorSnapshot: Decodable { let status: String; let lastUpdated: Date?; let message: String?; let retryable: Bool?; let dataQuality: String?; enum CodingKeys: String, CodingKey { case status, message, retryable; case lastUpdated = "last_updated"; case dataQuality = "data_quality" } }
struct FieldRecommendation: Codable {
    let id: UUID
    let fieldId: UUID
    let category: String
    let priority: String
    let advice: String
    var rationale: String? = nil
    let confidence: Double?
    var confidenceReason: String? = nil
    var evidence: [RecommendationEvidence]? = nil
    var safetyLevel: String = "guarded"
    var requiresExpertConfirmation: Bool = false
    let status: String
    let ndviAtGeneration: Double?
    let createdAt: Date
    var expiresAt: Date? = nil
    var outcome: String? = nil
    var outcomeNotes: String? = nil
    enum CodingKeys: String, CodingKey { case id, category, priority, advice, rationale, confidence, evidence, status, outcome; case fieldId = "field_id"; case confidenceReason = "confidence_reason"; case safetyLevel = "safety_level"; case requiresExpertConfirmation = "requires_expert_confirmation"; case ndviAtGeneration = "ndvi_at_generation"; case createdAt = "created_at"; case expiresAt = "expires_at"; case outcomeNotes = "outcome_notes" }
}
struct RecommendationEvidence: Codable {
    let url: String?
    let approved: Bool?
    let metric: String?
    let value: Double?
}

let json = """
{"field":{"id":"d145abef-1ab1-4ec6-9d3f-4cf8f858f60f","owner_id":"2cd75f55-fd6b-449e-ba3a-e9808d02e525","name":"Ggs","coordinates":[{"longitude":74.32759533,"latitude":31.55253864},{"longitude":74.32927443,"latitude":31.54944014},{"longitude":74.32855719,"latitude":31.55271529}],"area_ha":1.7249571414649487,"status":"active","archived_at":null,"created_at":"2026-08-05T14:49:24.921984+00:00","updated_at":"2026-08-06T05:42:51.475058+00:00","crop_type":"Wheat","plantation_date":"2026-08-05T14:48:49+00:00","expected_harvest_date":"2026-12-03T14:48:49+00:00","agromonitoring_polygon_id":"6a734f2b4e13cb7f84faed03","agro_status":"available","agro_error":null,"agro_retryable":true,"latest_ndvi":0.11585851099323606,"last_satellite_sync":"2026-08-06T05:42:53.008898+00:00","interval_overrides":null},"sources":{"satellite":{"status":"available","last_updated":"2026-08-04T00:00:00+00:00","data":{"scene_id":"d0a0686b-bf36-4491-8a76-8185c36a18c5","acquired_at":"2026-08-04T00:00:00+00:00","cloud_percent":100.0,"coverage_percent":100.0,"statistics":{"evi":{"max":0.3698930889652541,"min":0.09344115004492366,"num":264,"p25":0.17506667318394736,"p75":0.25162691474906035,"std":0.053242141994607826,"mean":0.21223732939110398,"median":0.20988251164399652},"evi2":{"max":0.13868476846720953,"min":0.039711632453567944,"num":264,"p25":0.06632698287942543,"p75":0.09204820305847025,"std":0.016923560022469263,"mean":0.07905040059558961,"median":0.07937441352723272},"ndvi":{"max":0.21604503870513722,"min":0.05379310344827586,"num":264,"p25":0.09206998431129161,"p75":0.1382589010106774,"std":0.02952420755817589,"mean":0.11585851099323606,"median":0.11518736326961299}},"ndvi_image_url":"/api/fields/d145abef-1ab1-4ec6-9d3f-4cf8f858f60f/satellite/latest/ndvi","truecolor_image_url":"/api/fields/d145abef-1ab1-4ec6-9d3f-4cf8f858f60f/satellite/latest/truecolor"},"message":null,"retryable":true},"soil":{"status":"available","last_updated":"2026-08-06T00:00:00+00:00","data":{"source":"agromonitoring","moisture":0.301,"observed_at":1785974400,"depth_temp_c":28.5,"surface_temp_c":25.6},"message":null,"retryable":false},"weather":{"status":"available","last_updated":"2026-08-06T05:42:51.543069+00:00","data":{"source":"agromonitoring","current":{"temp_c":35.79,"humidity":47,"description":"overcast clouds"},"forecast_days":[{"date":"2026-08-06","rain_mm":3.9,"temp_max_c":38.23,"temp_min_c":28.85,"description":"light rain"},{"date":"2026-08-07","rain_mm":0.0,"temp_max_c":38.64,"temp_min_c":27.84,"description":"clear sky"},{"date":"2026-08-08","rain_mm":2.5,"temp_max_c":35.37,"temp_min_c":28.72,"description":"light rain"},{"date":"2026-08-09","rain_mm":2.0,"temp_max_c":38.33,"temp_min_c":27.42,"description":"broken clouds"},{"date":"2026-08-10","rain_mm":0.3,"temp_max_c":36.84,"temp_min_c":30.87,"description":"overcast clouds"}]},"message":null,"retryable":false},"uvi":{"status":"available","last_updated":"2026-08-06T05:42:51.524051+00:00","data":{"dt":1786017600,"uvi":11.48},"message":null,"retryable":false},"sensors":{"status":"not_configured","last_updated":null,"data":[],"configured_count":0,"reporting_count":0,"message":"IoT monitoring is optional for this field.","retryable":false}},"advisor":{"status":"available","last_updated":"2026-08-06T11:28:50.507985+00:00","message":null,"retryable":false,"data_quality":"good"},"recommendations":[{"priority":"medium","status":"pending","analysis_run_id":"d14c24c1-5052-40a9-8548-acdebc531862","advice":"Perform daily physical field scouting to monitor for seedling emergence and check for soil crusting. Since the wheat crop was planted only 1 day ago (August 5, 2026) and the latest NDVI is 0.1158 (indicating bare soil), satellite data cannot yet confirm germination. Physical inspection is necessary to verify early stand establishment.","ndvi_at_generation":0.11585851099323606,"id":"59fd3384-7cda-4106-980e-5adec4bc50c6","rationale":"The crop is in the critical germination phase. High temperatures (up to 38.64°C) combined with light rain (up to 3.9 mm) can cause soil crusting, which physically restricts emerging wheat coleoptiles.","created_at":"2026-08-06T11:28:21.482591+00:00","category":"Field Monitoring","confidence":0.75,"feedback_at":null,"confidence_reason":"NDVI and soil moisture (0.301 m3/m3) are fresh and consistent with a newly planted field, but satellite sensors cannot directly observe germination at this stage.","expires_at":"2026-08-13T11:28:50.506759+00:00","evidence":[],"outcome":null,"safety_level":"routine","outcome_notes":null,"field_id":"d145abef-1ab1-4ec6-9d3f-4cf8f858f60f","requires_expert_confirmation":false,"outcome_at":null},{"priority":"medium","status":"pending","analysis_run_id":"d14c24c1-5052-40a9-8548-acdebc531862","advice":"Monitor soil moisture levels closely as temperatures are forecast to reach up to 38.64°C with an extremely high UV index of 11.48. Ensure that the soil does not dry out rapidly, which could desiccate germinating seeds, while also keeping drainage pathways clear for the forecast light rain events (up to 3.9 mm).","ndvi_at_generation":0.11585851099323606,"id":"6ab08cce-325f-447f-9c8e-9452b611886c","rationale":"Newly sown wheat seeds are highly vulnerable to heat stress and moisture fluctuations. The combination of high temperatures and high UV exposure can rapidly dry the topsoil layer.","created_at":"2026-08-06T11:28:21.482591+00:00","category":"Weather Alert","confidence":0.75,"feedback_at":null,"confidence_reason":"Based on fresh weather forecast and UVI data showing high temperatures and high solar radiation immediately following the planting date.","expires_at":"2026-08-13T11:28:50.507886+00:00","evidence":[],"outcome":null,"safety_level":"guarded","outcome_notes":null,"field_id":"d145abef-1ab1-4ec6-9d3f-4cf8f858f60f","requires_expert_confirmation":false,"outcome_at":null},{"priority":"high","status":"pending","analysis_run_id":"aaf71241-95e8-44fd-bf34-b14c305cc66c","advice":"Low Vegetation Health Index detected (NDVI: 0.12). Inspect the field for signs of pest stress or nutrient deficiency.","ndvi_at_generation":0.11585851099323606,"id":"833a0fe7-cd1c-43e0-86b2-e7bfc4fdc1cc","rationale":"Satellite multi-spectral analysis indicates lower-than-normal canopy vigor.","created_at":"2026-08-06T11:22:57.065899+00:00","category":"Plant Health","confidence":0.85,"feedback_at":null,"confidence_reason":"Sentinel-2 Satellite Remote Sensing (NDVI 0.12).","expires_at":"2026-08-13T11:23:29.974205+00:00","evidence":[{"value":0.12,"metric":"latest_ndvi"}],"outcome":null,"safety_level":"routine","outcome_notes":null,"field_id":"d145abef-1ab1-4ec6-9d3f-4cf8f858f60f","requires_expert_confirmation":false,"outcome_at":null},{"priority":"medium","status":"pending","analysis_run_id":"e3da513c-6427-4e8a-a609-145fe5d973ca","advice":"Carefully manage soil moisture levels to support germination without causing waterlogging. Monitor the soil moisture (currently measured at 0.301 m3/m3) alongside the forecasted light rains (3.9 mm on Aug 6 and 2.5 mm on Aug 8). Consult a local agronomy expert before applying any supplementary irrigation.","ndvi_at_generation":0.11585851099323606,"id":"8b7e88bd-0e91-4fc1-b646-03d59140bad1","rationale":"Sufficient moisture is vital for wheat germination, but excessive water can reduce soil oxygen and rot the seeds. High ambient temperatures (up to 38.64°C) will accelerate evaporation, meaning moisture levels in the seeding zone must be verified manually.","created_at":"2026-08-06T11:03:54.345582+00:00","category":"Irrigation","confidence":0.75,"feedback_at":null,"confidence_reason":"Soil moisture and weather forecast data are fresh, but physical verification of the seed-zone moisture is missing and required for precise irrigation scheduling.","expires_at":"2026-08-13T11:04:11.137442+00:00","evidence":[],"outcome":null,"safety_level":"guarded","outcome_notes":null,"field_id":"d145abef-1ab1-4ec6-9d3f-4cf8f858f60f","requires_expert_confirmation":true,"outcome_at":null}]}
"""
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    let formatter1 = ISO8601DateFormatter()
    formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let formatter2 = ISO8601DateFormatter()
    formatter2.formatOptions = [.withInternetDateTime]
    if let date = formatter1.date(from: value) ?? formatter2.date(from: value) {
        return date
    }
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
}

do {
    let _ = try decoder.decode(DashboardSnapshot.self, from: json.data(using: .utf8)!)
    print("SUCCESS")
} catch {
    print("ERROR:", error)
}
