public struct CorePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CoreSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct CoreRect: Codable, Equatable, Sendable {
    public var origin: CorePoint
    public var size: CoreSize

    public init(origin: CorePoint, size: CoreSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = CorePoint(x: x, y: y)
        self.size = CoreSize(width: width, height: height)
    }
}

public struct PixelSize: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct DisplayTarget: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var frame: CoreRect
    public var pixelSize: PixelSize
    public var scale: Double
    public var colorSpace: String
    public var isMain: Bool
    public var friendlyName: String

    public init(
        id: String,
        frame: CoreRect,
        pixelSize: PixelSize,
        scale: Double,
        colorSpace: String,
        isMain: Bool,
        friendlyName: String
    ) {
        self.id = id
        self.frame = frame
        self.pixelSize = pixelSize
        self.scale = scale
        self.colorSpace = colorSpace
        self.isMain = isMain
        self.friendlyName = friendlyName
    }
}
