import PremiseCore
import PremiseSMT
import Testing

@Suite("SMT Provider Opt-In Tests")
struct SMTProviderOptInTests {
  @Test("Z3Availability reports compile-time status")
  func compileTimeAvailability() {
    // Without the SMT trait, this should be false.
    // With the SMT trait, this should be true.
    // Either way the query itself must not crash.
    let enabled = Z3Availability.isCompileTimeEnabled
    #if PREMISE_SMT
    #expect(enabled == true)
    #else
    #expect(enabled == false)
    #endif
  }

  @Test("Z3VersionPolicy validates minimum version correctly")
  func versionPolicyMinimum() {
    let good = Z3VersionPolicy(major: 4, minor: 15, patch: 0)
    #expect(good.meetsMinimum)

    let exact = Z3VersionPolicy(
      major: Z3VersionPolicy.minimumMajor,
      minor: Z3VersionPolicy.minimumMinor,
      patch: Z3VersionPolicy.minimumPatch
    )
    #expect(exact.meetsMinimum)

    let tooOld = Z3VersionPolicy(major: 3, minor: 99, patch: 99)
    #expect(!tooOld.meetsMinimum)

    let minorTooLow = Z3VersionPolicy(major: 4, minor: 11, patch: 99)
    #expect(!minorTooLow.meetsMinimum)
  }

  @Test("Z3VersionPolicy version string formatting")
  func versionString() {
    let policy = Z3VersionPolicy(major: 4, minor: 15, patch: 4)
    #expect(policy.versionString == "4.15.4")
  }

  @Test("Z3VersionPolicy equality")
  func versionEquality() {
    let a = Z3VersionPolicy(major: 4, minor: 15, patch: 0)
    let b = Z3VersionPolicy(major: 4, minor: 15, patch: 0)
    let c = Z3VersionPolicy(major: 4, minor: 16, patch: 0)
    #expect(a == b)
    #expect(a != c)
  }

  @Test("SMTProvider conforms to PrimitiveProvider and draws bits")
  func smtProviderDrawBits() {
    var provider = SMTProvider(seed: 42)
    let value = provider.drawBits(count: 8)
    // Must produce a value without crashing
    #expect(value <= 255)
    #expect(!provider.isExhausted)
  }

  @Test("SMTProvider draws bytes deterministically")
  func smtProviderDrawBytes() {
    var provider1 = SMTProvider(seed: 123)
    var provider2 = SMTProvider(seed: 123)
    let bytes1 = provider1.drawBytes(count: 4)
    let bytes2 = provider2.drawBytes(count: 4)
    #expect(bytes1 == bytes2)
    #expect(bytes1.count == 4)
  }

  @Test("SMTProvider exhaustion tracking")
  func smtProviderExhaustion() {
    var provider = SMTProvider(seed: 0)
    #expect(!provider.isExhausted)
    provider.markExhausted()
    #expect(provider.isExhausted)
  }

  @Test("PremiseSMTModule namespace marker")
  func moduleMarker() {
    #expect(PremiseSMTModule.name == "PremiseSMT")
  }
}
