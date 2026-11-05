import Testing
import PremiseTesting
import PremiseStrategies

// The function under test.
func mySort(_ array: [Int]) -> [Int] {
  array.sorted()
}

// Strategy: integer arrays of 0 to 30 elements, each in -500...500.
let intArrays = Strategy<[Int]>.arrays(
  of: .integers(in: -500...500),
  length: 0...30
)
