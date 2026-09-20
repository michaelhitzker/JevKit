import Foundation
import Testing
@testable import JevKit

@Test func namedEnvironmentCredentialDoesNotFallBack() throws {
    let environment = ["TYPESAFE_API_KEY": "official-key", "JEV_API_KEY": "example-key", "CUSTOM_KEY": "custom-key"]
    #expect(try JevAPIKeySource.environment().resolve(environment: environment) == "official-key")
    #expect(try JevAPIKeySource.environment("JEV_API_KEY").resolve(environment: environment) == "example-key")
    #expect(try JevAPIKeySource.environment("CUSTOM_KEY").resolve(environment: environment) == "custom-key")
    #expect(throws: JevError.self) { try JevAPIKeySource.environment("MISSING").resolve(environment: environment) }
    #expect(throws: JevError.self) { try JevAPIKeySource.environment("").resolve(environment: environment) }
}

@Test(arguments: ["", " ", " leading", "trailing\n", "key\r\nInjected: header", "🔑", "$(MISSING_KEY)", "${MISSING_KEY}"])
func invalidEnvironmentCredentials(_ key: String) {
    #expect(throws: JevError.self) {
        try JevAPIKeySource.environment().resolve(environment: ["TYPESAFE_API_KEY": key])
    }
}

private func withTemporaryPlist(contents: Any, format: PropertyListSerialization.PropertyListFormat = .xml,
                                operation: (URL) async throws -> Void) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("Secrets.plist")
    try PropertyListSerialization.data(fromPropertyList: contents, format: format, options: 0).write(to: url)
    try await operation(url)
}

@Test(arguments: [PropertyListSerialization.PropertyListFormat.xml, .binary])
func plistCredentialReachesAuthorizationHeader(_ format: PropertyListSerialization.PropertyListFormat) async throws {
    try await withTemporaryPlist(contents: ["CUSTOM_KEY": "fixture-secret"], format: format) { url in
        let source = JevAPIKeySource.plist(url: url, key: "CUSTOM_KEY")
        let configuration = try JevConfiguration(apiKeySource: source, timeout: .seconds(7), model: "fixture", retryPolicy: .init(maximumRetries: 0))
        #expect(configuration.timeout == .seconds(7))
        #expect(configuration.model == "fixture")
        let transport = StubTransport([.http(200, noulFixture)])
        let client = try JevClient(configuration: configuration, transport: transport)
        // Initialization snapshots the credential; evaluation does not reread the file.
        try FileManager.default.removeItem(at: url)
        _ = try await client.evaluate(state: "Crash", questions: [bugQuestion])
        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-secret")
    }
}

@Test func defaultPlistKeyAndClientInitializer() async throws {
    try await withTemporaryPlist(contents: ["JEV_API_KEY": "fixture-secret"]) { url in
        _ = try JevClient(apiKeySource: .plist(url: url))
        #expect(try JevConfiguration(apiKeySource: .plist(url: url)).apiKey == "fixture-secret")
        _ = try JevClient(apiKey: "direct-secret")
    }
}

@Test func missingAndNonStringPlistValuesAreRejected() async throws {
    for contents: [String: Any] in [[:], ["JEV_API_KEY": 123], ["JEV_API_KEY": true], ["JEV_API_KEY": ["secret"]], ["JEV_API_KEY": ""], ["JEV_API_KEY": "$(SECRET)"]] {
        try await withTemporaryPlist(contents: contents) { url in
            #expect(throws: JevError.self) { try JevClient(apiKeySource: .plist(url: url)) }
        }
    }
    try await withTemporaryPlist(contents: ["not", "a", "dictionary"]) { url in
        #expect(throws: JevError.self) { try JevClient(apiKeySource: .plist(url: url)) }
    }
}

@Test func plistFailuresDoNotExposePathsOrContents() async throws {
    try await withTemporaryPlist(contents: [:]) { url in
        try Data("secret-invalid-plist".utf8).write(to: url)
        do {
            _ = try JevClient(apiKeySource: .plist(url: url))
            Issue.record("Expected invalid configuration")
        } catch let error as JevError {
            guard case .invalidConfiguration = error else { Issue.record("Wrong error category"); return }
            #expect(!error.description.contains("secret-invalid-plist"))
            #expect(!error.description.contains(url.path))
        }
        try FileManager.default.removeItem(at: url)
        #expect(throws: JevError.self) { try JevClient(apiKeySource: .plist(url: url)) }
    }
    let remote = try #require(URL(string: "https://example.com/secret.plist"))
    #expect(throws: JevError.self) { try JevClient(apiKeySource: .plist(url: remote)) }
}

@Test func infoPlistSupportsCustomBundlesAndKeys() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).bundle")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let contents = ["CFBundleIdentifier": "test.jev.credentials", "JEV_API_KEY": "default-secret", "CUSTOM_KEY": "custom-secret"]
    try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0)
        .write(to: directory.appendingPathComponent("Info.plist"))
    let bundle = try #require(Bundle(url: directory))
    #expect(try JevConfiguration(apiKeySource: .infoPlist(bundle: bundle)).apiKey == "default-secret")
    #expect(try JevConfiguration(apiKeySource: .infoPlist(key: "CUSTOM_KEY", bundle: bundle)).apiKey == "custom-secret")
    _ = try JevClient(apiKeySource: .infoPlist(bundle: bundle))
    #expect(throws: JevError.self) { try JevClient(apiKeySource: .infoPlist(key: "MISSING", bundle: bundle)) }
}

@Test func credentialSourcesRedactAssociatedValues() {
    let source = JevAPIKeySource.plist(url: URL(fileURLWithPath: "/private/secret-path"), key: "secret-name")
    var reflected = ""
    dump(source, to: &reflected)
    #expect(!String(describing: source).contains("secret-path"))
    #expect(!String(reflecting: source).contains("secret-name"))
    #expect(!reflected.contains("secret-path"))
    #expect(!reflected.contains("secret-name"))
}
