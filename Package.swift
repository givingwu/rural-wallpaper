// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RuralWallpaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RuralWallpaperCore", targets: ["RuralWallpaperCore"]),
        .executable(name: "RuralWallpaperApp", targets: ["RuralWallpaperApp"])
    ],
    targets: [
        .target(name: "RuralWallpaperCore"),
        .executableTarget(
            name: "RuralWallpaperApp",
            dependencies: ["RuralWallpaperCore"]
        ),
        .testTarget(
            name: "RuralWallpaperCoreTests",
            dependencies: ["RuralWallpaperCore"]
        ),
        .testTarget(
            name: "RuralWallpaperAppTests",
            dependencies: ["RuralWallpaperApp"]
        )
    ]
)
