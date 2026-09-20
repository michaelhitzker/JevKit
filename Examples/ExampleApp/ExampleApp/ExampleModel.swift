import Foundation
import Observation
import JevKit

struct Probability: Identifiable {
    let id: String
    let value: Double
}

struct ResultSection: Identifiable {
    let id: String
    let headline: String
    let detail: String
    let probabilities: [Probability]
}

enum CredentialMode: String, CaseIterable, Identifiable {
    case direct = "Direct key", environment = "Environment", infoPlist = "Info.plist", plist = "JevSecrets.plist"
    var id: Self { self }
}

@MainActor @Observable
final class ExampleModel {
    var text = "Every production user sees a crash at launch after upgrading to version 4.2. The previous version worked."
    var live = false
    var credentialMode: CredentialMode = .environment
    var directKey = ""
    var environmentVariable = "JEV_API_KEY"
    var threshold = 0.9
    private(set) var sections: [ResultSection] = []
    private(set) var metadata: String?
    private(set) var status: String?
    private(set) var running = false
    private var task: Task<Void, Never>?
    private var generation = UUID()

    private func liveConfiguration() throws -> JevConfiguration {
        let source: JevAPIKeySource
        switch credentialMode {
        case .direct:
            return JevConfiguration(apiKey: directKey, timeout: .seconds(20), retryPolicy: .init(maximumRetries: 0))
        case .environment:
            source = .environment(environmentVariable)
        case .infoPlist:
            source = .infoPlist()
        case .plist:
            guard let url = Bundle.main.url(forResource: "JevSecrets", withExtension: "plist") else {
                throw JevError.invalidConfiguration("Add JevSecrets.plist to the example app resources with a JEV_API_KEY string entry.")
            }
            source = .plist(url: url)
        }
        return try JevConfiguration(apiKeySource: source, timeout: .seconds(20), retryPolicy: .init(maximumRetries: 0))
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        running = false
    }

    func run(_ example: Example) {
        cancel()
        let generation = generation
        let text = text
        let live = live
        let threshold = threshold
        sections = []
        metadata = nil
        status = nil
        running = true
        task = Task {
            defer { if self.generation == generation { running = false; task = nil } }
            do {
                let client: JevClient
                if live {
                    client = try JevClient(configuration: liveConfiguration())
                } else {
                    client = try JevClient(configuration: .init(apiKey: "offline-demo"), transport: DemoTransport(example: example))
                }
                var output: [ResultSection] = []
                let metadata: JevMetadata
                if example == .assessment {
                    let result = try await client.evaluate(state: JevValue(encoding: Issue(body: text)), as: Assessment.self)
                    output = [try noulSection(result.bugResult, threshold: threshold), try choiceSection(result.priority, threshold: threshold), try scoreSection(result.urgency)]
                    let escalate = result.priority.value == .critical && result.priority.confidence >= 0.95
                    output.append(.init(id: "Swift policy", headline: escalate ? "Escalate to incident review" : "Queue for triage", detail: "Requires critical priority and confidence ≥ 95%. This example takes no external action.", probabilities: []))
                    metadata = result.metadata
                } else {
                    let response = try await client.evaluate(state: text, questions: example.questions)
                    metadata = response.metadata
                    switch example {
                    case .noul: output = [try noulSection(response.answer(Assessment.bug), threshold: threshold)]
                    case .choice: output = [try choiceSection(response.answer(Assessment.priorityQuestion), threshold: threshold)]
                    case .score: output = [try scoreSection(response.answer(Assessment.urgencyQuestion))]
                    case .assessment: break
                    }
                }
                try Task.checkCancellation()
                guard self.generation == generation else { return }
                sections = output
                self.metadata = "\(live ? "Live" : "Fixed demo") · \(metadata.model) · \(metadata.latency)"
            } catch {
                guard self.generation == generation else { return }
                status = error is CancellationError ? "Cancelled." : String(describing: error)
            }
        }
    }

    private func noulSection(_ result: NoulResult, threshold: Double) throws -> ResultSection {
        .init(id: "Noul", headline: try result.value(threshold: threshold) ? "Label as bug" : "Do not label as bug",
              detail: "Local yes threshold: \(threshold.formatted(.percent)). Noul has no separate confidence statistic.",
              probabilities: [.init(id: "Yes", value: result.probability), .init(id: "No", value: result.noProbability)])
    }

    private func choiceSection(_ result: ChoiceResult<Priority>, threshold: Double) throws -> ResultSection {
        let trusted = try result.value(ifConfidenceAtLeast: threshold)
        return .init(id: "Choice", headline: result.value.rawValue.capitalized,
                     detail: "Confidence: \(result.confidence.formatted(.percent)). \(trusted == nil ? "Request confirmation." : "Meets the selected confidence threshold.") Confidence is distinct from the selected option’s probability.",
                     probabilities: Priority.allCases.map { .init(id: $0.rawValue.capitalized, value: result.probabilities[$0] ?? 0) })
    }

    private func scoreSection(_ result: ScoreResult) throws -> ResultSection {
        .init(id: "Score", headline: "\(result.value.formatted()) / 2",
              detail: "Scaled: \(try result.scaled(to: 0...100).formatted()) / 100 (not a probability). Confidence: \(result.confidence.formatted(.percent)).",
              probabilities: result.probabilities.keys.sorted().map {
                  let label: String
                  if case .string(let text) = result.legend[$0] { label = text }
                  else { label = "Rubric level \($0)" }
                  return .init(id: "Level \($0): \(label)", value: result.probabilities[$0] ?? 0)
              })
    }
}
