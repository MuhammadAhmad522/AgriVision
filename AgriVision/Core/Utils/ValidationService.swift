import Foundation

enum ValidationError: LocalizedError {
    case emptyField(String)
    case invalidEmail
    case passwordTooShort(min: Int)
    case passwordComplexity
    case passwordsDoNotMatch
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let fieldName):
            return "\(fieldName) cannot be empty."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .passwordTooShort(let min):
            return "Password must be at least \(min) characters long."
        case .passwordComplexity:
            return "Password must contain uppercase, lowercase, number, and special character."
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        }
    }
}

struct InputValidator {
    
    static func validate(email: String) throws {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyField("Email")
        }
        
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        if !emailPred.evaluate(with: email) {
            throw ValidationError.invalidEmail
        }
    }
    
    static func validate(password: String, minLength: Int = 8) throws {
        if password.isEmpty {
            throw ValidationError.emptyField("Password")
        }
        if password.count < minLength {
            throw ValidationError.passwordTooShort(min: minLength)
        }
        
        // Check for uppercase
        let uppercasePred = NSPredicate(format: "SELF MATCHES %@", ".*[A-Z]+.*")
        if !uppercasePred.evaluate(with: password) { throw ValidationError.passwordComplexity }
        
        // Check for lowercase
        let lowercasePred = NSPredicate(format: "SELF MATCHES %@", ".*[a-z]+.*")
        if !lowercasePred.evaluate(with: password) { throw ValidationError.passwordComplexity }
        
        // Check for number
        let numberPred = NSPredicate(format: "SELF MATCHES %@", ".*[0-9]+.*")
        if !numberPred.evaluate(with: password) { throw ValidationError.passwordComplexity }
        
        // Check for special character
        // Allow any non-alphanumeric character as special
        let specialPred = NSPredicate(format: "SELF MATCHES %@", ".*[^A-Za-z0-9].*")
        if !specialPred.evaluate(with: password) { throw ValidationError.passwordComplexity }
    }
    
    static func validate(value: String, fieldName: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.emptyField(fieldName)
        }
    }
}
