import Foundation

/// An explicit location from which to load a credential once during initialization.
/// Plist values must be top-level strings. Bundled credentials are extractable;
/// production consumer apps should generally keep API secrets on their backend.
public enum JevAPIKeySource: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    /// Reads one process environment variable, defaulting to the official SDK variable.
    /// No other variable or plist is tried when the selected value is missing or invalid.
    case environment(String = "TYPESAFE_API_KEY")
    /// Reads an unlocalized entry in a bundle's Info.plist.
    case infoPlist(key: String = "JEV_API_KEY", bundle: Bundle = .main)
    /// Reads an XML or binary property list at a local file URL.
    case plist(url: URL, key: String = "JEV_API_KEY")

    /// Omits caller-supplied names, paths, and bundle details.
    public var description: String { "JevAPIKeySource(<redacted>)" }
    /// A redacted debugger description.
    public var debugDescription: String { description }
    /// Omits associated values from reflection.
    public var customMirror: Mirror { Mirror(self, children: ["source": "<redacted>"]) }

    // Injection keeps tests independent of process-global environment mutation.
    func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        let value: Any?
        switch self {
        case .environment(let name):
            guard !name.isEmpty else {
                throw JevError.invalidConfiguration("An environment variable name is required.")
            }
            value = environment[name]
        case .infoPlist(let key, let bundle):
            value = bundle.infoDictionary?[key]
        case .plist(let url, let key):
            guard url.isFileURL else {
                throw JevError.invalidConfiguration("The API-key plist must use a local file URL.")
            }
            let dictionary: [String: Any]
            do {
                let data = try Data(contentsOf: url)
                guard let decoded = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                    throw JevError.invalidConfiguration("The API-key plist must contain a dictionary.")
                }
                dictionary = decoded
            } catch {
                // Foundation errors can include paths or file contents; do not forward them.
                throw JevError.invalidConfiguration("The API-key plist could not be read as a dictionary.")
            }
            value = dictionary[key]
        }
        guard let key = value as? String, !key.isEmpty,
              key.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }),
              !(key.hasPrefix("$(") && key.hasSuffix(")")),
              !(key.hasPrefix("${") && key.hasSuffix("}")) else {
            throw JevError.invalidConfiguration("The selected API-key source must contain a nonempty credential string without whitespace or unresolved build variables.")
        }
        return key
    }
}
