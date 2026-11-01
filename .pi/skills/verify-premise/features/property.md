# Consumer property

A SwiftPM consumer generates integers and checks a property through Swift Testing.

---
## Sub-features

- `property-swift-testing`: compile and run the consumer's property with two generated inputs.

---
## How to get to it (user POV)

- Add Premise's local package as a dependency and run `swift test` in the consumer package.

---
## Driving it with SwiftPM

Preconditions: complete Launch and Doctor in the parent skill. Run its Drive command. Require exit code 0 and an explicit passing result for `additionIsCommutative`; retain `$EVIDENCE/consumer-property.log`. This checks the consumer path, not a package-internal test.

---
## Gotchas

- The README's first-property example omits `import PremiseCore`, which is needed for `Strategy` in a separate consumer. Add the `PremiseCore` product as shown in Launch.
- If there are no discovered tests, the journey failed even if the process exits successfully.
