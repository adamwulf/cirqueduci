// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cirqueduci",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "CircleCIKit", targets: ["CircleCIKit"]),
        .executable(name: "cirqueduci", targets: ["cirqueduci"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "CircleCIKit"
        ),
        .executableTarget(
            name: "cirqueduci",
            dependencies: [
                "CircleCIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "CircleCIKitTests",
            dependencies: ["CircleCIKit"]
        ),
        .testTarget(
            name: "CLITests",
            dependencies: [
                "cirqueduci",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
