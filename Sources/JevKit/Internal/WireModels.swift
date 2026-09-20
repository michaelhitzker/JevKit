import Foundation

// Early-access HTTP fields are confined here, away from the public DSL.
struct WireRequest: Encodable {
    let state: JevValue
    let model: String
    let questions: [String: WireQuestion]
}

struct WireQuestion: Encodable {
    let type: String
    let instructions: JevValue
    let criteria: JevValue?

    init(_ question: JevQuestion) {
        instructions = question.instructions
        switch question.kind {
        case .noul(let yes, let no):
            type = "noul"
            var values: [String: JevValue] = [:]
            if let yes { values["true"] = yes }
            if let no { values["false"] = no }
            criteria = values.isEmpty ? nil : .object(values)
        case .choice(let options): type = "choice"; criteria = .object(options)
        case .score(let levels): type = "score"; criteria = .array(levels)
        }
    }
}

struct WireResponse: Decodable {
    let model: String
    let answers: [String: WireAnswer]
    let usage: WireUsage
}
struct WireUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
}
struct WireAnswer: Decodable {
    let type: String
    let noul: Double?
    let choice: String?
    let score: Double?
    let confidence: Double?
    let probabilities: [String: Double]?
    let legend: [String: JevValue]?
}

extension WireResponse {
    func validated(questions: [JevQuestion]) throws -> [JevQuestionID: JevAnswer] {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (usage.input_tokens ?? 0) >= 0, (usage.output_tokens ?? 0) >= 0,
              Set(answers.keys) == Set(questions.map { $0.id.rawValue }) else {
            throw JevError.invalidResponse("Model, usage, or answer IDs do not match the contract.")
        }
        var results: [JevQuestionID: JevAnswer] = [:]
        for question in questions {
            guard let answer = answers[question.id.rawValue] else { throw JevError.invalidResponse("Missing answer.") }
            results[question.id] = try answer.validated(for: question)
        }
        return results
    }
}

extension WireAnswer {
    func validated(for question: JevQuestion) throws -> JevAnswer {
        switch question.kind {
        case .noul:
            guard type == "noul", let noul, isProbability(noul) else {
                throw JevError.invalidResponse("Invalid Noul answer or probability.")
            }
            return .noul(NoulResult(probability: noul))
        case .choice(let options):
            let distribution = try validatedDistribution(type: "choice", keys: Set(options.keys))
            guard let choice, let winner = distribution[choice],
                  winner >= (distribution.values.max() ?? 0) - 0.001, let confidence else {
                throw JevError.invalidResponse("Choice is not a highest-probability option.")
            }
            return .choice(ChoiceResult(value: choice, confidence: confidence, probabilities: distribution))
        case .score(let levels):
            let keys = Set(levels.indices.map(String.init))
            let distribution = try validatedDistribution(type: "score", keys: keys)
            guard let score, score.isFinite, (0...Double(levels.count - 1)).contains(score),
                  let confidence, let legend, Set(legend.keys) == keys, legend.values.allSatisfy(\.isDescription) else {
                throw JevError.invalidResponse("Invalid Score value or legend.")
            }
            // Keys have been checked against canonical integer strings; never silently discard a level.
            var typedProbabilities: [Int: Double] = [:]
            var typedLegend: [Int: JevValue] = [:]
            for index in levels.indices {
                typedProbabilities[index] = distribution[String(index)]
                typedLegend[index] = legend[String(index)]
            }
            return .score(ScoreResult(value: score, confidence: confidence, probabilities: typedProbabilities, legend: typedLegend))
        }
    }

    private func validatedDistribution(type expected: String, keys: Set<String>) throws -> [String: Double] {
        guard type == expected, let confidence, isProbability(confidence), let probabilities,
              Set(probabilities.keys) == keys, probabilities.values.allSatisfy(isProbability),
              abs(probabilities.values.reduce(0, +) - 1) <= 0.001 else {
            throw JevError.invalidResponse("Invalid answer type, confidence, or probability distribution.")
        }
        return probabilities
    }
}
private func isProbability(_ value: Double) -> Bool { value.isFinite && (0...1).contains(value) }
