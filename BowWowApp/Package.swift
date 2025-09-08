// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BowWowDependencies",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "BowWowDependencies",
            dependencies: [
                .product(name: "Tagged", package: "swift-tagged"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        )
    ]
)