import Foundation
import PremiseCore
// MARK: - Date, time, timezone, and calendar strategies

public extension Strategy where Value == TimeZone {
  static func timeZones(
    identifiers: [String] = TimeZone.knownTimeZoneIdentifiers
  ) -> Strategy<TimeZone> {
    let valid = identifiers.compactMap(TimeZone.init(identifier:))
    precondition(
      !valid.isEmpty,
      "timeZones requires at least one valid identifier"
    )
    return Strategy<TimeZone>(
      label: "timeZones",
      draw: { data in valid[data.drawInteger(in: 0...(valid.count - 1))] },
      shrink: { zone in
        guard zone.identifier != "UTC" else { return [] }
        guard let utc = TimeZone(secondsFromGMT: 0) else {
          preconditionFailure("UTC time zone unavailable")
        }
        return [utc]
      }
    )
  }
}

public extension Strategy where Value == Calendar.Identifier {
  static var calendarIdentifiers: Strategy<Calendar.Identifier> {
    .elements(of: [
      .gregorian, .iso8601, .buddhist, .hebrew, .islamic, .japanese,
    ])
  }
}

public extension Strategy where Value == DateComponents {
  static func dateTimes(
    years: ClosedRange<Int> = 1970...2099,
    timeZones: Strategy<TimeZone> = .timeZones()
  ) -> Strategy<DateComponents> {
    Strategy<DateComponents>(
      label: "dateTimes(years: \(years))",
      draw: { data in
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = try timeZones.draw(&data)
        components.year = data.drawInteger(in: years)
        components.month = data.drawInteger(in: 1...12)
        components.day = data.drawInteger(in: 1...28)
        components.hour = data.drawInteger(in: 0...23)
        components.minute = data.drawInteger(in: 0...59)
        components.second = data.drawInteger(in: 0...59)
        return components
      },
      shrink: { value in shrinkDateTime(value, years: years) }
    )
  }
}

public extension Strategy where Value == Double {
  /// Generates `TimeInterval`/duration values in seconds.
  static func timeIntervals(
    in range: ClosedRange<TimeInterval>
  ) -> Strategy<TimeInterval> {
    Strategy<Double>.floats(in: range)
  }
}

public extension Strategy where Value == Duration {
  /// Generates Swift `Duration` values in whole seconds.
  static func durations(
    seconds range: ClosedRange<Int64>
  ) -> Strategy<Duration> {
    Strategy<Duration>(
      label: "durations(seconds: \(range))",
      draw: { data in
        .seconds(try Strategy<Int64>.integers(in: range).draw(&data))
      },
      shrink: { value in value == .zero ? [] : [.zero] }
    )
  }
}

// MARK: - UUID strategies

public extension Strategy where Value == UUID {
  /// The nil UUID (`00000000-0000-0000-0000-000000000000`).
  static var nilUUID: Strategy<UUID> {
    .just(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
  }

  /// Generates RFC 4122 version-4 UUIDs, optionally including nil UUIDs.
  static func version4(includeNil: Bool = false) -> Strategy<UUID> {
    includeNil ? .oneOf([.nilUUID, .any]) : .any
  }
}

private func shrinkDateTime(
  _ value: DateComponents,
  years: ClosedRange<Int>
) -> [DateComponents] {
  var epoch = DateComponents()
  epoch.calendar = Calendar(identifier: .gregorian)
  epoch.timeZone = TimeZone(secondsFromGMT: 0)
  epoch.year = max(years.lowerBound, 1970)
  epoch.month = 1
  epoch.day = 1
  epoch.hour = 0
  epoch.minute = 0
  epoch.second = 0
  return value == epoch ? [] : [epoch]
}
