import Foundation

/// Bounded retries for documented transient statuses and transient URL transport failures.
public struct JevRetryPolicy: Sendable {
    /// Additional attempts after the initial request. Zero disables retries.
    public let maximumRetries: Int
    /// Initial exponential-backoff delay. Jitter adds up to 25 percent.
    public let initialDelay: Duration
    /// Maximum permitted wait. Longer Retry-After values terminate with the HTTP error.
    public let maximumDelay: Duration
    /// Creates a retry policy. Bounds are validated by the client initializer.
    public init(maximumRetries: Int = 2, initialDelay: Duration = .milliseconds(500), maximumDelay: Duration = .seconds(60)) {
        self.maximumRetries = maximumRetries
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
    }
}

/// Immutable connection settings. Credentials are omitted from debug descriptions and mirrors.
public struct JevConfiguration: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let apiKey: String
    /// API root; `v1/systemone` is appended, preserving any gateway path prefix.
    public let baseURL: URL
    /// Per-request transport timeout (URLSession inactivity timeout); backoff is additional time.
    public let timeout: Duration
    /// A model ID or alias; defaults to the official stable alias.
    public let model: String
    /// Retry limits and delays.
    public let retryPolicy: JevRetryPolicy

    /// Creates settings. The client validates HTTPS, credentials, and timing (at most one day).
    /// HTTP is permitted only for localhost/loopback development endpoints.
    public init(apiKey: String, baseURL: URL = URL(string: "https://api.typesafe.ai") ?? URL(fileURLWithPath: "/"),
                timeout: Duration = .seconds(30), model: String = "jev-latest", retryPolicy: JevRetryPolicy = .init()) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.model = model
        self.retryPolicy = retryPolicy
    }
    /// Redacted description; endpoint/model may themselves contain caller-supplied secrets, so are omitted too.
    public var description: String { "JevConfiguration(apiKey: <redacted>)" }
    /// Redacted debugger description.
    public var debugDescription: String { description }
    /// A mirror that never includes credentials.
    public var customMirror: Mirror { Mirror(self, children: ["apiKey": "<redacted>"]) }

    func validate() throws {
        let host = baseURL.host?.lowercased() ?? ""
        let local = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
        guard !apiKey.isEmpty, apiKey.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }),
              !host.isEmpty, baseURL.scheme == "https" || (baseURL.scheme == "http" && local),
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil,
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              timeout > .zero, timeout <= .seconds(86_400),
              (0...10).contains(retryPolicy.maximumRetries), retryPolicy.initialDelay >= .zero,
              retryPolicy.maximumDelay >= retryPolicy.initialDelay,
              retryPolicy.maximumDelay <= .seconds(86_400) else {
            throw JevError.invalidConfiguration("Check API key, HTTPS root URL, model, timeout, and retry bounds.")
        }
    }
}

extension Duration {
    var secondsValue: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
