// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BilidownMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BilidownMac", targets: ["BilidownMac"])
    ],
    targets: [
        .executableTarget(
            name: "BilidownMac",
            path: "Sources/BilidownMac"
        )
    ]
)
