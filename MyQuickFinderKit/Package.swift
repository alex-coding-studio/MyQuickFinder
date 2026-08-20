// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyQuickFinderKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MyQuickFinderKit", targets: ["MyQuickFinderKit"]),
    ],
    targets: [
        .target(name: "MyQuickFinderKit"),
        .testTarget(
            name: "MyQuickFinderKitTests",
            dependencies: ["MyQuickFinderKit"]
        ),
    ]
)
