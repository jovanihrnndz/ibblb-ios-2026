// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IBBLBAndroid",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "IBBLBAndroid",
            targets: ["IBBLBAndroid"]
        )
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-web.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "IBBLBAndroid",
            dependencies: [
                .product(name: "Skip", package: "skip"),
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "SkipWeb", package: "skip-web")
            ],
            path: "../IBBLB",
            plugins: [
                .plugin(name: "skipstone", package: "skip")
            ]
        )
    ]
)
