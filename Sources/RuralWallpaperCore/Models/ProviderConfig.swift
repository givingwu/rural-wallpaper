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

public struct ProviderConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var baseURL: URL
    public var model: String
    public var secretRef: SecretRef
    public var headers: [String: String]
    public var capabilities: ProviderCapability

    public init(
        id: String,
        name: String,
        baseURL: URL,
        model: String,
        secretRef: SecretRef,
        headers: [String: String] = [:],
        capabilities: ProviderCapability = []
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.secretRef = secretRef
        self.headers = headers
        self.capabilities = capabilities
    }
}
