import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppController: ObservableObject {
    private struct OpenTabProbe: Sendable {
        let id: DocumentTab.ID
        let url: URL
    }

    static let shared = AppController()

    private enum PreferenceKey {
        static let autoReload = "autoReloadOnDiskChange"
    }

    @Published private(set) var tabs: [DocumentTab] = []
    @Published var selectedTabID: DocumentTab.ID?
    @Published private(set) var isZenModeEnabled = false
    @Published var isDropTargeted = false

    /*
     * On by default: this app is read-only and normally sits beside an editor,
     * so the useful behaviour is for a save to show up here on its own. Content
     * is swapped without a page reload, so an update mid-read costs nothing but
     * the changed text.
     */
    @Published private(set) var isAutoReloadEnabled: Bool

    private let renderer = MarkdownRenderer()
    private var renderTasks: [DocumentTab.ID: Task<Void, Never>] = [:]
    private var fileVersionMonitorTask: Task<Void, Never>?
    private var didLoadLaunchArguments = false

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [PreferenceKey.autoReload: true])
        isAutoReloadEnabled = defaults.bool(forKey: PreferenceKey.autoReload)

        // Leftovers from a session that crashed before it could clean up.
        ScratchDocumentStore.removeAll()

        startFileVersionMonitoring()
    }

    deinit {
        fileVersionMonitorTask?.cancel()
    }

    var selectedTab: DocumentTab? {
        tabs.first(where: { $0.id == selectedTabID })
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .plainText,
            .utf8PlainText,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "mdown") ?? .plainText,
            UTType(filenameExtension: "mkd") ?? .plainText,
        ]

        guard panel.runModal() == .OK else {
            return
        }

        openFiles(panel.urls)
    }

    func loadLaunchArgumentsIfNeeded() {
        guard !didLoadLaunchArguments else {
            return
        }

        didLoadLaunchArguments = true

        let arguments = CommandLine.arguments.dropFirst()
        let urls = arguments.map { argument in
            URL(fileURLWithPath: argument)
        }.filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        if !urls.isEmpty {
            openFiles(urls)
        }
    }

    func openFiles(_ urls: [URL]) {
        for url in urls {
            let normalizedURL = url.standardizedFileURL

            if let existingTab = tabs.first(where: { $0.url == normalizedURL }) {
                selectedTabID = existingTab.id
                continue
            }

            let tab = DocumentTab(url: normalizedURL)
            tabs.append(tab)
            selectedTabID = tab.id
            render(tabID: tab.id)
        }
    }

    /// Returns false when there was nothing usable, so callers can beep.
    @discardableResult
    func open(_ content: IncomingContent) -> Bool {
        switch content {
        case .files(let urls):
            openFiles(urls)
        case .text(let text):
            do {
                openFiles([try ScratchDocumentStore.makeDocument(text: text)])
            } catch {
                NSAlert(error: error).runModal()
                return false
            }
        }

        return true
    }

    func pasteAsDocument() {
        guard let content = IncomingContent.read(from: .general, acceptingText: true), open(content) else {
            NSSound.beep()
            return
        }
    }

    /*
     * Files are resolved before text is considered. A Finder or Dock item's
     * provider often advertises only the file's own type, and Markdown
     * conforms to plain text, so loading it as a String returns the contents
     * and the drop would open as a scratch copy instead of the file itself.
     */
    func openDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else {
            return false
        }

        Task {
            var fileURLs: [URL] = []

            for provider in providers {
                if let url = await Self.loadFileURL(from: provider) {
                    fileURLs.append(url)
                }
            }

            var text: String?

            if fileURLs.isEmpty, let provider = providers.first(where: { $0.canLoadObject(ofClass: String.self) }) {
                text = await Self.loadText(from: provider)
            }

            if let content = IncomingContent.make(fileURLs: fileURLs, text: text) {
                open(content)
            } else {
                NSSound.beep()
            }
        }

        return true
    }

    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await loadURLItem(from: provider), url.isFileURL {
            return url
        }

        // Only an in-place representation is the original file; a copy would
        // live in a temporary directory that is deleted once loading returns.
        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .data) == true
        }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { url, isInPlace, _ in
                continuation.resume(returning: isInPlace ? url : nil)
            }
        }
    }

    private static func loadURLItem(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                continuation.resume(returning: data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) })
            }
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }

    func selectTab(_ tabID: DocumentTab.ID) {
        // Row taps can race a close on the same row; never point the selection
        // at a tab that is already gone or the preview would blank out.
        guard tabs.contains(where: { $0.id == tabID }) else {
            return
        }

        selectedTabID = tabID
    }

    func closeSelectedTab() {
        guard let selectedTabID else {
            return
        }

        closeTab(id: selectedTabID)
    }

    func closeTab(id: DocumentTab.ID) {
        renderTasks[id]?.cancel()
        renderTasks[id] = nil

        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return
        }

        let removedTab = tabs.remove(at: index)

        if removedTab.isTemporary {
            ScratchDocumentStore.remove(removedTab.url)
        }

        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = nextIndex >= 0 ? tabs[nextIndex].id : nil
        }
    }

    /// Tabs whose file diverged from what is currently rendered.
    var outdatedTabs: [DocumentTab] {
        tabs.filter(\.needsReloadPrompt)
    }

    /*
     * A refresh covers every open file that changed on disk, not just the
     * visible one, so switching tabs after a reload never shows stale content.
     * With nothing stale, it still re-renders the current tab so the command
     * is never a silent no-op.
     */
    @discardableResult
    func reloadOutdatedTabs() -> Int {
        let staleTabIDs = outdatedTabs.map(\.id)

        guard !staleTabIDs.isEmpty else {
            reloadSelectedTab()
            return 0
        }

        for tabID in staleTabIDs {
            render(tabID: tabID)
        }

        return staleTabIDs.count
    }

    func reloadAllTabs() {
        for tab in tabs {
            render(tabID: tab.id)
        }
    }

    func reloadSelectedTab() {
        guard let selectedTab else {
            return
        }

        render(tabID: selectedTab.id)
    }

    func revealSelectedInFinder() {
        guard let selectedTab else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([selectedTab.url])
    }

    func toggleZenMode() {
        isZenModeEnabled.toggle()
    }

    func toggleAutoReload() {
        setAutoReload(!isAutoReloadEnabled)
    }

    func setAutoReload(_ isEnabled: Bool) {
        isAutoReloadEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.autoReload)

        // Catch up on anything that went stale while it was off, but do not
        // force a pointless re-render when nothing did.
        if isEnabled, !outdatedTabs.isEmpty {
            reloadOutdatedTabs()
        }
    }

    func setZenMode(_ isEnabled: Bool) {
        isZenModeEnabled = isEnabled
    }

    func updateTableOfContents(_ items: [TableOfContentsItem], for tabID: DocumentTab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else {
            return
        }

        tab.updateTableOfContents(items)
    }

    func updateActiveHeading(_ headingID: String?, for tabID: DocumentTab.ID) {
        tabs.first(where: { $0.id == tabID })?.updateActiveHeading(headingID)
    }

    func updateScrollPosition(_ position: Double, for tabID: DocumentTab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else {
            return
        }

        tab.savedScrollPosition = position
    }

    func scrollSelectedTab(to anchorID: String) {
        selectedTab?.requestScroll(to: anchorID)
    }

    private func render(tabID: DocumentTab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else {
            return
        }

        tab.beginLoading()
        renderTasks[tabID]?.cancel()

        let url = tab.url

        let renderer = self.renderer

        renderTasks[tabID] = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                return
            }

            do {
                let rendered = try renderer.render(url: url)

                await MainActor.run {
                    guard let currentTab = self.tabs.first(where: { $0.id == tabID }) else {
                        return
                    }

                    currentTab.applyRender(
                        html: rendered.html,
                        bodyHTML: rendered.bodyHTML,
                        metadata: .init(
                            byteCount: rendered.byteCount,
                            lineCount: rendered.lineCount,
                            renderDuration: rendered.renderDuration
                        ),
                        fileVersion: rendered.fileVersion
                    )
                }
            } catch is CancellationError {
            } catch {
                let fileVersion = FileVersionSnapshot.capture(for: url)

                await MainActor.run {
                    guard let currentTab = self.tabs.first(where: { $0.id == tabID }) else {
                        return
                    }

                    currentTab.applyError(
                        error.localizedDescription,
                        fallbackHTML: PreviewTemplate.makeErrorHTML(
                            title: currentTab.title,
                            message: error.localizedDescription
                        ),
                        fileVersion: fileVersion
                    )
                }
            }

            await MainActor.run {
                self.renderTasks[tabID] = nil
            }
        }
    }

    private func startFileVersionMonitoring() {
        fileVersionMonitorTask?.cancel()

        fileVersionMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let probes = self.tabs.map { OpenTabProbe(id: $0.id, url: $0.url) }

                if !probes.isEmpty {
                    let snapshots = await Task.detached(priority: .utility) { () -> [DocumentTab.ID: FileVersionSnapshot] in
                        var results: [DocumentTab.ID: FileVersionSnapshot] = [:]
                        results.reserveCapacity(probes.count)

                        for probe in probes {
                            results[probe.id] = FileVersionSnapshot.capture(for: probe.url)
                        }

                        return results
                    }.value

                    self.applyFileVersionSnapshots(snapshots)
                }

                try? await Task.sleep(for: probes.isEmpty ? .seconds(2) : .seconds(1))
            }
        }
    }

    private func applyFileVersionSnapshots(_ snapshots: [DocumentTab.ID: FileVersionSnapshot]) {
        var tabIDsToReload: [DocumentTab.ID] = []

        for tab in tabs {
            guard let snapshot = snapshots[tab.id] else {
                continue
            }

            tab.updateFileSyncStatus(using: snapshot)

            if isAutoReloadEnabled, shouldAutoReload(tab, snapshot: snapshot) {
                tabIDsToReload.append(tab.id)
            }
        }

        for tabID in tabIDsToReload {
            render(tabID: tabID)
        }
    }

    private func shouldAutoReload(_ tab: DocumentTab, snapshot: FileVersionSnapshot) -> Bool {
        guard tab.fileSyncStatus == .changedOnDisk else {
            // A file that vanished keeps its last render and its badge; there is
            // nothing better to show, and it usually means a move in progress.
            return false
        }

        /*
         * Editors that truncate before writing leave a momentarily empty file.
         * Polling can land in that window, so an empty file where we previously
         * had content is treated as a save in flight and picked up next tick.
         */
        if snapshot.fileSize == 0, (tab.renderMetadata?.byteCount ?? 0) > 0 {
            return false
        }

        return true
    }
}
