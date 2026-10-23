// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KindleSwift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KindleUI",
            targets: ["KindleUI"]
        ),
        .executable(
            name: "kindle-swift",
            targets: ["KindleSwiftCLI"]
        ),
        .executable(
            name: "KindleNotesDemo",
            targets: ["KindleNotesDemo"]
        )
    ],
    targets: [
        .target(
            name: "CKindleGTK",
            path: "Sources/CKindleGTK",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("dl", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "KindleUI",
            dependencies: ["CKindleGTK"],
            path: "Sources/KindleUI"
        ),
        .executableTarget(
            name: "KindleSwiftCLI",
            dependencies: ["KindleUI"],
            path: "Sources/KindleSwiftCLI"
        ),
        .executableTarget(
            name: "KindleNotesDemo",
            dependencies: ["KindleUI"],
            path: "Sources/KindleNotesDemo"
        )
    ]
)
