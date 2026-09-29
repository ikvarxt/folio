import Foundation

/*
 * Pasted and dropped text is written to a real file rather than held in
 * memory, so rendering, reload, and Reveal in Finder treat it like any other
 * tab. The files are disposable: closing the tab or quitting deletes them.
 */
enum ScratchDocumentStore {
    private static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Pasted", isDirectory: true)

    static func contains(_ url: URL) -> Bool {
        url.standardizedFileURL.deletingLastPathComponent().path == directory.standardizedFileURL.path
    }

    static func makeDocument(text: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var index = 1
        var url = directory.appendingPathComponent("Pasted \(index).md")

        while FileManager.default.fileExists(atPath: url.path) {
            index += 1
            url = directory.appendingPathComponent("Pasted \(index).md")
        }

        try Data(text.utf8).write(to: url, options: .withoutOverwriting)
        return url
    }

    static func remove(_ url: URL) {
        guard contains(url) else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
