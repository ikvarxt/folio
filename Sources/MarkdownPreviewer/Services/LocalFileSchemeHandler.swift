import Foundation
import UniformTypeIdentifiers
import WebKit

/*
 * A page loaded with loadHTMLString cannot read file:// URLs, whatever its
 * base URL says: the WebContent process is sandboxed away from the disk. The
 * document's base URL therefore points at this scheme instead, so relative
 * image paths resolve here and the host process reads the file.
 *
 * Only media types are served. Documents are rendered with raw HTML enabled,
 * so a script in a Markdown file could otherwise read any file on disk.
 */
@MainActor
final class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
    nonisolated static let scheme = "mdpreview"
    private nonisolated static let host = "local"

    private var activeTasks = Set<ObjectIdentifier>()

    nonisolated static func url(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = fileURL.hasDirectoryPath ? fileURL.path + "/" : fileURL.path
        return components.url
    }

    nonisolated static func fileURL(for url: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme, url.host == host else {
            return nil
        }

        return URL(fileURLWithPath: url.path)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = Self.fileURL(for: requestURL),
              let mimeType = Self.servableMIMEType(for: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let taskID = ObjectIdentifier(urlSchemeTask)
        activeTasks.insert(taskID)

        Task { [weak self] in
            let result = await Self.readFile(at: fileURL)

            // WebKit raises if a task is answered after it was stopped.
            guard let self, self.activeTasks.remove(taskID) != nil else {
                return
            }

            switch result {
            case .success(let data):
                let response = URLResponse(
                    url: requestURL,
                    mimeType: mimeType,
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            case .failure(let error):
                urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        activeTasks.remove(ObjectIdentifier(urlSchemeTask))
    }

    @concurrent
    private nonisolated static func readFile(at fileURL: URL) async -> Result<Data, any Error> {
        Result { try Data(contentsOf: fileURL, options: .mappedIfSafe) }
    }

    private nonisolated static func servableMIMEType(for fileURL: URL) -> String? {
        guard let type = UTType(filenameExtension: fileURL.pathExtension),
              type.conforms(to: .image) || type.conforms(to: .audiovisualContent) else {
            return nil
        }

        return type.preferredMIMEType ?? "application/octet-stream"
    }
}
