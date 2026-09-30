// swift-tools-version: 6.2

import PackageDescription

let productSwiftSettings: [SwiftSetting] = [.define("BLENNY_PRODUCT"), .unsafeFlags(["-Xcc", "-DBLENNY_PRODUCT=1"])]

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
            swiftSettings: productSwiftSettings,
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
            swiftSettings: productSwiftSettings,
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .target(
            name: "BlennyPrivateABIShim",
            publicHeadersPath: "include",
            cSettings: [.define("BLENNY_PRODUCT", to: "1")]
        ),
        .executableTarget(
            name: "BlennyLayoutProbe",
            dependencies: ["BlennyCore"],
            swiftSettings: productSwiftSettings
        ),
        .testTarget(name: "BlennyAppTests", dependencies: ["BlennyApp"], swiftSettings: productSwiftSettings),
        .testTarget(
            name: "BlennyCoreTests",
            dependencies: ["BlennyCore"],
            swiftSettings: productSwiftSettings
        )
    ]
)
