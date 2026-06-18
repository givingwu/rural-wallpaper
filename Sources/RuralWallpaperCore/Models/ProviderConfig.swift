import Foundation

public struct SecretRef: Codable, Equatable, Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }
}

public struct ProviderCapability: OptionSet, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let vision = ProviderCapability(rawValue: 1 << 0)
    public static let imageGeneration = ProviderCapability(rawValue: 1 << 1)
    public static let structuredOutput = ProviderCapability(rawValue: 1 << 2)
}

public enum ProviderConfigValidationError: Error, Equatable, Sendable {
    case sensitiveAdditionalHeader(String)
}

public struct ProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var baseURL: URL
    public var model: String
    public var secretRef: SecretRef
    public private(set) var additionalHeaders: [String: String]
    public var capabilities: ProviderCapability

    public init(
        id: String,
        name: String,
        baseURL: URL,
        model: String,
        secretRef: SecretRef,
        additionalHeaders: [String: String] = [:],
        capabilities: ProviderCapability = []
    ) throws {
        try Self.validateAdditionalHeaders(additionalHeaders)

        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.secretRef = secretRef
        self.additionalHeaders = additionalHeaders
        self.capabilities = capabilities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let additionalHeaders = try container.decodeIfPresent(
            [String: String].self,
            forKey: .additionalHeaders
        ) ?? [:]

        do {
            try Self.validateAdditionalHeaders(additionalHeaders)
        } catch ProviderConfigValidationError.sensitiveAdditionalHeader(let header) {
            throw DecodingError.dataCorruptedError(
                forKey: .additionalHeaders,
                in: container,
                debugDescription: "Sensitive additional header is not allowed: \(header)"
            )
        }

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.baseURL = try container.decode(URL.self, forKey: .baseURL)
        self.model = try container.decode(String.self, forKey: .model)
        self.secretRef = try container.decode(SecretRef.self, forKey: .secretRef)
        self.additionalHeaders = additionalHeaders
        self.capabilities = try container.decode(ProviderCapability.self, forKey: .capabilities)
    }

    private static func validateAdditionalHeaders(_ headers: [String: String]) throws {
        for (key, value) in headers {
            if isSensitiveHeaderKey(key) || isSensitiveHeaderValue(value) {
                throw ProviderConfigValidationError.sensitiveAdditionalHeader(key)
            }
        }
    }

    private static func isSensitiveHeaderKey(_ key: String) -> Bool {
        let normalizedKey = normalizedHeaderKey(key)
        let sensitiveFragments = [
            "authorization",
            "auth",
            "token",
            "secret",
            "key",
            "apikey",
            "xapikey"
        ]

        return sensitiveFragments.contains { normalizedKey.contains($0) }
    }

    private static func normalizedHeaderKey(_ key: String) -> String {
        key.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0).lowercased() }
            .joined()
    }

    private static func isSensitiveHeaderValue(_ value: String) -> Bool {
        value.range(of: "Bearer ", options: .caseInsensitive) != nil
            || value.contains("sk-")
    }
}
