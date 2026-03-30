#if CONJECTURE_SMT
import CZ3

/// RAII-style wrapper around a Z3 context and solver pair.
///
/// Each `Z3Context` owns an isolated Z3 context and solver with
/// explicit reference counting. Contexts are not shared across
/// tasks — create one per worker or per property check.
///
/// - Important: `Z3Context` is `@unchecked Sendable` because the
///   underlying Z3 context is not thread-safe. Callers must ensure
///   single-threaded access per instance (e.g., actor isolation or
///   task-local ownership).
public final class Z3Context: @unchecked Sendable {
    private let context: Z3_context
    private let solver: Z3_solver

    /// Creates a new Z3 context with default configuration.
    ///
    /// - Parameter versionPolicy: Optional version policy to validate
    ///   the runtime Z3 version. If the runtime version does not meet
    ///   the policy minimum, initialization returns `nil`.
    public init?(versionPolicy: Z3VersionPolicy? = nil) {
        if let policy = versionPolicy, !policy.meetsMinimum {
            return nil
        }

        let config = Z3_mk_config()
        defer { Z3_del_config(config) }

        guard let ctx = Z3_mk_context(config) else {
            return nil
        }
        self.context = ctx

        let slv = Z3_mk_solver(ctx)
        Z3_solver_inc_ref(ctx, slv)
        self.solver = slv
    }

    deinit {
        Z3_solver_dec_ref(context, solver)
        Z3_del_context(context)
    }

    /// Checks satisfiability of the current solver assertions.
    ///
    /// - Returns: The check result (satisfiable, unsatisfiable, or unknown).
    public func check() -> Z3CheckResult {
        let result = Z3_solver_check(context, solver)
        switch result {
        case Z3_L_TRUE:
            return .satisfiable

        case Z3_L_FALSE:
            return .unsatisfiable

        default:
            return .unknown
        }
    }

    /// Resets the solver, removing all assertions.
    public func reset() {
        Z3_solver_reset(context, solver)
    }

    /// Creates an integer constant with the given name.
    ///
    /// - Parameter name: The symbol name for the constant.
    /// - Returns: A Z3 AST representing the integer constant.
    public func makeIntConstant(named name: String) -> Z3_ast {
        let symbol = Z3_mk_string_symbol(context, name)
        let intSort = Z3_mk_int_sort(context)
        return Z3_mk_const(context, symbol, intSort)
    }

    /// Creates a boolean constant with the given name.
    ///
    /// - Parameter name: The symbol name for the constant.
    /// - Returns: A Z3 AST representing the boolean constant.
    public func makeBoolConstant(named name: String) -> Z3_ast {
        let symbol = Z3_mk_string_symbol(context, name)
        let boolSort = Z3_mk_bool_sort(context)
        return Z3_mk_const(context, symbol, boolSort)
    }

    /// Creates an integer literal.
    ///
    /// - Parameter value: The integer value.
    /// - Returns: A Z3 AST representing the integer.
    public func makeInt(_ value: Int) -> Z3_ast {
        let intSort = Z3_mk_int_sort(context)
        return Z3_mk_int64(context, Int64(value), intSort)
    }

    /// Asserts that a constraint holds in the solver.
    ///
    /// - Parameter constraint: The Z3 AST constraint to assert.
    public func assert(_ constraint: Z3_ast) {
        Z3_solver_assert(context, solver, constraint)
    }

    /// Creates a less-than constraint between two arithmetic expressions.
    public func makeLessThan(_ lhs: Z3_ast, _ rhs: Z3_ast) -> Z3_ast {
        Z3_mk_lt(context, lhs, rhs)
    }

    /// Creates a greater-than constraint between two arithmetic expressions.
    public func makeGreaterThan(_ lhs: Z3_ast, _ rhs: Z3_ast) -> Z3_ast {
        Z3_mk_gt(context, lhs, rhs)
    }

    /// Creates an equality constraint between two expressions.
    public func makeEqual(_ lhs: Z3_ast, _ rhs: Z3_ast) -> Z3_ast {
        Z3_mk_eq(context, lhs, rhs)
    }

    /// Creates a logical AND of constraints.
    public func makeAnd(_ constraints: [Z3_ast]) -> Z3_ast {
        constraints.withUnsafeBufferPointer { buffer in
            Z3_mk_and(context, UInt32(buffer.count), buffer.baseAddress)
        }
    }

    /// Extracts an integer value from the model after a satisfiable check.
    ///
    /// - Parameter ast: The AST to evaluate in the current model.
    /// - Returns: The integer value if extraction succeeds, `nil` otherwise.
    public func extractInt(from ast: Z3_ast) -> Int? {
        guard let model = Z3_solver_get_model(context, solver) else {
            return nil
        }
        Z3_model_inc_ref(context, model)
        defer { Z3_model_dec_ref(context, model) }

        var evaluated: Z3_ast?
        guard Z3_model_eval(context, model, ast, true, &evaluated) else {
            return nil
        }
        guard let evaluatedAST = evaluated else {
            return nil
        }

        var result: Int64 = 0
        guard Z3_get_numeral_int64(context, evaluatedAST, &result) else {
            return nil
        }
        return Int(result)
    }
}

/// Result of a Z3 satisfiability check.
public enum Z3CheckResult: Sendable, Equatable {
    /// The assertions are satisfiable (a model exists).
    case satisfiable
    /// The assertions are unsatisfiable (no model exists).
    case unsatisfiable
    /// The solver could not determine satisfiability.
    case unknown
}

#endif  // CONJECTURE_SMT
