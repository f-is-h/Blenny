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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(
            name: "BlennyCore",
            dependencies: ["BlennyPrivateABIShim"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "BlennyApp",
            dependencies: [
                "BlennyCore", "BlennyPrivateABIShim",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .target(
            name: "BlennyPrivateABIShim",
            publicHeadersPath: "include"
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
