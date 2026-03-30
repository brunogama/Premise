import Foundation
import Testing
import PremiseTesting
import PremiseStrategies

struct Contact: Codable, Equatable {
  var name: String
  var email: String
  var age: Int
}

// The same contactStrategy from earlier…
let safe = Array("abcdefghijklmnopqrstuvwxyz0123456789")
let domains = ["example.com", "test.org", "mail.net"]
let contactStrategy: Strategy<Contact> = Strategy<String>
  .strings(from: safe, length: 2...20)
  .flatMap { name in
    Strategy<String>.strings(from: safe, length: 3...10).flatMap { local in
      Strategy<Int>.integers(in: 0...120).map { age in
        Contact(name: name, email: "\(local)@\(domains[0])", age: age)
      }
    }
  }

@Test func contactRoundTripsJSON() async throws {
  let e = JSONEncoder()
  let d = JSONDecoder()
  try await forAll(contactStrategy) { contact in
    #expect(try d.decode(Contact.self, from: e.encode(contact)) == contact)
  }
}

// Same strategy, different codec — no extra strategy code needed.
@Test func contactRoundTripsPlist() async throws {
  let e = PropertyListEncoder()
  let d = PropertyListDecoder()
  try await forAll(contactStrategy) { contact in
    #expect(try d.decode(Contact.self, from: e.encode(contact)) == contact)
  }
}
