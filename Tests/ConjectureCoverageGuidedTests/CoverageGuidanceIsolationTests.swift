import ConjectureCore
import Testing

@testable import ConjectureCoverageGuided

@Suite("Coverage Guidance Isolation Tests")
struct CoverageGuidanceIsolationTests {
    @Test("EdgeCountGuide scores novel edges correctly")
    func edgeCountGuideScoresNovelEdges() {
        let guide = EdgeCountGuide()
        var baseline = CoverageMap(capacity: 64)
        baseline.recordEdge(1)

        var snapshot = CoverageMap(capacity: 64)
        snapshot.recordEdge(1)
        snapshot.recordEdge(5)
        snapshot.recordEdge(9)

        let trace = ChoiceTrace()
        let score = guide.score(snapshot: snapshot, baseline: baseline, trace: trace)
        #expect(score.value == 2)
    }

    @Test("EdgeCountGuide scores zero when no novel edges")
    func edgeCountGuideScoresZeroForKnownEdges() {
        let guide = EdgeCountGuide()
        var baseline = CoverageMap(capacity: 64)
        baseline.recordEdge(1)
        baseline.recordEdge(5)

        var snapshot = CoverageMap(capacity: 64)
        snapshot.recordEdge(1)
        snapshot.recordEdge(5)

        let trace = ChoiceTrace()
        let score = guide.score(snapshot: snapshot, baseline: baseline, trace: trace)
        #expect(score == .zero)
    }

    @Test("CoverageScore zero is comparable")
    func coverageScoreComparable() {
        let low = CoverageScore(value: 0)
        let high = CoverageScore(value: 3)
        #expect(low < high)
        #expect(low == .zero)
    }

    @Test("CoverageScore clamps negative values to zero")
    func coverageScoreClamps() {
        let negative = CoverageScore(value: -5)
        #expect(negative == .zero)
        #expect(negative.value == 0)
    }

    @Test("CoverageTracker accumulates baseline across records")
    func trackerAccumulatesBaseline() async {
        let tracker = CoverageTracker(guide: EdgeCountGuide(), capacity: 64)
        let trace = ChoiceTrace()

        var snap1 = CoverageMap(capacity: 64)
        snap1.recordEdge(1)
        snap1.recordEdge(3)
        let score1 = await tracker.record(snapshot: snap1, trace: trace)
        #expect(score1.value == 2)

        var snap2 = CoverageMap(capacity: 64)
        snap2.recordEdge(3)
        snap2.recordEdge(5)
        let score2 = await tracker.record(snapshot: snap2, trace: trace)
        #expect(score2.value == 1)

        let total = await tracker.totalEdgesSeen
        #expect(total == 3)
        let count = await tracker.inputsEvaluated
        #expect(count == 2)
    }

    @Test("CoverageTracker reset clears state")
    func trackerResetClearsState() async {
        let tracker = CoverageTracker(guide: EdgeCountGuide(), capacity: 64)
        let trace = ChoiceTrace()

        var snap = CoverageMap(capacity: 64)
        snap.recordEdge(1)
        await tracker.record(snapshot: snap, trace: trace)

        let edgesBefore = await tracker.totalEdgesSeen
        #expect(edgesBefore == 1)

        await tracker.reset()
        let edgesAfter = await tracker.totalEdgesSeen
        #expect(edgesAfter == 0)
        let countAfter = await tracker.inputsEvaluated
        #expect(countAfter == 0)
    }

    @Test("Coverage guidance does not affect Runner replay semantics")
    func coverageDoesNotAffectReplaySemantics() async {
        // Run a property through the core Runner - coverage tracking
        // should be a completely separate concern with no back-edge.
        let strategy = Strategy<Int>(label: "testInt") { data in
            data.drawInteger(in: 0...100)
        }
        let config = PropertyConfig(maxRuns: 5, seed: 42)
        let runner = Runner(strategy: strategy, config: config)

        // Run the property
        let result = await runner.run { value in
            if value > 200 {
                throw TestPropertyError.failed
            }
        }

        // Separately track coverage - this is sidecar, not integrated
        let tracker = CoverageTracker(guide: EdgeCountGuide(), capacity: 64)
        var snap = CoverageMap(capacity: 64)
        snap.recordEdge(10)
        await tracker.record(snapshot: snap, trace: ChoiceTrace())

        // The Runner result is completely independent of coverage tracking
        switch result {
        case .passed(let runs):
            #expect(runs == 5)

        case .failure:
            Issue.record("Expected property to pass")
        }

        // Coverage tracker state is independent
        let edges = await tracker.totalEdgesSeen
        #expect(edges == 1)
    }

    @Test("CoverageTracker with no records has zero state")
    func emptyTrackerHasZeroState() async {
        let tracker = CoverageTracker(guide: EdgeCountGuide(), capacity: 64)
        let edges = await tracker.totalEdgesSeen
        let count = await tracker.inputsEvaluated
        #expect(edges == 0)
        #expect(count == 0)
    }
}

private enum TestPropertyError: Error {
    case failed
}
