import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /*
     * Finder hands files over through an Apple Event, not argv, and a
     * SwiftUI-lifecycle app never receives the legacy
     * application(_:openFiles:) callback. Implementing only that one meant
     * double-click, Open With, and dropping a file on the icon all launched the
     * app with an empty window. application(_:open:) is the callback SwiftUI
     * actually forwards, so it is the one that has to be here.
     */
    func application(_ sender: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            AppController.shared.openFiles(urls)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScratchDocumentStore.removeAll()
    }
}
