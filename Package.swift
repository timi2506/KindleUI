// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KindleUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KindleUI", targets: ["KindleUI"])
    ],
    targets: [
        // C bridge to GTK+-2.0 / Cairo / Pango / LIPC. SwiftPM cannot mix C and Swift in one
        // target, so this is a separate, internal target (not exported as a product).
        .target(
            name: "CKindleGTK",
            path: "Sources/KindleUI/CKindleGTK",
            publicHeadersPath: "include"
        ),
        .target(
            name: "KindleUI",
            dependencies: ["CKindleGTK"],
            path: "Sources/KindleUI",
            exclude: ["CKindleGTK"]
        ),
        .testTarget(
            name: "KindleUITests",
            dependencies: ["KindleUI"],
            path: "Tests/KindleUITests"
        )
    ]
)
