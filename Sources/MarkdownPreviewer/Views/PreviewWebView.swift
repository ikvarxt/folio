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
        private var pendingRestoreScroll: Double?
        private var lastScrollRequestToken: UUID?

        init(controller: AppController) {
            self.controller = controller
        }

        func makeWebView() -> WKWebView {
            let userContentController = WKUserContentController()
            userContentController.add(self, name: "tableOfContents")
            userContentController.add(self, name: "scrollState")

            let mermaidScript = WKUserScript(
                source: PreviewTemplate.resourceText(named: "mermaid.min", ext: "js", subdirectory: "Vendor"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )

            let bridgeScript = WKUserScript(
                source: PreviewTemplate.resourceText(named: "preview", ext: "js", subdirectory: "Preview"),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )

            userContentController.addUserScript(mermaidScript)
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
                currentTabID = nil
                currentRevision = -1
                webView.loadHTMLString("", baseURL: nil)
                return
            }

            if currentTabID != tab.id || currentRevision != tab.renderRevision {
                currentTabID = tab.id
                currentRevision = tab.renderRevision
                pendingRestoreScroll = tab.savedScrollPosition
                lastScrollRequestToken = nil
                webView.loadHTMLString(tab.renderedHTML ?? "", baseURL: tab.url.deletingLastPathComponent())
                return
            }

            if let request = tab.scrollRequest, request.token != lastScrollRequestToken {
                lastScrollRequestToken = request.token
                scroll(to: request.anchorID, webView: webView)
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
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
            let escapedAnchor = anchorID
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            webView.evaluateJavaScript("window.markdownPreview?.scrollToHeading('\(escapedAnchor)');")
        }
    }
}
