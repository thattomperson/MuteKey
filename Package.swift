// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VMKit",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "VMKit",
        )
    ],
    swiftLanguageModes: [.v6],
)
