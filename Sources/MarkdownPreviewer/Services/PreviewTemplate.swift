import Foundation

enum PreviewTemplate {
    private static let previewCSS = {
        resourceText(named: "preview", ext: "css", subdirectory: "Preview")
    }()

    private static let highlightCSS = {
        resourceText(named: "highlight", ext: "css", subdirectory: "Vendor")
    }()

    private static let documentCSS = [
        highlightCSS,
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
