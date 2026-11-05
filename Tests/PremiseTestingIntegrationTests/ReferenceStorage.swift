actor ReferenceStorage {
  private var values: [Int] = []

  func append(_ value: Int) {
    values.append(value)
  }

  func count() -> Int {
    values.count
  }
}
