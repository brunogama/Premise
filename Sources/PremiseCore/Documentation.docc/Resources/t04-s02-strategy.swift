import Foundation
import Testing
import PremiseTesting
import PremiseStrategies

struct Contact: Codable, Equatable {
  var name: String
  var email: String
  var age: Int
}

let safe = Array("abcdefghijklmnopqrstuvwxyz0123456789")
let domains = ["example.com", "test.org", "mail.net"]

let contactStrategy: Strategy<Contact> = Strategy<String>
  .strings(from: safe, length: 2...20)
  .flatMap { name in
    Strategy<String>.strings(from: safe, length: 3...10)
      .flatMap { local in
        Strategy<Int>.integers(in: 0...120)
          .map { age in
            let domain = domains[abs(name.hashValue) % domains.count]
            return Contact(name: name, email: "\(local)@\(domain)", age: age)
          }
      }
  }
