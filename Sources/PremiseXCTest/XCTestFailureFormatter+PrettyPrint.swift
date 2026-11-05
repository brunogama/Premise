extension XCTestFailureFormatter {
  static func prettyPrint(_ value: some Any) -> String {
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle == .struct || mirror.displayStyle == .class,
      !mirror.children.isEmpty,
      mirror.children.first?.label != nil
    {
      let fields = mirror.children.map { child in
        let label = child.label ?? "_"
        return "  \(label): \(child.value)"
      }
      let typeName = String(describing: type(of: value))
      return "\(typeName)(\n\(fields.joined(separator: "\n"))\n)"
    }

    return String(describing: value)
  }
}
