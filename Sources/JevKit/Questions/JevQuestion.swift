import Foundation

/// A stable key correlating a question with its answer. Validated before sending.
public struct JevQuestionID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    /// The exact key transmitted in the questions map.
    public let rawValue: String
    /// Creates an ID; empty IDs are rejected at evaluation.
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Creates an ID from a string literal.
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    /// Decodes an ID as a JSON string.
    public init(from decoder: any Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    /// Encodes an ID as a JSON string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A dynamically constructed question. Arrays preserve duplicate IDs for validation.
public struct JevQuestion: Sendable {
    /// The key used to retrieve the answer.
    public let id: JevQuestionID
    let instructions: JevValue
    let kind: Kind
    enum Kind: Sendable {
        case noul(yes: JevValue?, no: JevValue?)
        case choice([String: JevValue])
        case score([JevValue])
    }

    /// Asks a yes/no question, optionally describing the two outcomes.
    public static func noul(id: JevQuestionID, question: JevValue, yes: JevValue? = nil, no: JevValue? = nil) -> Self {
        Self(id: id, instructions: question, kind: .noul(yes: yes, no: no))
    }
    /// Selects an option using a map of option names to descriptions (or `.null`).
    public static func choice(id: JevQuestionID, question: JevValue, criteria: [String: JevValue]) -> Self {
        Self(id: id, instructions: question, kind: .choice(criteria))
    }
    /// Selects an option with no additional descriptions. Duplicate options are rejected.
    public static func choice(id: JevQuestionID, question: JevValue, options: [String]) throws -> Self {
        guard Set(options).count == options.count else { throw JevError.invalidRequest("Duplicate choice options.") }
        return .choice(id: id, question: question, criteria: Dictionary(uniqueKeysWithValues: options.map { ($0, .null) }))
    }
    /// Rates state on 2–10 ordered descriptive levels, numbered from zero.
    public static func score(id: JevQuestionID, question: JevValue, levels: [JevValue]) -> Self {
        Self(id: id, instructions: question, kind: .score(levels))
    }

    func validate() throws {
        guard !id.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, instructions.isDescription else {
            throw JevError.invalidRequest("Question IDs and instructions must be nonempty text or structured descriptions.")
        }
        switch kind {
        case .noul(let yes, let no):
            guard [yes, no].compactMap({ $0 }).allSatisfy(\.isDescription) else {
                throw JevError.invalidRequest("Noul criteria must be nonempty descriptions.")
            }
        case .choice(let criteria):
            guard (2...255).contains(criteria.count), criteria.keys.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  criteria.values.allSatisfy({ $0 == .null || $0.isDescription }) else {
                throw JevError.invalidRequest("Choice requires 2–255 named options with descriptions or null.")
            }
        case .score(let levels):
            guard (2...10).contains(levels.count), levels.allSatisfy(\.isDescription) else {
                throw JevError.invalidRequest("Score requires 2–10 nonempty descriptive levels.")
            }
        }
    }
}
