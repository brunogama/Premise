# Changelog

## v1.0.0 - 2026-06-04

### Added

- Added async property execution for core runner APIs and test adapters.
- Added replay classification for new vs known failures.
- Added JSON failure trace export for CI artifacts.
- Added committed replay corpus support through composite example databases.
- Added `suchThat`, sized generation, convenience recursive generation, and
  tuple shrink support.
- Added exact/min/max collection generators with stronger shrinking.
- Added floating-point edge-case generation including NaN, infinities,
  denormals, and epsilon-near values.
- Added vector and index workflow strategies for dense vectors, sparse vectors,
  quantized values, dimensions, and index operations.
- Added operation-sequence model testing primitives.

### Changed

- Requires Swift 6.2 or newer.
- The default manifest is macro-free and does not download macro binaries or
  resolve `swift-syntax`.
- `PremiseMacros` is an explicit opt-in product for source or binary macro
  validation.
- CI builds with warnings as errors and complete strict-concurrency checking.

### Fixed

- Fixed manifest argument ordering so SwiftPM can parse the package.
- Fixed strict-build issues in replay execution, parallel execution, UUID
  strategy formatting, and `Int8` generation.
