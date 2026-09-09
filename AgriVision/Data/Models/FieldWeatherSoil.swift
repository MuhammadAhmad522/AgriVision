import Foundation

/**
 The `FieldWeatherSoil` model represents the aggregated weather and soil telemetry
 fetched from the AgroMonitoring satellite and forecast APIs for a specific field.
 */
struct FieldWeatherSoil: Codable {
    let fieldId: UUID
    let soil: SoilData
    let weather: WeatherData
    
    struct SoilData: Codable {
        let moisture: Double?
        let surfaceTempC: Double?
        let depthTempC: Double?
        let source: String
        
        enum CodingKeys: String, CodingKey {
            case moisture
            case surfaceTempC = "surface_temp_c"
            case depthTempC = "depth_temp_c"
            case source
        }
    }
    
    struct WeatherData: Codable {
        let current: CurrentWeather
        let forecastDays: [ForecastDay]
        let source: String
        
        enum CodingKeys: String, CodingKey {
            case current
            case forecastDays = "forecast_days"
            case source
        }
    }
    
    struct CurrentWeather: Codable {
        let tempC: Double?
        let humidity: Double?
        let description: String?
        
        enum CodingKeys: String, CodingKey {
            case tempC = "temp_c"
            case humidity
            case description
        }
    }
    
    struct ForecastDay: Codable, Identifiable {
        var id: String { date }
        let date: String
        let tempMaxC: Double?
        let tempMinC: Double?
        let rainMm: Double?
        let description: String?
        
        enum CodingKeys: String, CodingKey {
            case date
            case tempMaxC = "temp_max_c"
            case tempMinC = "temp_min_c"
            case rainMm = "rain_mm"
            case description
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case fieldId = "field_id"
        case soil
        case weather
    }
}
