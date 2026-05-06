// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KittenTTSBundledAssetsExample",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "KittenTTSBundledAssetsExample",
            dependencies: [
                .product(name: "KittenTTS", package: "KittenTTS-swift"),
            ]
        ),
    ]
)
