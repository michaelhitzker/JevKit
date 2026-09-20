/// A string-backed enumeration usable as a strongly typed Choice.
public protocol JevChoice: RawRepresentable, CaseIterable, Hashable, Sendable where RawValue == String {
    /// Optional rubric text/structure for this option; defaults to no additional description.
    var jevDescription: JevValue { get }
}
extension JevChoice {
    /// Defaults to JSON null, so the model uses the case's raw name.
    public var jevDescription: JevValue { .null }
}

/// A typed question descriptor that reads its result from a validated response.
public protocol JevField: Sendable {
    /// The value returned by this question.
    associatedtype Result: Sendable
    /// The underlying runtime question, suitable for batching or dynamic arrays.
    var question: JevQuestion { get }
    /// Extracts the typed result or throws for missing/incompatible answers.
    func read(from response: JevResponse) throws -> Result
}

/// An immutable typed yes/no question. No macros or runtime reflection are required.
public struct Noul: JevField {
    /// The runtime question.
    public let question: JevQuestion
    /// Defines a question with a stable ID and optional descriptions of yes and no.
    public init(_ instructions: JevValue, id: JevQuestionID, yes: JevValue? = nil, no: JevValue? = nil) {
        question = .noul(id: id, question: instructions, yes: yes, no: no)
    }
    /// Reads the yes/no probability.
    public func read(from response: JevResponse) throws -> NoulResult { try response.noul(question.id) }
}

/// An immutable question whose options come from a string-backed Swift enum.
public struct Choice<Option: JevChoice>: JevField {
    /// The runtime question containing all enum cases.
    public let question: JevQuestion
    /// Defines a choice, using each case's `jevDescription` as its rubric.
    public init(_ instructions: JevValue, id: JevQuestionID) {
        var criteria: [String: JevValue] = [:]
        for option in Option.allCases { criteria[option.rawValue] = option.jevDescription }
        question = .choice(id: id, question: instructions, criteria: criteria)
    }
    /// Reads the enum-valued answer, preserving every probability.
    public func read(from response: JevResponse) throws -> ChoiceResult<Option> { try response.choice(question.id, as: Option.self) }
}

/// An immutable question using an explicit, ordered descriptive rubric.
public struct Score: JevField {
    /// The runtime rubric question.
    public let question: JevQuestion
    /// Defines 2–10 levels; level indices are implicit and start at zero.
    public init(_ instructions: JevValue, id: JevQuestionID, levels: [JevValue]) {
        question = .score(id: id, question: instructions, levels: levels)
    }
    /// Reads a fractional score with confidence, probabilities, and legend.
    public func read(from response: JevResponse) throws -> ScoreResult { try response.score(question.id) }
}

/// An explicit typed assessment. A future optional macro can synthesize this same contract.
public protocol JevSchema: Sendable {
    /// Questions that will be evaluated together against one state.
    static var questions: [JevQuestion] { get }
    /// Constructs an assessment from validated answers. Keep deterministic business policy outside this initializer.
    init(response: JevResponse) throws
}

extension JevClient {
    /// Evaluates plain text and constructs a strongly typed assessment.
    public func evaluate<Schema: JevSchema>(state: String, as type: Schema.Type) async throws -> Schema {
        try await evaluate(state: .string(state), as: type)
    }
    /// Evaluates structured state and constructs a strongly typed assessment.
    public func evaluate<Schema: JevSchema>(state: JevValue, as type: Schema.Type) async throws -> Schema {
        let response = try await evaluate(state: state, questions: Schema.questions)
        return try Schema(response: response)
    }
}
