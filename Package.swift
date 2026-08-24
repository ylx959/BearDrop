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
            exclude: [
                "Assets/README.md",
                // Source art for the app icon, not something the app draws. It reaches the bundle
                // as Contents/Resources/AppIcon.icns, built from it by Scripts/package_app.sh.
                "Assets/AppIcon.png"
            ],
            resources: [
                .process("Assets"),
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "ParaBearTests",
            dependencies: ["ParaBear"],
            path: "Tests/ParaBearTests"
        )
    ]
)
