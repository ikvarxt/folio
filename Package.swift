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
        // cmark-gfm rather than plain cmark: tables, strikethrough, task lists,
        // autolinks, and footnotes come from the parser instead of being
        // hand-rolled around it.
        .package(url: "https://github.com/stackotter/swift-cmark-gfm", from: "1.0.2"),
    ],
    targets: [
        .executableTarget(
            name: "MarkdownPreviewer",
            dependencies: [
                .product(name: "CMarkGFM", package: "swift-cmark-gfm"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MarkdownPreviewerTests",
            dependencies: [
                "MarkdownPreviewer",
            ]
        ),
    ]
)
