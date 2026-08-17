import Foundation

enum MetricDetailType: String, Identifiable, CaseIterable {
    case weather
    case health
    case moisture
    case phLevel
    case liveSensor
    case ndvi
    case vegetationIndices
    case uvIndex
    case forecast
    case soilChemistry
    case soilTemp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weather: return "Weather & Atmospheric"
        case .health: return "Crop Health & Vigor"
        case .moisture: return "Soil Moisture Analysis"
        case .phLevel: return "Soil pH & Acidity"
        case .liveSensor: return "Live IoT Sensor Stream"
        case .ndvi: return "NDVI Vegetation Index"
        case .vegetationIndices: return "Multispectral Indices"
        case .uvIndex: return "Solar UV Radiation"
        case .forecast: return "5-Day Weather Forecast"
        case .soilChemistry: return "Soil Chemistry & NPK"
        case .soilTemp: return "Soil Thermal Profile"
        }
    }

    var iconName: String {
        switch self {
        case .weather: return "cloud.sun.fill"
        case .health: return "heart.text.square.fill"
        case .moisture: return "drop.fill"
        case .phLevel: return "flask.fill"
        case .liveSensor: return "sensor.tag.radiowaves.forward.fill"
        case .ndvi: return "map.fill"
        case .vegetationIndices: return "leaf.fill"
        case .uvIndex: return "sun.max.fill"
        case .forecast: return "calendar"
        case .soilChemistry: return "testtube.2"
        case .soilTemp: return "thermometer.medium"
        }
    }
}
