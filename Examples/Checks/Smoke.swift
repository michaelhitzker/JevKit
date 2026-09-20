import Foundation
import JevKit

@main struct Smoke {
    @MainActor static func main() async throws {
        let store = KeychainAPIKeyStore(service: "dev.jevkit.example.checks.\(UUID().uuidString)")
        defer { try? store.save("") }
        let savedSettings = ExampleSettings(keyStore: store)
        precondition(savedSettings.apiKey.isEmpty)
        savedSettings.apiKey = "test-key-one"
        precondition(savedSettings.persistenceError == nil)
        precondition(ExampleSettings(keyStore: store).apiKey == "test-key-one")
        savedSettings.apiKey = "test-key-two"
        precondition(ExampleSettings(keyStore: store).apiKey == "test-key-two")
        savedSettings.apiKey = "  \n "
        precondition(ExampleSettings(keyStore: store).apiKey.isEmpty)
        print("Passed: Keychain save, reload, replacement, and removal")

        let fixtureSettings = ExampleSettings(keyStore: MemoryKeyStore())
        fixtureSettings.apiKey = "test-only-key"
        for example in Example.allCases {
            let model = ExampleModel(settings: fixtureSettings, transport: FixtureTransport(example: example))
            model.run(example)
            while model.running { try await Task.sleep(for: .milliseconds(20)) }
            precondition(model.status == nil, model.status ?? "")
            precondition(model.sections.count == (example == .assessment ? 4 : 1))
            precondition(model.metadata?.contains("offline-fixture") == true)
            print("Passed: \(example.rawValue)")
        }
        let model = ExampleModel(settings: fixtureSettings, transport: FixtureTransport(example: .noul))
        model.run(.assessment)
        model.cancel()
        try await Task.sleep(for: .milliseconds(500))
        precondition(model.sections.isEmpty && !model.running)
        model.threshold = 1
        model.run(.noul)
        while model.running { try await Task.sleep(for: .milliseconds(20)) }
        precondition(model.sections.first?.headline == "Do not label as bug")
        print("Passed: cancellation and threshold policy")

        let settings = ExampleSettings(keyStore: MemoryKeyStore())
        let first = ExampleModel(settings: settings, transport: FixtureTransport(example: .noul))
        let second = ExampleModel(settings: settings, transport: FixtureTransport(example: .choice))
        for key in ["", "  \n  "] {
            settings.apiKey = key
            for model in [first, second] {
                model.run(.noul)
                precondition(model.needsAPIKey && model.status != nil)
                precondition(!model.running && model.sections.isEmpty)
            }
        }
        settings.apiKey = "test-only-key"
        second.run(.choice)
        settings.apiKey = ""
        while second.running { try await Task.sleep(for: .milliseconds(20)) }
        precondition(second.status == nil && !second.needsAPIKey)
        precondition(second.metadata?.contains("offline-fixture") == true)
        second.run(.choice)
        precondition(second.needsAPIKey && !second.running && second.sections.isEmpty)
        print("Passed: missing-key validation, shared key editing, and in-flight snapshot")
    }
}

private final class MemoryKeyStore: APIKeyStoring {
    var key = ""
    func load() throws -> String { key }
    func save(_ key: String) throws { self.key = key }
}
