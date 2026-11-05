import Foundation
import PremiseStrategies
import PremiseTesting
import Testing

struct Contact: Equatable {
  var name: String
  var email: String
  var age: Int
}

// Broken: custom encoder that omits `age` when it is 0.
extension Contact: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(email, forKey: .email)
    if age != 0 {
      try container.encode(age, forKey: .age)  // Bug: skips encoding age == 0
    }
  }

  enum CodingKeys: String, CodingKey { case name, email, age }
}

extension Contact: Decodable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    email = try container.decode(String.self, forKey: .email)
    age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 0
  }
}
