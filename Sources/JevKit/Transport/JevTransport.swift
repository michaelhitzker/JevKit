import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An injectable HTTP boundary. Implementations must honor task cancellation and request timeouts.
public protocol JevTransport: Sendable {
    /// Sends a request and returns its bytes and HTTP response without interpreting statuses.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Foundation HTTP transport using an ephemeral session without credential-bearing redirects.
public final class URLSessionTransport: JevTransport {
    private let session: URLSession
    private let ownsSession: Bool

    /// Creates a private, ephemeral session. Automatic redirects are rejected to avoid credential disclosure.
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        ownsSession = true
        session = URLSession(configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
    }

    /// Uses a caller-owned session. The caller is responsible for redirect, cookie, and cache security.
    public init(session: URLSession) { self.session = session; self.ownsSession = false }

    deinit { if ownsSession { session.invalidateAndCancel() } }

    /// Uses URLSession's async API, which propagates task cancellation to the network operation.
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw JevError.transport(code: nil) }
        return (data, response)
    }
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
