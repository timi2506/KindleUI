// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HelloWorld",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "/Users/timi2506/Desktop/Xcode Projects/KindleUI")
    ],
    targets: [
        .executableTarget(
            name: "HelloWorld",
            dependencies: [
                .product(name: "KindleUI", package: "KindleUI")
            ],
            path: "Sources/HelloWorld"
        )
    ]
)