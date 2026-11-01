import Foundation
import PremiseCore
// MARK: - URL strategies

public extension Strategy where Value == URL {
  // Keep the published URL options source-compatible.
  // swiftlint:disable function_parameter_count
  /// Generates web URLs with optional ports, paths, and query items.
  static func web(
    schemes: [String] = ["http", "https"],
    allowPort: Bool = true,
    maxPathSegments: Int = 4,
    maxQueryItems: Int = 3
  ) -> Strategy<URL> {
    // swiftlint:enable function_parameter_count
    precondition(!schemes.isEmpty, "URL strategy requires at least one scheme")
    return Strategy<URL>(
      label: "url.web",
      draw: { data in
        var components = URLComponents()
        components.scheme =
          schemes[
            data.drawInteger(in: 0...(schemes.count - 1))
          ]
        components.host = try Strategy<String>.domainNames().draw(&data)
        if allowPort, data.drawBoolean() {
          components.port = data.drawInteger(in: 1...65_535)
        }
        components.path = drawWebPath(maxPathSegments, using: &data)
        let query = drawWebQuery(maxQueryItems, using: &data)
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? fallbackWebURL()
      },
      shrink: shrinkWebURL
    )
  }
}

private func fallbackWebURL() -> URL {
  guard let url = URL(string: "https://example.com") else {
    preconditionFailure("Invalid fallback URL")
  }
  return url
}

private func shrinkWebURL(_ value: URL) -> [URL] {
  value.absoluteString == "https://example.com" ? [] : [fallbackWebURL()]
}

private func drawWebPath(
  _ maximum: Int,
  using data: inout PremiseData
) -> String {
  let count = maximum <= 0 ? 0 : data.drawInteger(in: 0...maximum)
  guard count > 0 else { return "" }
  let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789-_")
  return (0..<count).map { _ in
    let length = data.drawInteger(in: 1...12)
    return String(
      (0..<length).map { _ in
        chars[data.drawInteger(in: 0...(chars.count - 1))]
      }
    )
  }.joined(separator: "/", prefix: "/")
}

private func drawWebQuery(
  _ maximum: Int,
  using data: inout PremiseData
) -> [URLQueryItem] {
  let count = maximum <= 0 ? 0 : data.drawInteger(in: 0...maximum)
  guard count > 0 else { return [] }
  return (0..<count).map { index in
    URLQueryItem(
      name: "q\(index)",
      value: String(data.drawInteger(in: 0...999))
    )
  }
}
private extension Sequence where Element == String {
  func joined(separator: String, prefix: String) -> String {
    let body = joined(separator: separator)
    return body.isEmpty ? "" : prefix + body
  }
}
