import Foundation
import JevKit

@main struct Smoke {
    @MainActor static func main() async throws {
        for example in Example.allCases {
            let model = ExampleModel()
            model.run(example)
            while model.running { try await Task.sleep(for: .milliseconds(20)) }
            precondition(model.status == nil, model.status ?? "")
            precondition(model.sections.count == (example == .assessment ? 4 : 1))
            precondition(model.metadata?.contains("offline-fixture") == true)
            print("Passed: \(example.rawValue)")
        }
        let model = ExampleModel()
        model.run(.assessment)
        model.cancel()
        try await Task.sleep(for: .milliseconds(500))
        precondition(model.sections.isEmpty && !model.running)
        model.threshold = 1
        model.run(.noul)
        while model.running { try await Task.sleep(for: .milliseconds(20)) }
        precondition(model.sections.first?.headline == "Do not label as bug")
        print("Passed: cancellation and threshold policy")
    }
}
