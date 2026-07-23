import Foundation

extension Error {
    /// Converts internal errors into safe, user-facing copy for UI surfaces.
    var userFacingMessage: String {
        let fallbackMessage = "We couldn’t complete your request right now. Please try again later or contact App Admin."

        if let agriError = self as? AgriVisionError {
            return agriError.errorDescription ?? fallbackMessage
        }
        if let validationError = self as? ValidationError {
            return validationError.errorDescription ?? fallbackMessage
        }
        if let apiError = self as? BackendAPIError {
            guard let requestID = apiError.requestID, !requestID.isEmpty else { return apiError.message }
            return "\(apiError.message) Reference: \(requestID.prefix(8))."
        }
        return fallbackMessage
    }
}
