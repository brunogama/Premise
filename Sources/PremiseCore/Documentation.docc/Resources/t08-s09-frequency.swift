import PremiseStrategies

// Payload sizes with weighted distribution:
// empty (5x), small (3x), medium (1x), large (1x)
// Bugs most often appear at boundaries — weight them heavily.
let payloadStrategy = Strategy<[UInt8]>.frequency([
  (5, .just([])),  // empty: most likely to cause bugs
  (3, .bytes(length: 1...64)),  // small payloads
  (1, .bytes(length: 65...1024)),  // medium payloads
  (1, .bytes(length: 1025...65536)),  // large payloads
])
