#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
import Testing

@testable import PremiseDatabase

@Suite("SQLiteRuntimeGate")
struct SQLiteRuntimeGateTests {

  @Test("minimumSafeVersion equals 3_051_003")
  func minimumSafeVersionValue() {
    #expect(SQLiteRuntimeGate.minimumSafeVersion == 3_051_003)
  }

  @Test("safeBackports contains exactly the expected versions")
  func safeBackportsContents() {
    let backports = SQLiteRuntimeGate.safeBackports
    #expect(backports.count == 2)
    #expect(backports.contains(3_050_007))
    #expect(backports.contains(3_044_006))
  }

  @Test("isWALSafe returns a Bool consistent with the linked runtime")
  func isWALSafeSmoke() {
    let version = sqlite3_libversion_number()
    let result = SQLiteRuntimeGate.isWALSafe()

    let expectedSafe =
      version >= SQLiteRuntimeGate.minimumSafeVersion
      || SQLiteRuntimeGate.safeBackports.contains(version)
    #expect(result == expectedSafe)
  }

  @Test("assertWALSafeRuntime succeeds or throws based on runtime version")
  func assertWALSafeRuntimeBehavior() throws {
    let version = sqlite3_libversion_number()
    let expectedSafe =
      version >= SQLiteRuntimeGate.minimumSafeVersion
      || SQLiteRuntimeGate.safeBackports.contains(version)

    if expectedSafe {
      // Should not throw on a safe runtime.
      try SQLiteRuntimeGate.assertWALSafeRuntime()
    } else {
      // Should throw the specific error on an unsafe runtime.
      #expect(throws: SQLiteError.unsupportedWALRuntime(versionNumber: version)) {
        try SQLiteRuntimeGate.assertWALSafeRuntime()
      }
    }
  }
}
