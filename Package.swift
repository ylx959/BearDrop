// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ParaBear",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ParaBear", targets: ["ParaBear"])
    ],
    targets: [
        .executableTarget(
            name: "ParaBear",
            path: "Sources/ParaBear",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        )
    ]
)
