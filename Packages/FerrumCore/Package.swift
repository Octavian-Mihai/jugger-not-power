// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FerrumCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FerrumCore", targets: ["FerrumCore"])],
    targets: [
        .target(name: "FerrumCore"),
        .testTarget(name: "FerrumCoreTests", dependencies: ["FerrumCore"]),
    ]
)
