import XCTest
@testable import MarkdownPreviewer

final class MarkdownPreviewerTests: XCTestCase {
    func testPreviewAssetsLoadFromBundledFallbackLocations() {
        XCTAssertFalse(PreviewTemplate.resourceText(named: "preview", ext: "css", subdirectory: "Preview").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "preview", ext: "js", subdirectory: "Preview").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "mermaid.min", ext: "js", subdirectory: "Vendor").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "highlight", ext: "js", subdirectory: "Vendor").isEmpty)
        XCTAssertFalse(PreviewTemplate.resourceText(named: "highlight", ext: "css", subdirectory: "Vendor").isEmpty)
    }

    func testPreviewTemplateInlinesHighlightTheme() {
        let highlightCSS = PreviewTemplate.resourceText(named: "highlight", ext: "css", subdirectory: "Vendor")
        let html = PreviewTemplate.makeDocumentHTML(
            title: "Demo",
            bodyHTML: "<pre><code class=\"language-swift\">let value = 1</code></pre>"
        )

        XCTAssertTrue(html.contains(highlightCSS))
        XCTAssertTrue(html.contains("language-swift"))
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

        // cmark-gfm carries alignment as an attribute, not an inline style, and
        // preview.css has to restate it because an attribute loses to author CSS.
        XCTAssertTrue(rendered.html.contains("<td align=\"right\">2</td>"))
        XCTAssertTrue(
            PreviewTemplate.resourceText(named: "preview", ext: "css", subdirectory: "Preview")
                .contains("td[align=\"right\"]")
        )
    }

    func testStrikethroughAndTaskListsComeFromTheParser() throws {
        let markdown = """
        Struck ~~through~~ text.

        - [ ] open task
        - [x] done task
        """

        let html = try MarkdownRenderer.renderHTML(markdown: markdown)

        XCTAssertTrue(html.contains("<del>through</del>"))
        XCTAssertFalse(html.contains("~~"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled=\"\" /> open task"))
        XCTAssertTrue(html.contains("checked=\"\""))

        // The literal "[ ]" that preview.js used to rewrite must be gone.
        XCTAssertFalse(html.contains("[ ]"))
        XCTAssertFalse(html.contains("[x]"))
    }

    func testFootnotesRender() throws {
        let markdown = """
        A claim.[^src]

        [^src]: Where it came from.
        """

        let html = try MarkdownRenderer.renderHTML(markdown: markdown)

        XCTAssertTrue(html.contains("class=\"footnote-ref\""))
        XCTAssertTrue(html.contains("class=\"footnotes\""))
        XCTAssertTrue(html.contains("Where it came from."))
    }

    func testBareURLsStayPlainTextSoChineseProseIsNotSwallowed() throws {
        let markdown = """
        详见 https://example.com/spec。另见 www.example.dev，以及说明。

        A [labelled link](https://example.com/path) still works.
        """

        let html = try MarkdownRenderer.renderHTML(markdown: markdown)

        /*
         * Guard rail for the "autolink" extension, which is deliberately off. Its
         * scanner treats non-ASCII bytes as part of the URL and only stops at
         * ASCII whitespace, so in Chinese prose a bare URL eats the following
         * punctuation and words. If someone switches it back on, this fails.
         * See the comment on MarkdownRenderer.syntaxExtensionNames.
         */
        XCTAssertFalse(html.contains("href=\"https://example.com/spec"))
        XCTAssertFalse(html.contains("%E3%80%82"))
        XCTAssertTrue(html.contains("详见 https://example.com/spec。另见"))

        // Explicit links are a different code path and must keep working.
        XCTAssertTrue(html.contains("<a href=\"https://example.com/path\">labelled link</a>"))
    }

    func testStrikethroughIsNotAppliedInsideCodeSpansOrFences() throws {
        let markdown = """
        Inline `a ~~b~~ c` stays literal.

        ```text
        ~~not struck~~
        ```
        """

        let html = try MarkdownRenderer.renderHTML(markdown: markdown)

        XCTAssertTrue(html.contains("a ~~b~~ c"))
        XCTAssertTrue(html.contains("~~not struck~~"))
        XCTAssertFalse(html.contains("<del>"))
    }

    func testRendererPreservesLanguageClassesForFencedCodeBlocks() throws {
        let markdown = """
        ```swift
        let answer = 42
        ```

        ```react
        export const App = () => <section>Hello</section>;
        ```

        ```kotlin
        val enabled = true
        ```
        """

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        XCTAssertTrue(rendered.html.contains("class=\"language-swift\""))
        XCTAssertTrue(rendered.html.contains("class=\"language-react\""))
        XCTAssertTrue(rendered.html.contains("class=\"language-kotlin\""))
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
            bodyHTML: "<p>Draft</p>",
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
            bodyHTML: "<p>Draft</p>",
            metadata: .init(byteCount: 7, lineCount: 1, renderDuration: 0.001),
            fileVersion: initialVersion
        )

        try FileManager.default.removeItem(at: url)
        tab.updateFileSyncStatus(using: FileVersionSnapshot.capture(for: url))

        XCTAssertEqual(tab.fileSyncStatus, .missingFromDisk)
        XCTAssertTrue(tab.needsReloadPrompt)
    }

    func testRendererKeepsSingleNewlinesAsLineBreaks() throws {
        let markdown = """
        > 需求来源：PRD 第一章。
        > 改动范围文档：`scope.md`。
        > 代码仓库：`demo`。
        """

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        // Two soft breaks between the three statements, so the metadata block
        // stays three lines instead of collapsing into one paragraph.
        XCTAssertEqual(rendered.html.components(separatedBy: "<br />").count - 1, 2)
    }

    func testHardBreaksDoNotDisturbCodeFencesOrGeneratedTables() throws {
        let markdown = """
        | Name | Value |
        | --- | --- |
        | Alpha | 1 |

        ```swift
        let a = 1
        let b = 2
        ```
        """

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        // Table markup is emitted as a raw HTML block and code fences are
        // literal, so neither should pick up a <br />.
        let tableStart = try XCTUnwrap(rendered.html.range(of: "<table>"))
        let tableEnd = try XCTUnwrap(rendered.html.range(of: "</table>"))
        XCTAssertFalse(rendered.html[tableStart.lowerBound..<tableEnd.upperBound].contains("<br"))

        let codeStart = try XCTUnwrap(rendered.html.range(of: "<code class=\"language-swift\">"))
        let codeEnd = try XCTUnwrap(rendered.html.range(of: "</code>"))
        XCTAssertFalse(rendered.html[codeStart.lowerBound..<codeEnd.upperBound].contains("<br"))
    }

    func testRendererEmitsDelElementForStrikethrough() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try "Text with ~~a removed clause~~ inside.".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        XCTAssertTrue(rendered.html.contains("<del>a removed clause</del>"))
        XCTAssertFalse(rendered.html.contains("~~"))
    }

    @MainActor
    func testReloadRefreshesEveryOpenFileThatChangedOnDisk() async throws {
        let controller = AppController.shared
        closeAllTabs(in: controller)
        defer { closeAllTabs(in: controller) }

        let unchanged = try makeTemporaryMarkdown("# Untouched heading")
        let firstChanged = try makeTemporaryMarkdown("# First heading")
        let secondChanged = try makeTemporaryMarkdown("# Second heading")
        defer {
            for url in [unchanged, firstChanged, secondChanged] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        controller.openFiles([unchanged, firstChanged, secondChanged])
        XCTAssertEqual(controller.tabs.count, 3)

        try await waitForIdleRender(in: controller)

        // The selected tab is the last opened one, so the other two prove that a
        // refresh is not limited to whatever happens to be visible.
        XCTAssertEqual(controller.selectedTab?.url, secondChanged)

        try "# First heading, revised further".write(to: firstChanged, atomically: true, encoding: .utf8)
        try "# Second heading, revised further".write(to: secondChanged, atomically: true, encoding: .utf8)
        refreshSyncStatuses(in: controller)

        XCTAssertEqual(
            Set(controller.outdatedTabs.map(\.url)),
            Set([firstChanged, secondChanged])
        )

        XCTAssertEqual(controller.reloadOutdatedTabs(), 2)

        try await waitForIdleRender(in: controller)

        XCTAssertTrue(controller.outdatedTabs.isEmpty)

        let firstTab = controller.tabs.first { $0.url == firstChanged }
        XCTAssertTrue(firstTab?.renderedHTML?.contains("First heading, revised further") == true)

        let secondTab = controller.tabs.first { $0.url == secondChanged }
        XCTAssertTrue(secondTab?.renderedHTML?.contains("Second heading, revised further") == true)
    }

    @MainActor
    func testReloadFallsBackToCurrentTabWhenNothingChanged() async throws {
        let controller = AppController.shared
        closeAllTabs(in: controller)
        defer { closeAllTabs(in: controller) }

        let url = try makeTemporaryMarkdown("# Stable heading")
        defer { try? FileManager.default.removeItem(at: url) }

        controller.openFiles([url])
        try await waitForIdleRender(in: controller)

        let revisionBeforeReload = controller.selectedTab?.renderRevision ?? 0

        XCTAssertEqual(controller.reloadOutdatedTabs(), 0)

        try await waitForIdleRender(in: controller)

        XCTAssertGreaterThan(controller.selectedTab?.renderRevision ?? 0, revisionBeforeReload)
    }

    @MainActor
    func testReloadAllTabsRerendersEveryOpenFile() async throws {
        let controller = AppController.shared
        closeAllTabs(in: controller)
        defer { closeAllTabs(in: controller) }

        let first = try makeTemporaryMarkdown("# One")
        let second = try makeTemporaryMarkdown("# Two")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        controller.openFiles([first, second])
        try await waitForIdleRender(in: controller)

        let revisionsBeforeReload = controller.tabs.map(\.renderRevision)

        controller.reloadAllTabs()
        try await waitForIdleRender(in: controller)

        for (tab, previousRevision) in zip(controller.tabs, revisionsBeforeReload) {
            XCTAssertGreaterThan(tab.renderRevision, previousRevision)
        }
    }

    @MainActor
    func testSelectingAClosedTabLeavesTheSelectionIntact() async throws {
        let controller = AppController.shared
        closeAllTabs(in: controller)
        defer { closeAllTabs(in: controller) }

        let first = try makeTemporaryMarkdown("# One")
        let second = try makeTemporaryMarkdown("# Two")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        controller.openFiles([first, second])
        try await waitForIdleRender(in: controller)

        let closedTabID = try XCTUnwrap(controller.tabs.first { $0.url == second }?.id)
        controller.closeTab(id: closedTabID)

        let survivingSelection = controller.selectedTabID
        controller.selectTab(closedTabID)

        XCTAssertEqual(controller.selectedTabID, survivingSelection)
        XCTAssertNotNil(controller.selectedTab)
    }

    func testRendererExposesBodySeparatelyFromThePage() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try "# Heading\n\nParagraph.".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let rendered = try MarkdownRenderer().render(url: url)

        // The body is what gets swapped into a live page, so it must carry the
        // content without the shell that would nest a second <html> inside it.
        XCTAssertTrue(rendered.bodyHTML.contains("<h1>Heading</h1>"))
        XCTAssertFalse(rendered.bodyHTML.contains("<!doctype"))
        XCTAssertFalse(rendered.bodyHTML.contains("<style>"))
        XCTAssertTrue(rendered.html.contains(rendered.bodyHTML))
    }

    @MainActor
    func testAutoReloadPicksUpASaveWithoutAnExplicitReload() async throws {
        let controller = AppController.shared
        let originalAutoReload = controller.isAutoReloadEnabled
        closeAllTabs(in: controller)
        defer {
            closeAllTabs(in: controller)
            controller.setAutoReload(originalAutoReload)
        }

        controller.setAutoReload(true)

        let url = try makeTemporaryMarkdown("# Before the save")
        defer { try? FileManager.default.removeItem(at: url) }

        controller.openFiles([url])
        try await waitForIdleRender(in: controller)

        try "# After the save, with more words".write(to: url, atomically: true, encoding: .utf8)

        // No reload call here: the disk monitor is expected to do it.
        try await waitUntil(in: controller) { tab in
            tab.renderedBodyHTML?.contains("After the save") == true
        }

        XCTAssertTrue(controller.outdatedTabs.isEmpty)
    }

    @MainActor
    func testAutoReloadOffLeavesTheTabStaleUntilAskedToReload() async throws {
        let controller = AppController.shared
        let originalAutoReload = controller.isAutoReloadEnabled
        closeAllTabs(in: controller)
        defer {
            closeAllTabs(in: controller)
            controller.setAutoReload(originalAutoReload)
        }

        controller.setAutoReload(false)

        let url = try makeTemporaryMarkdown("# Before the save")
        defer { try? FileManager.default.removeItem(at: url) }

        controller.openFiles([url])
        try await waitForIdleRender(in: controller)

        try "# After the save, with more words".write(to: url, atomically: true, encoding: .utf8)

        try await waitUntil(in: controller) { tab in
            tab.fileSyncStatus == .changedOnDisk
        }

        XCTAssertEqual(controller.selectedTab?.renderedBodyHTML?.contains("After the save"), false)

        XCTAssertEqual(controller.reloadOutdatedTabs(), 1)
        try await waitForIdleRender(in: controller)

        XCTAssertEqual(controller.selectedTab?.renderedBodyHTML?.contains("After the save"), true)
    }

    @MainActor
    func testActiveHeadingClearsWhenTheHeadingDisappears() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try "# One".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let tab = DocumentTab(url: url)
        tab.updateTableOfContents([
            TableOfContentsItem(id: "one", title: "One", level: 1),
            TableOfContentsItem(id: "two", title: "Two", level: 2),
        ])
        tab.updateActiveHeading("two")
        XCTAssertEqual(tab.activeHeadingID, "two")

        // A reload that removed that heading must not leave the outline pointing
        // at a row that is no longer there.
        tab.updateTableOfContents([
            TableOfContentsItem(id: "one", title: "One", level: 1),
        ])

        XCTAssertEqual(tab.activeHeadingID, "one")

        tab.updateActiveHeading("")
        XCTAssertNil(tab.activeHeadingID)
    }

    // MARK: - Helpers

    private func makeTemporaryMarkdown(_ contents: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")

        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.standardizedFileURL
    }

    @MainActor
    private func closeAllTabs(in controller: AppController) {
        for tab in controller.tabs {
            controller.closeTab(id: tab.id)
        }
    }

    @MainActor
    private func refreshSyncStatuses(in controller: AppController) {
        for tab in controller.tabs {
            tab.updateFileSyncStatus(using: FileVersionSnapshot.capture(for: tab.url))
        }
    }

    /// Polls until every open tab satisfies `condition`. The disk monitor runs on
    /// a 1s cycle, so this needs a timeout well above that.
    @MainActor
    private func waitUntil(
        in controller: AppController,
        timeout: Duration = .seconds(8),
        _ condition: (DocumentTab) -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)

        while ContinuousClock.now < deadline {
            if !controller.tabs.isEmpty, controller.tabs.allSatisfy(condition) {
                return
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        XCTFail("Condition not met within \(timeout)")
    }

    @MainActor
    private func waitForIdleRender(
        in controller: AppController,
        timeout: Duration = .seconds(5)
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)

        while ContinuousClock.now < deadline {
            let isIdle = controller.tabs.allSatisfy { !$0.isLoading && $0.renderedHTML != nil }

            if isIdle {
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }

        XCTFail("Renders did not settle within \(timeout)")
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
