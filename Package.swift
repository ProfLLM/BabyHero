// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BabyHeroCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BabyHeroCore", targets: ["BabyHeroCore"])],
    targets: [
        .target(name: "BabyHeroCore"),
        .testTarget(name: "BabyHeroCoreTests", dependencies: ["BabyHeroCore"])
    ]
)
