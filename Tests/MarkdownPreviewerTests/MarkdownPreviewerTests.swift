import XCTest
@testable import MarkdownPreviewer

final class MarkdownPreviewerTests: XCTestCase {
    func testPreviewAssetsLoadFromBundledFallbackLocations() {
        XCTAssertFalse(PreviewTemplate.resourceText(named: "preview", ext: "css", subdirectory: "Preview").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "preview", ext: "js", subdirectory: "Preview").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "mermaid.min", ext: "js", subdirectory: "Vendor").isEmpty)
    }

    func testRendererOutputsHTMLTableForPipeTableMarkdown() throws {
        let markdown = """
        # Demo

        | Name | Value |
        | --- | ---: |
        | Alpha | 1 |
        | Beta | 2 |
        """

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        XCTAssertTrue(rendered.html.contains("<table>"))
        XCTAssertTrue(rendered.html.contains("<thead>"))
        XCTAssertTrue(rendered.html.contains("<td style=\"text-align: right;\">2</td>"))
    }

    func testTablePreprocessorLeavesCodeFencesUntouched() throws {
        let markdown = """
        ```md
        | not | a | table |
        | --- | --- | --- |
        ```
        """

        let processed = try MarkdownPreprocessor().preprocess(markdown)

        XCTAssertFalse(processed.contains("<table>"))
        XCTAssertTrue(processed.contains("| not | a | table |"))
    }

    func testTableOfContentsTreePreservesHeadingHierarchy() {
        let items = [
            TableOfContentsItem(id: "a", title: "A", level: 1),
            TableOfContentsItem(id: "b", title: "B", level: 2),
            TableOfContentsItem(id: "c", title: "C", level: 3),
            TableOfContentsItem(id: "d", title: "D", level: 2),
            TableOfContentsItem(id: "e", title: "E", level: 1),
        ]

        let tree = TableOfContentsNode.tree(from: items)

        XCTAssertEqual(tree.map(\.id), ["a", "e"])
        XCTAssertEqual(tree[0].children.map(\.id), ["b", "d"])
        XCTAssertEqual(tree[0].children[0].children.map(\.id), ["c"])
        XCTAssertTrue(tree[0].collapsibleIDs.contains("a"))
        XCTAssertTrue(tree[0].collapsibleIDs.contains("b"))
        XCTAssertFalse(tree[0].collapsibleIDs.contains("c"))
    }

    func testCollapseAllPreservesFirstTwoVisibleOutlineLevels() {
        let items = [
            TableOfContentsItem(id: "a", title: "A", level: 1),
            TableOfContentsItem(id: "b", title: "B", level: 2),
            TableOfContentsItem(id: "c", title: "C", level: 3),
            TableOfContentsItem(id: "d", title: "D", level: 2),
            TableOfContentsItem(id: "e", title: "E", level: 3),
            TableOfContentsItem(id: "f", title: "F", level: 1),
            TableOfContentsItem(id: "g", title: "G", level: 2),
            TableOfContentsItem(id: "h", title: "H", level: 3),
        ]

        let tree = TableOfContentsNode.tree(from: items)
        let collapsedIDs = TableOfContentsNode.collapsedIDs(in: tree, preservingVisibleDepth: 2)

        XCTAssertEqual(collapsedIDs, ["b", "d", "g"])
        XCTAssertFalse(collapsedIDs.contains("a"))
        XCTAssertFalse(collapsedIDs.contains("f"))
    }

    @MainActor
    func testDocumentTabMarksExternalFileChangesForReload() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try "# Draft".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let tab = DocumentTab(url: url)
        let initialVersion = FileVersionSnapshot.capture(for: url)

        tab.applyRender(
            html: "<p>Draft</p>",
            metadata: .init(byteCount: 7, lineCount: 1, renderDuration: 0.001),
            fileVersion: initialVersion
        )
        XCTAssertEqual(tab.fileSyncStatus, .upToDate)

        try "# Draft updated".write(to: url, atomically: true, encoding: .utf8)
        tab.updateFileSyncStatus(using: FileVersionSnapshot.capture(for: url))

        XCTAssertEqual(tab.fileSyncStatus, .changedOnDisk)
        XCTAssertTrue(tab.needsReloadPrompt)
    }

    @MainActor
    func testDocumentTabMarksMissingFilesForReload() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try "# Draft".write(to: url, atomically: true, encoding: .utf8)

        let tab = DocumentTab(url: url)
        let initialVersion = FileVersionSnapshot.capture(for: url)

        tab.applyRender(
            html: "<p>Draft</p>",
            metadata: .init(byteCount: 7, lineCount: 1, renderDuration: 0.001),
            fileVersion: initialVersion
        )

        try FileManager.default.removeItem(at: url)
        tab.updateFileSyncStatus(using: FileVersionSnapshot.capture(for: url))

        XCTAssertEqual(tab.fileSyncStatus, .missingFromDisk)
        XCTAssertTrue(tab.needsReloadPrompt)
    }

    @MainActor
    func testZenModeToggleUpdatesControllerState() {
        let controller = AppController.shared
        let originalValue = controller.isZenModeEnabled

        defer {
            controller.setZenMode(originalValue)
        }

        controller.setZenMode(false)
        controller.toggleZenMode()
        XCTAssertTrue(controller.isZenModeEnabled)

        controller.toggleZenMode()
        XCTAssertFalse(controller.isZenModeEnabled)
    }
}
