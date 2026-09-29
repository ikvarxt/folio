import AppKit
import Foundation

/// What a paste or a drop hands the app: files to open, or text to preview.
enum IncomingContent {
    case files([URL])
    case text(String)

    /*
     * Files win outright. A Finder item also carries its name as plain text,
     * so falling back to text when none of the files is Markdown would open a
     * scratch document holding a file name.
     */
    static func read(from pasteboard: NSPasteboard, acceptingText: Bool) -> IncomingContent? {
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if !fileURLs.isEmpty {
            return make(fileURLs: fileURLs, text: nil)
        }

        return acceptingText ? make(fileURLs: [], text: pasteboard.string(forType: .string)) : nil
    }

    static func make(fileURLs: [URL], text: String?) -> IncomingContent? {
        if !fileURLs.isEmpty {
            let markdownURLs = fileURLs.filter(\.isMarkdownLike)
            return markdownURLs.isEmpty ? nil : .files(markdownURLs)
        }

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return .text(text)
    }
}
