import Foundation

struct FileVersionSnapshot: Equatable, Sendable {
    let fileExists: Bool
    let contentModificationDate: Date?
    let fileSize: Int64?
    let resourceIdentifier: String?

    static func capture(for url: URL) -> FileVersionSnapshot {
        var refreshedURL = url
        refreshedURL.removeAllCachedResourceValues()

        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .fileSizeKey,
            .fileResourceIdentifierKey,
            .isRegularFileKey,
        ]

        let values = try? refreshedURL.resourceValues(forKeys: keys)

        return FileVersionSnapshot(
            fileExists: values?.isRegularFile ?? FileManager.default.fileExists(atPath: refreshedURL.path),
            contentModificationDate: values?.contentModificationDate,
            fileSize: values?.fileSize.map(Int64.init),
            resourceIdentifier: values?.fileResourceIdentifier.map { String(describing: $0) }
        )
    }
}
