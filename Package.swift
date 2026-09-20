// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JevKit",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "JevKit", targets: ["JevKit"]),
        .executable(name: "JevKitExample", targets: ["JevKitExample"])
    ],
    targets: [
        .target(name: "JevKit"),
        .executableTarget(name: "JevKitExample", dependencies: ["JevKit"]),
        .testTarget(name: "JevKitTests", dependencies: ["JevKit"]),
        .testTarget(name: "JevKitIntegrationTests", dependencies: ["JevKit"])
    ],
    swiftLanguageModes: [.v6]
)
