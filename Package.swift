// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JalaliX",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "JalaliX", targets: ["JalaliX"])
    ],
    targets: [
        .target(name: "JalaliX"),
        .testTarget(
            name: "JalaliXTests",
            dependencies: ["JalaliX"]
        )
    ]
)
