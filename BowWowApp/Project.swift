import ProjectDescription

let project = Project(
    name: "BowWowApp",
    targets: [
        .target(
            name: "BowWowApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.bowwow.app",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .file(path: "BowWowApp/Info.plist"),
            sources: ["BowWowApp/**"],
            resources: ["BowWowApp/Assets.xcassets", "BowWowApp/Preview Content/**"],
            dependencies: [
                .external(name: "Tagged"),
                .external(name: "Alamofire"),
                .external(name: "AsyncAlgorithms")
            ]
        ),
        .target(
            name: "BowWowAppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.bowwow.app.tests",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["BowWowAppTests/**"],
            dependencies: [
                .target(name: "BowWowApp")
            ]
        ),
        .target(
            name: "BowWowAppUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.bowwow.app.uitests",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["BowWowAppUITests/**"],
            dependencies: [
                .target(name: "BowWowApp")
            ]
        )
    ]
)