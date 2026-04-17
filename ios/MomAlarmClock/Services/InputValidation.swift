import Foundation

/// Centralized input validation for registration, pairing, and profile fields.
/// All validation is client-side for UX; server-side rules enforce security.
enum InputValidation {

    // MARK: - Name

    /// Validates a display name (guardian or child).
    /// Requirements: 1-50 characters, at least one letter, no leading/trailing whitespace.
    static func validateName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return .invalid("Name is required.")
        }
        if trimmed.count > 50 {
            return .invalid("Name must be 50 characters or fewer.")
        }
        if !trimmed.contains(where: { $0.isLetter }) {
            return .invalid("Name must contain at least one letter.")
        }
        return .valid
    }

    // MARK: - Email

    /// Validates an email address format.
    /// Uses a practical regex — not RFC 5322 compliant but catches obvious mistakes.
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.isEmpty {
            return .invalid("Email is required.")
        }
        // Practical email format: no consecutive dots, no leading/trailing dots
        let pattern = #"^[A-Za-z0-9]([A-Za-z0-9._%+\-]*[A-Za-z0-9])?@[A-Za-z0-9]([A-Za-z0-9\-]*[A-Za-z0-9])?(\.[A-Za-z]{2,})+$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil,
              !trimmed.contains("..") else {
            return .invalid("Enter a valid email address.")
        }
        return .valid
    }

    // MARK: - Password

    /// Validates password strength.
    /// Requirements: 8+ characters, at least one uppercase, one lowercase, one number.
    static func validatePassword(_ password: String) -> ValidationResult {
        if password.count < 8 {
            return .invalid("Password must be at least 8 characters.")
        }
        if !password.contains(where: { $0.isUppercase }) {
            return .invalid("Password needs at least one uppercase letter.")
        }
        if !password.contains(where: { $0.isLowercase }) {
            return .invalid("Password needs at least one lowercase letter.")
        }
        if !password.contains(where: { $0.isNumber }) {
            return .invalid("Password needs at least one number.")
        }
        return .valid
    }

    /// Returns a password strength indicator for UI display.
    static func passwordStrength(_ password: String) -> PasswordStrength {
        if password.count < 8 { return .weak }
        var score = 0
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }) { score += 1 }
        if password.count >= 12 { score += 1 }
        switch score {
        case 0...2: return .weak
        case 3: return .medium
        default: return .strong
        }
    }

    // MARK: - Join Code

    /// Validates a family join code format.
    /// Must be exactly 10 alphanumeric characters from the allowed set.
    static func validateJoinCode(_ code: String) -> ValidationResult {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.isEmpty {
            return .invalid("Enter the family join code.")
        }
        if trimmed.count != 10 {
            return .invalid("Join code must be exactly 10 characters.")
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        if !trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return .invalid("Join code uses only letters A-Z (except I, O) and numbers 2-9.")
        }
        return .valid
    }

    // MARK: - Types

    enum ValidationResult: Equatable {
        case valid
        case invalid(String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var errorMessage: String? {
            if case .invalid(let msg) = self { return msg }
            return nil
        }
    }

    enum PasswordStrength {
        case weak, medium, strong

        var label: String {
            switch self {
            case .weak: "Weak"
            case .medium: "Medium"
            case .strong: "Strong"
            }
        }

        var color: String {
            switch self {
            case .weak: "red"
            case .medium: "orange"
            case .strong: "green"
            }
        }
    }
}
