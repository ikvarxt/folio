import AppKit
import SwiftUI
import WebKit

/*
 * WebKit re-evaluates prefers-color-scheme when the appearance is inherited
 * from the window, but dispatches no matchMedia change event on that path, so
 * page scripts never learn the scheme moved. CSS therefore switches on its own
 * and Mermaid, whose colours are baked into generated SVG, does not. The host
 * hands that signal over instead.
 */
final class AppearanceAwareWebView: WKWebView {
    var onEffectiveAppearanceChange: ((Bool) -> Void)?
    var onDropTargetChange: ((Bool) -> Void)?
    var onDrop: ((IncomingContent) -> Void)?

    private var pendingDrop: IncomingContent?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()

        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        onEffectiveAppearanceChange?(isDark)
    }

    /*
     * WebKit's own drop handling navigates the view to a dropped file, which
     * would replace the preview with the raw source. Drops the app can open are
     * taken here instead; anything else still goes to WebKit. Text only counts
     * when it comes from another app, so dragging a selection within the page
     * does not spawn a document.
     */
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pendingDrop = IncomingContent.read(
            from: sender.draggingPasteboard,
            acceptingText: sender.draggingSource == nil
        )

        guard pendingDrop != nil else {
            return super.draggingEntered(sender)
        }

        onDropTargetChange?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        pendingDrop != nil ? .copy : super.draggingUpdated(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        guard pendingDrop != nil else {
            super.draggingExited(sender)
            return
        }

        pendingDrop = nil
        onDropTargetChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        pendingDrop != nil || super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let content = pendingDrop else {
            return super.performDragOperation(sender)
        }

        onDropTargetChange?(false)
        onDrop?(content)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        guard pendingDrop != nil else {
            super.concludeDragOperation(sender)
            return
        }

        pendingDrop = nil
    }
}

