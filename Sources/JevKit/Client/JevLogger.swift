import Foundation

/// Optional observability sink. Implementations must tolerate simultaneous client calls.
public protocol JevLogger: Sendable {
    /// Records an event containing no state, questions, credentials, URLs, or response body.
    func log(_ event: JevLogEvent)
}

/// Safe operational events. A local UUID correlates events; it is not a server request ID.
public enum JevLogEvent: Sendable {
    /// An evaluation has passed local validation.
    case requestStarted(id: UUID, questionCount: Int)
    /// An HTTP attempt completed.
    case responseReceived(id: UUID, attempt: Int, status: Int)
    /// An additional attempt will follow a cancellable delay.
    case retry(id: UUID, nextAttempt: Int, delay: Duration)
    /// A response failed decoding or contract validation.
    case decodingFailed(id: UUID)
    /// An evaluation returned successfully, including all retry time.
    case requestCompleted(id: UUID, attempts: Int, latency: Duration)
    /// An evaluation ended with an error or cancellation; no error payload is logged.
    case requestFailed(id: UUID, latency: Duration)
}
