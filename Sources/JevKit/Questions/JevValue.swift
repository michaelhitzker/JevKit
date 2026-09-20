import Foundation

/// A lossless JSON shape for structured state, instructions, and descriptions.
/// Numeric values use Double; encode large exact identifiers as strings.
public enum JevValue: Sendable, Equatable, Codable {
    /// A text value.
    case string(String)
    /// A finite JSON number.
    case number(Double)
    /// A Boolean value.
    case bool(Bool)
    /// An ordered JSON array.
    case array([JevValue])
    /// A JSON object.
    case object([String: JevValue])
    /// JSON null, including a Choice option without a description.
    case null

    /// Converts an Encodable application value into structured JSON.
    public init<T: Encodable>(encoding value: T) throws {
        do { self = try JSONDecoder().decode(Self.self, from: JSONEncoder().encode(value)) }
        catch { throw JevError.invalidRequest("State could not be encoded as JSON.") }
    }

    /// Decodes an arbitrary JSON value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([JevValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JevValue].self)) }
    }

    /// Encodes JSON without a case discriminator.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var isDescription: Bool {
        switch self {
        case .string(let text): return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .array(let values): return !values.isEmpty && isFinite
        case .object(let values): return !values.isEmpty && isFinite
        default: return false
        }
    }
    var isFinite: Bool {
        switch self {
        case .number(let n): return n.isFinite
        case .array(let a): return a.allSatisfy(\.isFinite)
        case .object(let o): return o.values.allSatisfy(\.isFinite)
        default: return true
        }
    }
}

extension JevValue: ExpressibleByStringLiteral {
    /// Creates a text description or state from a string literal.
    public init(stringLiteral value: String) { self = .string(value) }
}
