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

    @Published private(set) var tabs: [DocumentTab] = []
    @Published var selectedTabID: DocumentTab.ID?
    @Published private(set) var isZenModeEnabled = false

    private let renderer = MarkdownRenderer()
    private var renderTasks: [DocumentTab.ID: Task<Void, Never>] = [:]
    private var fileVersionMonitorTask: Task<Void, Never>?
    private var didLoadLaunchArguments = false

    private init() {
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

    func selectTab(_ tabID: DocumentTab.ID) {
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

        tabs.remove(at: index)

        if selectedTabID == id {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = nextIndex >= 0 ? tabs[nextIndex].id : nil
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

    func setZenMode(_ isEnabled: Bool) {
        isZenModeEnabled = isEnabled
    }

    func updateTableOfContents(_ items: [TableOfContentsItem], for tabID: DocumentTab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else {
            return
        }

        tab.updateTableOfContents(items)
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
        for tab in tabs {
            guard let snapshot = snapshots[tab.id] else {
                continue
            }

            tab.updateFileSyncStatus(using: snapshot)
        }
    }
}
