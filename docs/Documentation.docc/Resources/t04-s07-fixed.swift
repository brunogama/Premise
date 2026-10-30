import Foundation

struct Contact: Equatable, Codable {
  var name: String
  var email: String
  var age: Int
  // Using the synthesized Codable conformance — no custom encoder needed.
}
