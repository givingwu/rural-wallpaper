public protocol DisplayProvider: Sendable {
    func currentDisplays() -> [DisplayTarget]
}
