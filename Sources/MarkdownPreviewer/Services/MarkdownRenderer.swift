import CMarkGFM
import Foundation

struct RenderedDocument: Sendable {
    /// Full page, used for the first load of a tab.
    let html: String
    /// Just the article contents, used to swap content without a reload.
    let bodyHTML: String
    let byteCount: Int
    let lineCount: Int
    let renderDuration: TimeInterval
    let fileVersion: FileVersionSnapshot
}

/*
 * Global `let`s are initialised exactly once and thread-safely by the runtime,
 * which is what the extension registry needs: several tabs can auto-reload at
 * the same time, each rendering on its own task.
 */
private let coreExtensionsRegistered: Void = {
    cmark_gfm_core_extensions_ensure_registered()
}()

struct MarkdownRenderer {
    enum RenderError: Error, LocalizedError {
        case parserUnavailable

        var errorDescription: String? {
            switch self {
            case .parserUnavailable:
                return "The Markdown parser could not be started."
            }
        }
    }

    /*
     * Extensions the parser gets.
     *
     * No "footnotes" entry on purpose: footnotes are not a syntax extension,
     * they are switched on by CMARK_OPT_FOOTNOTES below, and asking for them
     * here is a silent no-op.
     *
     * No "autolink" on purpose either, and do not add it. GFM's autolink scanner
     * treats every non-ASCII byte as part of the URL and only stops at ASCII
     * whitespace. Chinese does not put spaces between words, so a bare URL in
     * Chinese prose swallows the rest of the sentence:
     *
     *   详见 https://example.com/spec。另见 ...
     *   -> <a href="https://example.com/spec%E3%80%82%E5%8F%A6%E8%A7%81">
     *          https://example.com/spec。另见</a>
     *
     * Making that safe needs a CJK-aware guess at where the URL ends. These
     * notes use explicit [text](url) links almost everywhere, which are
     * unaffected, so bare URLs stay plain text instead.
     */
    private static let syntaxExtensionNames = [
        "table",
        "strikethrough",
        "tasklist",
    ]

    /*
     * hardBreaks keeps a single newline as a line break. Working notes are
     * written one statement per line, so CommonMark's soft-break rule would run
     * metadata blocks together into one paragraph.
     *
     * Deliberately no CMARK_OPT_SMART: it rewrites `--flag` as an en dash and
     * straight quotes as curly ones, which corrupts technical prose.
     */
    private static var renderOptions: Int32 {
        CMARK_OPT_UNSAFE | CMARK_OPT_HARDBREAKS
    }

    func render(url: URL) throws -> RenderedDocument {
        let startedAt = ContinuousClock.now
        let source = try TextFileLoader.load(from: url)
        let bodyHTML = try Self.renderHTML(markdown: source.text)
        let elapsed = startedAt.duration(to: ContinuousClock.now)

        return RenderedDocument(
            html: PreviewTemplate.makeDocumentHTML(title: url.lastPathComponent, bodyHTML: bodyHTML),
            bodyHTML: bodyHTML,
            byteCount: source.byteCount,
            lineCount: source.lineCount,
            renderDuration: elapsed.timeInterval,
            fileVersion: source.fileVersion
        )
    }

    static func renderHTML(markdown: String) throws -> String {
        _ = coreExtensionsRegistered

        guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES) else {
            throw RenderError.parserUnavailable
        }
        defer { cmark_parser_free(parser) }

        for name in syntaxExtensionNames {
            guard let syntaxExtension = cmark_find_syntax_extension(name) else {
                continue
            }

            cmark_parser_attach_syntax_extension(parser, syntaxExtension)
        }

        let utf8 = Array(markdown.utf8)
        utf8.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                cmark_parser_feed(parser, base, buffer.count)
            }
        }

        guard let document = cmark_parser_finish(parser) else {
            throw RenderError.parserUnavailable
        }
        defer { cmark_node_free(document) }

        // The extension list has to reach the renderer too, otherwise table and
        // task-list nodes fall back to their plain-cmark output.
        guard let rendered = cmark_render_html(
            document,
            renderOptions,
            cmark_parser_get_syntax_extensions(parser)
        ) else {
            throw RenderError.parserUnavailable
        }
        defer { free(rendered) }

        return String(cString: rendered)
    }

}
