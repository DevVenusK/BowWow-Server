import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: .init(
        [
            .remote(url: "https://github.com/pointfreeco/swift-tagged", requirement: .upToNextMajor(from: "0.10.0")),
            .remote(url: "https://github.com/Alamofire/Alamofire", requirement: .upToNextMajor(from: "5.8.0")),
            .remote(url: "https://github.com/apple/swift-async-algorithms", requirement: .upToNextMajor(from: "1.0.0"))
        ]
    ),
    platforms: [.iOS]
)