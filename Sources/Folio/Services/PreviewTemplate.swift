import Foundation

enum PreviewTemplate {
    private static let previewCSS = {
        resourceText(named: "preview", ext: "css", subdirectory: "Preview")
    }()

    private static let highlightCSS = {
        resourceText(named: "highlight", ext: "css", subdirectory: "Vendor")
    }()

    /*
     * Vendored themes ship as unconditional rules, so the night one is scoped to
     * the media query here rather than by editing the file: that keeps it
     * byte-identical to its upstream release and re-vendorable in one copy.
     */
    private static let highlightDarkCSS = {
        let theme = resourceText(named: "highlight-dark", ext: "css", subdirectory: "Vendor")

        return theme.isEmpty ? "" : "@media (prefers-color-scheme: dark) {\n\(theme)\n}"
    }()

    /*
     * preview.css comes last on purpose: both vendored themes carry layout rules
     * of their own (`pre code.hljs { padding: 1em }`) at the same specificity as
     * the ones here, so only source order keeps code blocks from re-padding
     * themselves once the dark theme applies.
     */
    private static let documentCSS = [
        highlightCSS,
        highlightDarkCSS,
        previewCSS,
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n")

    static func makeDocumentHTML(title: String, bodyHTML: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title.htmlEscaped)</title>
          <style>\(documentCSS)</style>
        </head>
        <body>
          <div class="canvas">
            <article class="document">
              \(bodyHTML)
            </article>
          </div>
        </body>
        </html>
        """
    }

    static func makeErrorHTML(title: String, message: String) -> String {
        makeDocumentHTML(
            title: title,
            bodyHTML: """
            <section class="error-state">
              <p class="eyebrow">Render failed</p>
              <h1>\(title.htmlEscaped)</h1>
              <p>\(message.htmlEscaped)</p>
            </section>
            """
        )
    }

    static func resourceText(named name: String, ext: String, subdirectory: String? = nil) -> String {
        let urls = [
            subdirectory.flatMap { Bundle.module.url(forResource: name, withExtension: ext, subdirectory: $0) },
            Bundle.module.url(forResource: name, withExtension: ext),
        ]

        for url in urls.compactMap({ $0 }) {
            if let text = try? String(contentsOf: url) {
                return text
            }
        }

        return ""
    }
}
