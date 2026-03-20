import Foundation

extension Error {
    /// Converts internal errors into safe, user-facing copy for UI surfaces.
    var userFacingMessage: String {
        let fallbackMessage = "We couldn’t complete your request right now. Please try again."

        if let agriError = self as? AgriVisionError {
            return agriError.errorDescription ?? fallbackMessage
        }
        if let validationError = self as? ValidationError {
            return validationError.errorDescription ?? fallbackMessage
        }
        return fallbackMessage
    }
}
