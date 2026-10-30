# Why Property-Based Testing

Example-based tests tell you that your code works for a few inputs you thought of. Property-based tests tell you it works for *all* inputs you could ever think of — and many you couldn't.

## The Problem with Hand-Written Examples

Imagine you're testing a function that reverses an array:

```swift
func reversed<T>(_ array: [T]) -> [T] { array.reversed() }
```

A typical unit test looks like this:

```swift
@Test func reversedWorksForIntegers() {
    #expect(reversed([1, 2, 3]) == [3, 2, 1])
}

@Test func reversedWorksForEmpty() {
    #expect(reversed([Int]()) == [])
}

@Test func reversedWorksSingleElement() {
    #expect(reversed([42]) == [42])
}
```

These tests pass. But do they give you confidence? You tested three shapes out of the infinite space of possible integer arrays. The inputs you chose reflect what *you* thought to check, which is exactly the blind spot you need to catch bugs in.

Consider this subtly broken implementation:

```swift
func reversed<T>(_ array: [T]) -> [T] {
    guard array.count > 1 else { return array }
    // Oops: drops the last element on even-length arrays
    var result = array
    if result.count % 2 == 0 { result.removeLast() }
    return result.reversed()
}
```

All three hand-written tests still pass. A property test finds it in milliseconds.

## Properties: Universal Statements

A *property* is a statement that must be true for **any** valid input:

> "Reversing an array twice gives back the original array."

In Premise:

```swift
@Test func reversingTwiceIsIdentity() async throws {
    try await forAll(.arrays(of: .integers(in: 0...100), length: 0...50)) { array in
        #expect(reversed(reversed(array)) == array)
    }
}
```

The engine generates hundreds of random arrays and verifies the property holds for each one. When it finds the broken implementation above, it immediately shrinks the failing input to its minimal form — probably `[0, 0]` or `[0, 1]` — so you see the simplest case that demonstrates the bug.

## What Kinds of Properties Exist?

Good properties come in a few recognisable shapes:

### Round-trip / inverse pairs

```
encode(decode(x)) == x
parse(format(x)) == x
decompress(compress(x)) == x
```

These are the most powerful properties. If encoding and decoding cancel each other out for all inputs, your codec is correct by definition.

### Algebraic laws

Many operations obey mathematical laws you can state as properties:

```
// Commutativity
a + b == b + a

// Associativity
(a + b) + c == a + (b + c)

// Identity element
a + 0 == a
```

### Idempotence

Applying an operation twice produces the same result as applying it once:

```
sort(sort(x)) == sort(x)
deduplicate(deduplicate(x)) == deduplicate(x)
normalise(normalise(x)) == normalise(x)
```

### Model equivalence

You have a fast but complex implementation and a slow but obviously-correct reference implementation. They must produce the same output:

```swift
#expect(fastSearch(haystack, needle) == naiveSearch(haystack, needle))
```

### Precondition / postcondition pairs

The output satisfies a structural invariant you can check independently:

```
isSorted(sort(x))
isBalanced(tree.insert(value))
isValidEmail(validator.normalise(email))
```

## The Shrinking Advantage

When a property fails, Premise doesn't just report the first failing case it found — which might be a 500-element array with complex relationships between its values. It *shrinks* the failure: it systematically tries smaller and simpler inputs, keeping the ones that still fail, until it can't get any smaller.

The result is the *minimal counterexample*: the simplest possible input that demonstrates the bug. This is the key practical advantage of property-based testing over fuzzing. Fuzzing finds bugs; Premise finds bugs *and* hands you a readable reproduction case.

## When to Use Properties vs. Examples

Properties and examples are complementary, not mutually exclusive:

| Situation | Best approach |
|-----------|--------------|
| Algorithmic correctness (sort, encode, parse) | Property |
| Mathematical invariants (commutativity, identity) | Property |
| Specific known edge cases (empty, nil, overflow) | Example |
| Business rules tied to specific domain values | Example |
| Regression for a specific bug report | Example |
| Integration smoke tests | Example |

A good test suite uses both. The properties cover the space of inputs you can't enumerate; the examples pin down the edge cases you know matter.

## Next Steps

- Read <doc:HowTheEngineWorks> to understand how Premise generates and shrinks inputs.
- Try the <doc:Premise> tutorials to write your first property test.
- Browse <doc:StrategyCatalog> to see the built-in generators available.
