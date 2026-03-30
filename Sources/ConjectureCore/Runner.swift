public struct Runner<Value: Sendable>: Sendable {
    public let strategy: Strategy<Value>
    public let config: PropertyConfig
    public let propertyID: PropertyIdentity

    public init(
        strategy: Strategy<Value>,
        config: PropertyConfig = .default,
        propertyID: PropertyIdentity = PropertyIdentity(
            fileID: "unknown",
            line: 0,
            strategyLabel: "unknown"
        )
    ) {
        self.strategy = strategy
        self.config = config
        self.propertyID = propertyID
    }

    public func run(
        _ property: @Sendable (Value) throws -> Void,
        replayTraces: [ChoiceTrace] = []
    ) async -> RunResult<Value> {
        if config.replayEnabled {
            for trace in replayTraces {
                if let failure = run(trace: trace, property: property) {
                    return .failure(failure.record, value: failure.value)
                }
            }
        }

        let seed = config.seed ?? 0
        for index in 0..<config.maxRuns {
            let providerSeed = seed &+ UInt64(index)
            let provider = PseudoRandomProvider(seed: providerSeed, maxDraws: config.maxDrawsPerRun)
            if let failure = run(provider: provider, property: property) {
                return .failure(failure.record, value: failure.value)
            }
        }

        return .passed(runs: config.maxRuns)
    }

    public func replay(
        _ trace: ChoiceTrace,
        property: @Sendable (Value) throws -> Void
    ) -> Bool {
        run(trace: trace, property: property) != nil
    }

    private func run(
        trace: ChoiceTrace,
        property: @Sendable (Value) throws -> Void
    ) -> ExecutionFailure<Value>? {
        let provider = ReplayProvider(trace: trace)
        return run(provider: provider, property: property)
    }

    private func run(
        provider: some PrimitiveProvider,
        property: @Sendable (Value) throws -> Void
    ) -> ExecutionFailure<Value>? {
        var data = ConjectureData(provider: provider)
        var drawnValue: Value?
        do {
            let value = try strategy.draw(&data)
            drawnValue = value
            try property(value)
            return nil
        } catch {
            let record = FailureRecord(
                propertyID: propertyID,
                trace: data.snapshot(),
                errorMessage: String(describing: error),
                runCount: 1,
                shrinkCount: 0
            )
            guard let drawnValue else {
                return nil
            }
            return ExecutionFailure(record: record, value: drawnValue)
        }
    }
}

private struct ExecutionFailure<Value: Sendable> {
    let record: FailureRecord
    let value: Value
}
