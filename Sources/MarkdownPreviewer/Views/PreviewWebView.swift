import AppKit
import SwiftUI
import WebKit

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

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.allowsBackForwardNavigationGestures = false
            webView.setValue(false, forKey: "drawsBackground")
            webView.underPageBackgroundColor = .clear

            return webView
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
            webView.loadHTMLString(tab.renderedHTML ?? "", baseURL: tab.url.deletingLastPathComponent())
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

            if url.isFileURL, url.isMarkdownLike {
                await MainActor.run {
                    controller?.openFiles([url])
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
