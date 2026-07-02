// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MarkdownPreviewer",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "MarkdownPreviewer",
            targets: ["MarkdownPreviewer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/johnxnguyen/Down.git", from: "0.9.5"),
    ],
    targets: [
        .executableTarget(
            name: "MarkdownPreviewer",
            dependencies: [
                "Down",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
