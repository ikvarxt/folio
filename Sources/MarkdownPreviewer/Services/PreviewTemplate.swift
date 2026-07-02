import Foundation

enum PreviewTemplate {
    private static let previewCSS = {
        resourceText(named: "preview", ext: "css", subdirectory: "Preview")
    }()

    static func makeDocumentHTML(title: String, bodyHTML: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title.htmlEscaped)</title>
          <style>\(previewCSS)</style>
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

    static func resourceText(named name: String, ext: String, subdirectory: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory),
              let text = try? String(contentsOf: url) else {
            return ""
        }

        return text
    }
}
