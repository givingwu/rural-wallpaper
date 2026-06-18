import Foundation

public enum ProviderRegistryError: Error, Equatable, Sendable {
    case providerNotFound(String)
}

public struct ProviderRegistry: Sendable {
    public var configs: [ProviderConfig]

    public init(configs: [ProviderConfig] = []) {
        self.configs = configs
    }

    public func config(id: String) -> ProviderConfig? {
        configs.first { $0.id == id }
    }

    public func makeProvider(
        id: String,
        secretStore: any SecretStore,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) throws -> OpenAICompatibleProvider {
        guard let config = config(id: id) else {
            throw ProviderRegistryError.providerNotFound(id)
        }

        return OpenAICompatibleProvider(
            config: config,
            secretStore: secretStore,
            httpClient: httpClient
        )
    }
}
