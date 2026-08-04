import Down
import Foundation

struct RenderedDocument: Sendable {
    let html: String
    let byteCount: Int
    let lineCount: Int
    let renderDuration: TimeInterval
    let fileVersion: FileVersionSnapshot
}

struct MarkdownRenderer {
    /*
     * hardBreaks turns a single newline into <br> instead of collapsing it to a
     * space. Working notes are written one statement per line, so CommonMark's
     * soft-break rule silently runs metadata blocks and stacked bullets
     * together into one paragraph. This matches Obsidian, Notion, and Lark
     * rather than github.com's rendering of .md files.
     *
     * Deliberately no `smart`: it would rewrite `--flag` as an en dash and
     * straight quotes as curly ones, which corrupts technical prose.
     */
    // Computed, not stored: DownOptions is not Sendable, so a static let would
    // trip Swift 6 global-state checking.
    static var downOptions: DownOptions { [.unsafe, .hardBreaks] }

    private let preprocessor = MarkdownPreprocessor()

    func render(url: URL) throws -> RenderedDocument {
        let startedAt = ContinuousClock.now
        let source = try TextFileLoader.load(from: url)
        let preparedMarkdown = try preprocessor.preprocess(source.text)
        let bodyHTML = try Down(markdownString: preparedMarkdown).toHTML(MarkdownRenderer.downOptions)
        let elapsed = startedAt.duration(to: ContinuousClock.now)

        return RenderedDocument(
            html: PreviewTemplate.makeDocumentHTML(title: url.lastPathComponent, bodyHTML: bodyHTML),
            byteCount: source.byteCount,
            lineCount: source.lineCount,
            renderDuration: elapsed.timeInterval,
            fileVersion: source.fileVersion
        )
    }
}
