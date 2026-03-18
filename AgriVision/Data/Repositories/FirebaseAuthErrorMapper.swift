import Foundation
import FirebaseAuth

enum FirebaseAuthErrorMapper {
    static func map(_ error: Error) -> AgriVisionError {
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .userNotFound: return .userNotFound
            case .wrongPassword: return .wrongPassword
            case .emailAlreadyInUse: return .emailAlreadyInUse
            case .invalidEmail: return .invalidEmail
            case .weakPassword: return .weakPassword
            case .tooManyRequests: return .tooManyRequests
            case .networkError: return .networkUnavailable
            case .invalidCredential:
                return .unknown("The Google credential is invalid. Please try again.")
            default:
                break
            }
        }

        return .unknown(error.localizedDescription)
    }
}
