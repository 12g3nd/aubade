// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AubadeCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AubadeCore", targets: ["AubadeCore"]),
        .library(name: "AubadeUI", targets: ["AubadeUI"])
    ],
    targets: [
        .target(name: "AubadeCore"),
        .target(name: "AubadeUI", dependencies: ["AubadeCore"]),
        .testTarget(name: "AubadeCoreTests", dependencies: ["AubadeCore"])
    ]
)
