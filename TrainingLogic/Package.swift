// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrainingLogic",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TrainingLogic", targets: ["TrainingLogic"])
    ],
    targets: [
        .target(name: "TrainingLogic"),
        .testTarget(
            name: "TrainingLogicTests",
            dependencies: ["TrainingLogic"]
        )
    ]
)
