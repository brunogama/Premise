struct StateMachineBundleKey: Hashable, Sendable {
  private let token: StateMachineBundleToken

  init(token: StateMachineBundleToken) {
    self.token = token
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.token === rhs.token
  }

  func hash(into hasher: inout Hasher) {
    ObjectIdentifier(token).hash(into: &hasher)
  }
}
