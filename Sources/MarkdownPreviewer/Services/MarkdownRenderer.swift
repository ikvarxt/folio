import Down
import Foundation

struct RenderedDocument: Sendable {
    let html: String
    let byteCount: Int
    let lineCount: Int
    let renderDuration: TimeInterval
}

struct MarkdownRenderer {
    func render(url: URL) throws -> RenderedDocument {
        let startedAt = ContinuousClock.now
        let source = try TextFileLoader.load(from: url)
        let bodyHTML = try Down(markdownString: source.text).toHTML()
        let elapsed = startedAt.duration(to: ContinuousClock.now)

        return RenderedDocument(
            html: PreviewTemplate.makeDocumentHTML(title: url.lastPathComponent, bodyHTML: bodyHTML),
            byteCount: source.byteCount,
            lineCount: source.lineCount,
            renderDuration: elapsed.timeInterval
        )
    }
}
