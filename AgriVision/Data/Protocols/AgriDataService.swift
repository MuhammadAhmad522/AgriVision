import Foundation

/**
 A `protocol` in Swift is like a contract or a blueprint.
 It says: "Any class or struct that uses this protocol MUST have these specific methods."
 We use this so our ViewModels don't care *where* the data comes from (mock data or a real server),
 as long as it has a `fetchSensorReadings` method.
 */
protocol AgriDataService {
    /// Fetches sensor readings. It is marked `async` because it might take time (like downloading from the internet),
    /// and `throws` because it might fail (like if the internet is disconnected).
    func fetchSensorReadings() async throws -> [SensorReading]
}
