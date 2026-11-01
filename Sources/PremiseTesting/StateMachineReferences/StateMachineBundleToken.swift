// Bundle keys compare this token by object identity.
// swiftlint:disable:next prefer_struct
final class StateMachineBundleToken: Sendable {
  let label: String

  init(label: String) {
    self.label = label
  }
}
