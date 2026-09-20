import Foundation

/// HTTP diagnostics for explicit inspection. Normal error descriptions omit the body.
public struct JevHTTPFailure: Sendable {
    /// HTTP response status.
    public let status: Int
    /// At most 8 KiB of response text after API-key redaction. May contain sensitive application data.
    public let responseBody: String
    /// Parsed server retry delay, when valid; not a promise that the SDK will retry.
    public let retryAfter: Duration?
}

/// Failures with stable categories and credential-safe default descriptions.
public enum JevError: Error, Sendable, CustomStringConvertible, LocalizedError {
    /// Invalid credentials, URL, timeout, model, or retry configuration.
    case invalidConfiguration(String)
    /// Invalid local question/state/threshold; no HTTP request was made for evaluation validation errors.
    case invalidRequest(String)
    /// The server rejected authentication (401 or 403).
    case authenticationFailed(JevHTTPFailure)
    /// Rate limit remained after the configured retry policy (429).
    case rateLimited(JevHTTPFailure)
    /// Server failure, including overload (5xx).
    case serverError(JevHTTPFailure)
    /// Any other unsuccessful HTTP status.
    case httpError(JevHTTPFailure)
    /// JSON could not be decoded into the documented response shape.
    case decodingFailed
    /// A decoded response violates the question/answer contract.
    case invalidResponse(String)
    /// An HTTP transport failed. Only a URL error code is retained, never URL/userInfo/secrets.
    case transport(code: Int?)

    /// A safe diagnostic string, excluding HTTP response bodies and arbitrary underlying errors.
    public var description: String {
        switch self {
        case .invalidConfiguration(let reason): return "Invalid Jev configuration: \(reason)"
        case .invalidRequest(let reason): return "Invalid Jev request: \(reason)"
        case .authenticationFailed: return "Jev authentication failed."
        case .rateLimited: return "Jev rate limit exceeded."
        case .serverError(let failure): return "Jev server error (HTTP \(failure.status))."
        case .httpError(let failure): return "Jev HTTP error (\(failure.status))."
        case .decodingFailed: return "Jev response could not be decoded."
        case .invalidResponse(let reason): return "Invalid Jev response: \(reason)"
        case .transport(let code): return "Jev transport failed\(code.map { " (code \($0))" } ?? "")."
        }
    }
    /// A localized, credential-safe diagnostic.
    public var errorDescription: String? { description }
}
