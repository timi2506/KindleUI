// swift-tools-version: 5.9
import PackageDescription

// Example apps for KindleUI. Kept in a separate package so the root KindleUI package
// exposes only the library.
let package = Package(
    name: "KindleUIExamples",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KindleShowcase", targets: ["KindleShowcase"]),
        .executable(name: "KindleWiki", targets: ["KindleWiki"])
    ],
    dependencies: [
        .package(name: "KindleUI", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "KindleShowcase",
            dependencies: [.product(name: "KindleUI", package: "KindleUI")],
            path: "KindleShowcase"
        ),
        .executableTarget(
            name: "KindleWiki",
            dependencies: [.product(name: "KindleUI", package: "KindleUI")],
            path: "KindleWiki"
        ),
        .testTarget(
            name: "KindleWikiTests",
            dependencies: ["KindleWiki"],
            path: "Tests/KindleWikiTests"
        )
    ]
)
