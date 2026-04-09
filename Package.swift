// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CardGameKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CardGameKit", targets: ["CardGameKit"])
    ],
    targets: [
        .target(
            name: "CardGameKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CardGameKitTests",
            dependencies: ["CardGameKit"]
        )
    ]
)
