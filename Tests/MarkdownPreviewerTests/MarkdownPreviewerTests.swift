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
}
