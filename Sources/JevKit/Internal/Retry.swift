import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func retryableStatus(_ status: Int) -> Bool { status == 408 || status == 429 || (500...599).contains(status) }

func retryableTransport(_ error: any Error) -> Bool {
    guard let error = error as? URLError else { return false }
    return [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
            .dnsLookupFailed, .notConnectedToInternet].contains(error.code)
}

func retryAfter(_ header: String?, now: Date = Date()) -> Duration? {
    guard let header else { return nil }
    let value = header.trimmingCharacters(in: .whitespacesAndNewlines)
    if let seconds = Double(value), seconds.isFinite, seconds >= 0, seconds < Double(Int64.max) / 2 {
        return .seconds(seconds)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    guard let date = formatter.date(from: value) else { return nil }
    return .seconds(max(0, date.timeIntervalSince(now)))
}

func redactedBody(_ data: Data, apiKey: String) -> String {
    // Decode/re-encode JSON first, so escaped credentials cannot bypass literal redaction.
    func redact(_ value: JevValue) -> JevValue {
        switch value {
        case .string(let text): return .string(text.replacingOccurrences(of: apiKey, with: "<redacted>"))
        case .array(let values): return .array(values.map(redact))
        case .object(let values):
            var output: [String: JevValue] = [:]
            for (key, value) in values { output[key.replacingOccurrences(of: apiKey, with: "<redacted>")] = redact(value) }
            return .object(output)
        default: return value
        }
    }
    let text: String
    if let value = try? JSONDecoder().decode(JevValue.self, from: data), let clean = try? JSONEncoder().encode(redact(value)) {
        text = String(decoding: clean, as: UTF8.self)
    } else {
        // Also redact escaped JSON strings in malformed/non-JSON bodies.
        var raw = String(decoding: data, as: UTF8.self).replacingOccurrences(of: apiKey, with: "<redacted>")
        if let encoded = try? JSONEncoder().encode(apiKey) {
            let escaped = String(decoding: encoded, as: UTF8.self).dropFirst().dropLast()
            raw = raw.replacingOccurrences(of: String(escaped), with: "<redacted>")
        }
        text = raw
    }
    var prefix = Data(text.utf8.prefix(8192))
    while !prefix.isEmpty {
        if let valid = String(data: prefix, encoding: .utf8) { return valid }
        prefix.removeLast()
    }
    return ""
}
