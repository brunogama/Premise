import ConjectureCore

/// Actor that accumulates coverage observations and scores new inputs
/// using a pluggable ``CoverageGuide``.
///
/// ``CoverageTracker`` owns the cumulative coverage baseline and provides
/// a thread-safe interface for recording coverage snapshots from concurrent
/// property runs. It is a sidecar component that does not affect replay
/// semantics or trace content.
public actor CoverageTracker {
    /// The cumulative coverage map across all evaluated inputs.
    private var baseline: CoverageMap

    /// The guide used to score individual snapshots.
    private let guide: any CoverageGuide

    /// The number of inputs evaluated so far.
    private var evaluatedCount: Int = 0

    /// Creates a coverage tracker with the given guide and initial map capacity.
    ///
    /// - Parameters:
    ///   - guide: The scoring strategy for evaluating coverage snapshots.
    ///   - capacity: The number of edge slots for the cumulative baseline map.
    public init(guide: some CoverageGuide, capacity: Int = 1024) {
        self.guide = guide
        self.baseline = CoverageMap(capacity: capacity)
    }

    /// Records a coverage snapshot and returns its interestingness score.
    ///
    /// The snapshot is scored against the current cumulative baseline, then
    /// merged into the baseline so future scores reflect the updated state.
    ///
    /// - Parameters:
    ///   - snapshot: The coverage map from a single property execution.
    ///   - trace: The choice trace that produced this execution.
    /// - Returns: The coverage score for this input.
    @discardableResult
    public func record(
        snapshot: CoverageMap,
        trace: ChoiceTrace
    ) -> CoverageScore {
        let result = guide.score(
            snapshot: snapshot,
            baseline: baseline,
            trace: trace
        )
        baseline.merge(snapshot)
        evaluatedCount += 1
        return result
    }

    /// The total number of distinct edges observed across all scored inputs.
    public var totalEdgesSeen: Int {
        baseline.observedEdgeCount
    }

    /// The number of inputs that have been evaluated.
    public var inputsEvaluated: Int {
        evaluatedCount
    }

    /// Returns a copy of the current cumulative baseline.
    public var currentBaseline: CoverageMap {
        baseline
    }

    /// Resets the tracker to its initial empty state.
    public func reset() {
        baseline.reset()
        evaluatedCount = 0
    }
}
