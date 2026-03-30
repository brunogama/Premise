import Testing
import PremiseTesting
import PremiseStrategies

struct UsernameValidator {
  enum ValidationError: Error {
    case tooShort, tooLong, invalidCharacter, leadingUnderscore,
      trailingUnderscore, consecutiveUnderscores
  }

  func validate(_ username: String) throws {
    guard username.count >= 3 else { throw ValidationError.tooShort }
    guard username.count <= 20 else { throw ValidationError.tooLong }

    let valid = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
    for char in username.unicodeScalars {
      guard valid.contains(char) else { throw ValidationError.invalidCharacter }
    }

    guard username.first != "_" else { throw ValidationError.leadingUnderscore }
    guard username.last != "_" else { throw ValidationError.trailingUnderscore }
    guard !username.contains("__") else { throw ValidationError.consecutiveUnderscores }
  }
}

let validator = UsernameValidator()
