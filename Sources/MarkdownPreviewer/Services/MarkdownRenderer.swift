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
    private let preprocessor = MarkdownPreprocessor()

    func render(url: URL) throws -> RenderedDocument {
        let startedAt = ContinuousClock.now
        let source = try TextFileLoader.load(from: url)
        let preparedMarkdown = try preprocessor.preprocess(source.text)
        let bodyHTML = try Down(markdownString: preparedMarkdown).toHTML(.unsafe)
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
