public protocol SecretStore: Sendable {
    func read(_ ref: SecretRef) throws -> String?
    func write(_ value: String, for ref: SecretRef) throws
    func delete(_ ref: SecretRef) throws
}
