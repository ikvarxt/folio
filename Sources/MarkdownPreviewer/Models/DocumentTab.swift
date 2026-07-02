import Foundation

@MainActor
final class DocumentTab: ObservableObject, Identifiable {
    enum FileSyncStatus: Equatable {
        case upToDate
        case changedOnDisk
        case missingFromDisk
    }

    struct RenderMetadata: Sendable {
        let byteCount: Int
        let lineCount: Int
        let renderDuration: TimeInterval
    }

    struct ScrollRequest: Equatable {
        let anchorID: String
        let token = UUID()
    }

    let id = UUID()
    let url: URL

    @Published private(set) var title: String
    @Published private(set) var subtitle: String
    @Published private(set) var renderedHTML: String?
    @Published private(set) var tableOfContents: [TableOfContentsItem] = []
    @Published private(set) var renderMetadata: RenderMetadata?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var renderRevision = 0
    @Published private(set) var fileSyncStatus: FileSyncStatus = .upToDate
    @Published var savedScrollPosition: Double = 0
    @Published var scrollRequest: ScrollRequest?

    private var lastRenderedFileVersion: FileVersionSnapshot?

    init(url: URL) {
        self.url = url.standardizedFileURL
        self.title = url.lastPathComponent
        self.subtitle = url.deletingLastPathComponent().tildePath
    }

    var fileDetailsText: String {
        guard let renderMetadata else {
            return "Waiting for first render"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file

        let size = formatter.string(fromByteCount: Int64(renderMetadata.byteCount))
        let lines = renderMetadata.lineCount.formatted(.number.grouping(.automatic))
        let time = renderMetadata.renderDuration.formattedRenderTime

        return "\(size)  •  \(lines) lines  •  \(time)"
    }

    var needsReloadPrompt: Bool {
        fileSyncStatus != .upToDate
    }

    func beginLoading() {
        isLoading = true
        errorMessage = nil
    }

    func applyRender(html: String, metadata: RenderMetadata, fileVersion: FileVersionSnapshot) {
        renderedHTML = html
        renderMetadata = metadata
        tableOfContents = []
        errorMessage = nil
        isLoading = false
        lastRenderedFileVersion = fileVersion
        fileSyncStatus = .upToDate
        renderRevision += 1
    }

    func applyError(_ message: String, fallbackHTML: String? = nil, fileVersion: FileVersionSnapshot? = nil) {
        errorMessage = message
        if let fallbackHTML {
            renderedHTML = fallbackHTML
        }
        tableOfContents = []
        isLoading = false
        lastRenderedFileVersion = fileVersion
        fileSyncStatus = .upToDate
        renderRevision += 1
    }

    func updateTableOfContents(_ items: [TableOfContentsItem]) {
        tableOfContents = items
    }

    func requestScroll(to anchorID: String) {
        scrollRequest = ScrollRequest(anchorID: anchorID)
    }

    func updateFileSyncStatus(using latestVersion: FileVersionSnapshot) {
        guard !isLoading, let lastRenderedFileVersion else {
            return
        }

        if latestVersion == lastRenderedFileVersion {
            fileSyncStatus = .upToDate
            return
        }

        fileSyncStatus = latestVersion.fileExists ? .changedOnDisk : .missingFromDisk
    }
}
