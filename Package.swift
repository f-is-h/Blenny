// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Blenny",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "Blenny", targets: ["BlennyApp"]),
        .executable(name: "BlennyLayoutProbe", targets: ["BlennyLayoutProbe"])
    ],
    targets: [
        .target(
            name: "BlennyCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "BlennyApp",
            dependencies: ["BlennyCore"]
        ),
        .executableTarget(
            name: "BlennyLayoutProbe",
            dependencies: ["BlennyCore"]
        ),
        .testTarget(
            name: "BlennyCoreTests",
            dependencies: ["BlennyCore"]
        )
    ]
)
