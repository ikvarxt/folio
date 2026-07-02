import SwiftUI

@main
struct MarkdownPreviewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        WindowGroup("Markdown Previewer") {
            RootView(controller: controller)
        }
        .commands {
            AppCommands(controller: controller)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
