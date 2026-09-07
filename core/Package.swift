// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AubadeCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AubadeCore", targets: ["AubadeCore"])
    ],
    targets: [
        .target(name: "AubadeCore"),
        .testTarget(name: "AubadeCoreTests", dependencies: ["AubadeCore"])
    ]
)
