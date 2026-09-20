import Foundation

/// One of the three documented answer types.
public enum JevAnswer: Sendable {
    /// A yes/no probability.
    case noul(NoulResult)
    /// A selected string option and its distribution.
    case choice(ChoiceResult<String>)
    /// A fractional rubric position and its distribution.
    case score(ScoreResult)
}

/// Token counts supplied by the server. Missing counts remain nil, not zero.
public struct JevUsage: Sendable, Equatable {
    /// Number of input tokens, if supplied.
    public let inputTokens: Int?
    /// Number of output tokens, if supplied.
    public let outputTokens: Int?
}

/// Documented server metadata and measurements made by this client.
public struct JevMetadata: Sendable {
    /// Exact model string reported by the server; may be an alias.
    public let model: String
    /// Documented server token counts.
    public let usage: JevUsage
    /// Local elapsed time covering all attempts, backoff, and decoding.
    public let latency: Duration
    /// Number of HTTP attempts, including the first attempt.
    public let attempts: Int
}

/// A validated set of answers correlated with the original question IDs.
public struct JevResponse: Sendable {
    /// All answers; no distributions are discarded.
    public let answers: [JevQuestionID: JevAnswer]
    /// Model, token usage, and local request measurements.
    public let metadata: JevMetadata

    /// Retrieves a Noul answer or throws a type/missing-answer error.
    public func noul(_ id: JevQuestionID) throws -> NoulResult {
        guard case .noul(let result) = answers[id] else { throw JevError.invalidResponse("Expected a Noul answer.") }
        return result
    }
    /// Retrieves a Choice answer with string-valued options.
    public func choice(_ id: JevQuestionID) throws -> ChoiceResult<String> {
        guard case .choice(let result) = answers[id] else { throw JevError.invalidResponse("Expected a Choice answer.") }
        return result
    }
    /// Converts every option into your enum, rejecting unknown cases rather than dropping them.
    public func choice<Option: JevChoice>(_ id: JevQuestionID, as type: Option.Type) throws -> ChoiceResult<Option> {
        let raw = try choice(id)
        guard let value = Option(rawValue: raw.value) else { throw JevError.invalidResponse("Unknown typed choice.") }
        var probabilities: [Option: Double] = [:]
        for (key, probability) in raw.probabilities {
            guard let option = Option(rawValue: key) else { throw JevError.invalidResponse("Unknown typed choice option.") }
            probabilities[option] = probability
        }
        return ChoiceResult(value: value, confidence: raw.confidence, probabilities: probabilities)
    }
    /// Retrieves a Score answer or throws a type/missing-answer error.
    public func score(_ id: JevQuestionID) throws -> ScoreResult {
        guard case .score(let result) = answers[id] else { throw JevError.invalidResponse("Expected a Score answer.") }
        return result
    }
    /// Reads a typed descriptor from this response.
    public func answer<Field: JevField>(_ field: Field) throws -> Field.Result { try field.read(from: self) }
}
