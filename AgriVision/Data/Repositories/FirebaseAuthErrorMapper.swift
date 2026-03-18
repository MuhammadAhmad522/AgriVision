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
            case .invalidCredential: return .invalidCredentials
            case .emailAlreadyInUse: return .emailAlreadyInUse
            case .invalidEmail: return .invalidEmail
            case .weakPassword: return .weakPassword
            case .userDisabled: return .unknown("This account has been disabled. Please contact support.")
            case .requiresRecentLogin: return .unknown("For your security, please sign in again and retry.")
            case .tooManyRequests: return .tooManyRequests
            case .networkError: return .networkUnavailable
            case .operationNotAllowed:
                return .operationFailed
            case .internalError:
                return .operationFailed
            default:
                break
            }
        }

        #if DEBUG
        print("Unmapped Firebase auth error encountered (domain: \(nsError.domain), code: \(nsError.code)). Falling back to generic message.")
        #endif
        return .operationFailed
    }
}
