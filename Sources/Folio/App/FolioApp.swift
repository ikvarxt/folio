import SwiftUI

@main
struct FolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        /*
         * `Window`, not `WindowGroup`: documents live in this app's own tab
         * sidebar, so a second window can only ever be a duplicate of the first.
         * A WindowGroup spawns one window per file-open event, and because the
         * controller is a singleton every one of them renders identical content.
         */
        Window("Folio", id: "main") {
            RootView(controller: controller)
        }
        .commands {
            AppCommands(controller: controller)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
