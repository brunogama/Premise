import PremiseCore
import PremiseStrategies

let safe = Array("abcdefghijklmnopqrstuvwxyz ")

let productStrategy = Strategy<Product>(
  label: "product",
  draw: { data in
    // Draw each field from the PremiseData primitives.
    let nameLength = data.drawInteger(in: 3...30)
    let name = String(
      (0..<nameLength).map { _ -> Character in
        Character(UnicodeScalar(UInt8(97 + data.drawInteger(in: 0...25))))
      }
    )
    let price = data.drawInteger(in: 0...99_99)  // 0 to $99.99
    let catIndex = data.drawInteger(in: 0...(Category.allCases.count - 1))
    let category = Category.allCases[catIndex]
    let stock = data.drawInteger(in: 0...1000)

    return Product(name: name, priceCents: price, category: category, stock: stock)
  }
)