struct PreviewWebView: NSViewRepresentable {
    @ObservedObject var controller: AppController
    @ObservedObject var tab: DocumentTab

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.controller = controller
        context.coordinator.sync(with: tab, webView: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var controller: AppController?

        private var currentTabID: DocumentTab.ID?
        private var currentRevision: Int = -1
        private var isPageLoaded = false
        private var pendingRestoreScroll: Double?
        private var lastScrollRequestToken: UUID?
        private var contentUpdate: Task<Void, Never>?

        init(controller: AppController) {
            self.controller = controller
        }

        deinit {
            contentUpdate?.cancel()
        }

        func makeWebView() -> WKWebView {
            let userContentController = WKUserContentController()
            userContentController.add(self, name: "tableOfContents")
            userContentController.add(self, name: "scrollState")
            userContentController.add(self, name: "activeHeading")

            let mermaidScript = WKUserScript(
                source: PreviewTemplate.resourceText(named: "mermaid.min", ext: "js", subdirectory: "Vendor"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )

            let highlightScript = WKUserScript(
                source: PreviewTemplate.resourceText(named: "highlight", ext: "js", subdirectory: "Vendor"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )

            let bridgeScript = WKUserScript(
                source: PreviewTemplate.resourceText(named: "preview", ext: "js", subdirectory: "Preview"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )

            userContentController.addUserScript(mermaidScript)
            userContentController.addUserScript(highlightScript)
            userContentController.addUserScript(bridgeScript)

            let configuration = WKWebViewConfiguration()
            configuration.userContentController = userContentController
            configuration.setURLSchemeHandler(LocalFileSchemeHandler(), forURLScheme: LocalFileSchemeHandler.scheme)

            let webView = AppearanceAwareWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            webView.setValue(false, forKey: "drawsBackground")
            webView.underPageBackgroundColor = .clear
            webView.onEffectiveAppearanceChange = { [weak webView] isDark in
                guard let webView else {
                    return
                }

                Self.applyColorScheme(isDark: isDark, on: webView)
            }
            webView.onDropTargetChange = { [weak self] isTargeted in
                self?.controller?.isDropTargeted = isTargeted
            }
            webView.onDrop = { [weak self] content in
                self?.controller?.open(content)
            }

            return webView
        }

        /*
         * Fire and forget: the call is a no-op before the first document loads,
         * and the page picks the right palette from the media query on its own
         * when it does. Only a later switch needs telling.
         */
        private static func applyColorScheme(isDark: Bool, on webView: WKWebView) {
            webView.callAsyncJavaScript(
                "window.markdownPreview?.applyColorScheme(isDark);",
                arguments: ["isDark": isDark],
                in: nil,
                in: .page,
                completionHandler: nil
            )
        }

        func sync(with tab: DocumentTab?, webView: WKWebView) {
            guard let tab else {
                contentUpdate?.cancel()
                contentUpdate = nil
                currentTabID = nil
                currentRevision = -1
                isPageLoaded = false
                webView.loadHTMLString("", baseURL: nil)
                return
            }

            if currentTabID != tab.id {
                loadWholePage(for: tab, webView: webView)
                return
            }

            if currentRevision != tab.renderRevision {
                currentRevision = tab.renderRevision

                /*
                 * Same document, new content: swap the body in place. Reloading
                 * the page here would white-flash, throw away the reading
                 * position, and re-run Mermaid and highlight.js from scratch.
                 */
                if isPageLoaded, let bodyHTML = tab.renderedBodyHTML {
                    replaceBody(bodyHTML, for: tab, webView: webView)
                } else {
                    loadWholePage(for: tab, webView: webView)
                }

                return
            }

            if let request = tab.scrollRequest, request.token != lastScrollRequestToken {
                lastScrollRequestToken = request.token
                scroll(to: request.anchorID, webView: webView)
            }
        }

        private func loadWholePage(for tab: DocumentTab, webView: WKWebView) {
            contentUpdate?.cancel()
            contentUpdate = nil

            currentTabID = tab.id
            currentRevision = tab.renderRevision
            isPageLoaded = false
            pendingRestoreScroll = tab.savedScrollPosition
            lastScrollRequestToken = nil
            webView.loadHTMLString(
                tab.renderedHTML ?? "",
                baseURL: LocalFileSchemeHandler.url(for: tab.url.deletingLastPathComponent())
            )
        }

        private func replaceBody(_ bodyHTML: String, for tab: DocumentTab, webView: WKWebView) {
            contentUpdate?.cancel()

            contentUpdate = Task { [weak self, weak webView] in
                guard let webView else {
                    return
                }

                let didReplace = await Self.callReplaceBody(bodyHTML, on: webView)

                guard !Task.isCancelled, let self else {
                    return
                }

                // Any failure falls back to a plain reload rather than leaving
                // the previous document on screen.
                if !didReplace {
                    self.loadWholePage(for: tab, webView: webView)
                }
            }
        }

        /*
         * bodyHTML travels as a call argument rather than interpolated into a
         * script string, so no amount of backticks, quotes, or backslashes in
         * the document can break out of it.
         */
        private static func callReplaceBody(_ bodyHTML: String, on webView: WKWebView) async -> Bool {
            do {
                let result = try await webView.callAsyncJavaScript(
                    """
                    return await Promise.race([
                        window.markdownPreview.replaceBody(bodyHTML),
                        new Promise((resolve) => setTimeout(() => resolve(false), timeoutMs)),
                    ]);
                    """,
                    arguments: [
                        "bodyHTML": bodyHTML,
                        // Backstop in case a future edit reintroduces an await
                        // that cannot settle; a reload is better than stale text.
                        "timeoutMs": 8000,
                    ],
                    in: nil,
                    contentWorld: .page
                )

                return (result as? Bool) == true
            } catch {
                return false
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let tabID = currentTabID else {
                return
            }

            switch message.name {
            case "tableOfContents":
                if let payload = message.body as? String,
                   let data = payload.data(using: .utf8),
                   let items = try? JSONDecoder().decode([TableOfContentsItem].self, from: data) {
                    controller?.updateTableOfContents(items, for: tabID)
                }
            case "scrollState":
                if let payload = message.body as? String,
                   let position = Double(payload) {
                    controller?.updateScrollPosition(position, for: tabID)
                }
            case "activeHeading":
                controller?.updateActiveHeading(message.body as? String, for: tabID)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true

            guard let position = pendingRestoreScroll, position > 0 else {
                return
            }

            pendingRestoreScroll = nil
            webView.evaluateJavaScript("window.markdownPreview?.restoreScroll(\(position));")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                return .allow
            }

            if url.isSameDocumentAnchor(as: navigationAction.sourceFrame.request.url) {
                return .allow
            }

            // Relative links resolve against the base URL, so local ones arrive
            // on the preview scheme rather than as file URLs.
            if let fileURL = LocalFileSchemeHandler.fileURL(for: url) ?? (url.isFileURL ? url : nil) {
                if fileURL.isMarkdownLike {
                    await MainActor.run {
                        controller?.openFiles([fileURL])
                    }
                } else {
                    NSWorkspace.shared.open(fileURL)
                }
                return .cancel
            }

            if let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
                NSWorkspace.shared.open(url)
                return .cancel
            }

            return .allow
        }

        private func scroll(to anchorID: String, webView: WKWebView) {
            webView.callAsyncJavaScript(
                "window.markdownPreview?.scrollToHeading(anchorID);",
                arguments: ["anchorID": anchorID],
                in: nil,
                in: .page,
                completionHandler: nil
            )
        }
    }
}
