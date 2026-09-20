import Foundation

/// A yes/no probability returned by Jev, without an invented confidence statistic.
public struct NoulResult: Sendable, Equatable {
    /// Probability that the answer is yes, between zero and one.
    public let probability: Double
    /// A local Boolean policy: yes at probability 0.5 or above.
    public var value: Bool { probability >= 0.5 }
    /// Locally derived probability of no.
    public var noProbability: Double { 1 - probability }
    /// Applies your decision threshold, rejecting non-finite or out-of-range thresholds.
    public func value(threshold: Double) throws -> Bool {
        try validateThreshold(threshold)
        return probability >= threshold
    }
}

/// An option selected by Jev, retaining both confidence and its full distribution.
public struct ChoiceResult<Option: Hashable & Sendable>: Sendable {
    /// The selected option.
    public let value: Option
    /// Server-provided confidence; not necessarily the winning probability.
    public let confidence: Double
    /// A probability for every option, including unselected options.
    public let probabilities: [Option: Double]
    /// Tests a validated confidence threshold.
    public func isConfident(threshold: Double) throws -> Bool {
        try validateThreshold(threshold)
        return confidence >= threshold
    }
    /// Returns the choice only when the server confidence reaches your threshold.
    public func value(ifConfidenceAtLeast threshold: Double) throws -> Option? {
        try isConfident(threshold: threshold) ? value : nil
    }
}
extension ChoiceResult: Equatable where Option: Equatable {}

/// A fractional position on an ordered rubric, preserving the level distribution.
public struct ScoreResult: Sendable, Equatable {
    /// The server-provided fractional level index, from zero to the final level.
    public let value: Double
    /// Server-provided concentration of the probability distribution.
    public let confidence: Double
    /// Probability for each zero-based rubric level.
    public let probabilities: [Int: Double]
    /// Server-provided descriptions, including structured JSON descriptions.
    public let legend: [Int: JevValue]
    /// Tests a validated confidence threshold.
    public func isConfident(threshold: Double) throws -> Bool {
        try validateThreshold(threshold)
        return confidence >= threshold
    }
    /// Returns the fractional level only when confidence reaches your threshold.
    public func value(ifConfidenceAtLeast threshold: Double) throws -> Double? {
        try isConfident(threshold: threshold) ? value : nil
    }
    /// Linearly maps the level index onto a local scale; nothing is sent to Jev.
    /// Use this when a UI needs a percentage. It does not turn the score into a probability.
    public func scaled(to range: ClosedRange<Double>) throws -> Double {
        try scaled(minimum: range.lowerBound, maximum: range.upperBound)
    }
    /// Maps onto finite increasing bounds; also permits validating bounds from user input.
    public func scaled(minimum: Double, maximum: Double) throws -> Double {
        guard minimum.isFinite, maximum.isFinite, minimum < maximum, (maximum - minimum).isFinite,
              let top = probabilities.keys.max(), top > 0 else {
            throw JevError.invalidRequest("Score scale must have finite, increasing bounds.")
        }
        return minimum + (value / Double(top)) * (maximum - minimum)
    }
}

func validateThreshold(_ value: Double) throws {
    guard value.isFinite, (0...1).contains(value) else {
        throw JevError.invalidRequest("Probability thresholds must be finite and between zero and one.")
    }
}
