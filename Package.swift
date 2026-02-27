// swift-tools-version: 5.9
import PackageDescription

// Skip cross-platform Android integration package.
// iOS app is built normally via IBBLB.xcodeproj.
// Android app is built via: skip android build (from this directory)
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
        .package(url: "https://source.skip.tools/skip.git", branch: "main"),
        .package(url: "https://source.skip.tools/skip-ui.git", branch: "main"),
        .package(url: "https://source.skip.tools/skip-foundation.git", branch: "main"),
        .package(url: "https://source.skip.tools/skip-web.git", branch: "main")
    ],
    targets: [
        .target(
            name: "IBBLBAndroid",
            dependencies: [
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "SkipFoundation", package: "skip-foundation"),
                .product(name: "SkipWeb", package: "skip-web")
            ],
            path: "IBBLB",
            plugins: [
                .plugin(name: "skipstone", package: "skip")
            ]
        )
    ]
)
