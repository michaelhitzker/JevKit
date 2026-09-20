import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Evaluates independent Jev questions asynchronously. Safe to share across concurrent tasks.
/// Network suspension permits other requests on this actor; no request state is shared.
public actor JevClient {
    private let configuration: JevConfiguration
    private let transport: any JevTransport
    private let logger: (any JevLogger)?
    private let sleep: @Sendable (Duration) async throws -> Void

    /// Creates a client for the official endpoint, validating credentials before any network activity.
    public init(apiKey: String) throws {
        let configuration = JevConfiguration(apiKey: apiKey)
        try configuration.validate()
        self.configuration = configuration
        self.transport = URLSessionTransport()
        self.logger = nil
        self.sleep = { try await Task.sleep(for: $0) }
    }

    /// Creates a configurable client with optional transport injection and privacy-safe observability.
    public init(configuration: JevConfiguration, transport: any JevTransport = URLSessionTransport(), logger: (any JevLogger)? = nil) throws {
        try configuration.validate()
        self.configuration = configuration
        self.transport = transport
        self.logger = logger
        self.sleep = { try await Task.sleep(for: $0) }
    }

    // Tests control time without adding a public clock abstraction to the SDK.
    init(configuration: JevConfiguration, transport: any JevTransport, logger: (any JevLogger)? = nil,
         sleep: @escaping @Sendable (Duration) async throws -> Void) throws {
        try configuration.validate()
        self.configuration = configuration
        self.transport = transport
        self.logger = logger
        self.sleep = sleep
    }

    /// Evaluates plain text and a runtime list of questions in one request.
    public func evaluate(state: String, questions: [JevQuestion]) async throws -> JevResponse {
        try await evaluate(state: .string(state), questions: questions)
    }

    /// Evaluates structured JSON state. Only nonempty text, objects, and arrays are supported at the root.
    /// Throws `CancellationError` on cancellation, including cancellation during retry backoff.
    public func evaluate(state: JevValue, questions: [JevQuestion]) async throws -> JevResponse {
        try Task.checkCancellation()
        guard state.isDescription else { throw JevError.invalidRequest("State must be nonempty text, an object, or an array with finite numbers.") }
        guard !questions.isEmpty, Set(questions.map(\.id)).count == questions.count else {
            throw JevError.invalidRequest("Provide at least one question and unique question IDs.")
        }
        for question in questions { try question.validate() }
        let wire = WireRequest(state: state, model: configuration.model,
                               questions: Dictionary(uniqueKeysWithValues: questions.map { ($0.id.rawValue, WireQuestion($0)) }))
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("v1/systemone"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout.secondsValue
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do { request.httpBody = try JSONEncoder().encode(wire) }
        catch { throw JevError.invalidRequest("Request could not be encoded as JSON.") }

        let id = UUID()
        let clock = ContinuousClock()
        let started = clock.now
        logger?.log(.requestStarted(id: id, questionCount: questions.count))
        do {
            for attempt in 1...(configuration.retryPolicy.maximumRetries + 1) {
                try Task.checkCancellation()
                let data: Data
                let response: HTTPURLResponse
                do { (data, response) = try await transport.send(request) }
                catch {
                    if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
                    if retryableTransport(error), let delay = retryDelay(attempt: attempt, serverDelay: nil) {
                        try await wait(id: id, attempt: attempt, delay: delay)
                        continue
                    }
                    throw JevError.transport(code: (error as? URLError)?.code.rawValue)
                }
                try Task.checkCancellation()
                logger?.log(.responseReceived(id: id, attempt: attempt, status: response.statusCode))
                guard (200...299).contains(response.statusCode) else {
                    let serverDelay = retryAfter(response.value(forHTTPHeaderField: "Retry-After"))
                    if retryableStatus(response.statusCode), let delay = retryDelay(attempt: attempt, serverDelay: serverDelay) {
                        try await wait(id: id, attempt: attempt, delay: delay)
                        continue
                    }
                    throw httpError(status: response.statusCode, data: data, delay: serverDelay)
                }
                let decoded: WireResponse
                let answers: [JevQuestionID: JevAnswer]
                do {
                    do { decoded = try JSONDecoder().decode(WireResponse.self, from: data) }
                    catch { throw JevError.decodingFailed }
                    answers = try decoded.validated(questions: questions)
                } catch {
                    logger?.log(.decodingFailed(id: id))
                    throw error
                }
                try Task.checkCancellation()
                let latency = started.duration(to: clock.now)
                let metadata = JevMetadata(model: decoded.model,
                                           usage: JevUsage(inputTokens: decoded.usage.input_tokens, outputTokens: decoded.usage.output_tokens),
                                           latency: latency, attempts: attempt)
                logger?.log(.requestCompleted(id: id, attempts: attempt, latency: latency))
                return JevResponse(answers: answers, metadata: metadata)
            }
            throw JevError.transport(code: nil) // All exhausted attempts normally throw at their failure site.
        } catch {
            logger?.log(.requestFailed(id: id, latency: started.duration(to: clock.now)))
            throw error
        }
    }

    private func retryDelay(attempt: Int, serverDelay: Duration?) -> Duration? {
        let policy = configuration.retryPolicy
        guard attempt <= policy.maximumRetries else { return nil }
        if let serverDelay {
            guard serverDelay <= policy.maximumDelay else { return nil }
            return serverDelay
        }
        let seconds = min(policy.maximumDelay.secondsValue,
                          policy.initialDelay.secondsValue * pow(2, Double(attempt - 1)) * Double.random(in: 1...1.25))
        return .seconds(seconds)
    }
    private func wait(id: UUID, attempt: Int, delay: Duration) async throws {
        logger?.log(.retry(id: id, nextAttempt: attempt + 1, delay: delay))
        try Task.checkCancellation()
        try await sleep(delay)
        try Task.checkCancellation()
    }
    private func httpError(status: Int, data: Data, delay: Duration?) -> JevError {
        let failure = JevHTTPFailure(status: status, responseBody: redactedBody(data, apiKey: configuration.apiKey), retryAfter: delay)
        switch status {
        case 401, 403: return .authenticationFailed(failure)
        case 429: return .rateLimited(failure)
        case 500...599: return .serverError(failure)
        default: return .httpError(failure)
        }
    }
}
