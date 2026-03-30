import Testing
import PremiseTesting
import PremiseStrategies

enum Category: String, CaseIterable, Sendable {
  case electronics, clothing, food, books, sports
}

struct Product: Sendable {
  var name: String
  var priceCents: Int  // price in cents (0 = free)
  var category: Category
  var stock: Int  // units available

  var isFree: Bool { priceCents == 0 }
  var isOutOfStock: Bool { stock == 0 }

  func discountedPrice(percent: Int) -> Int {
    let discount = (priceCents * percent) / 100
    return max(0, priceCents - discount)
  }
}
