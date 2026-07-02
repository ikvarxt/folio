import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var controller: AppController

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Markdown Files…") {
                controller.openPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        CommandMenu("Preview") {
            Button("Reload Current Tab") {
                controller.reloadSelectedTab()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(controller.selectedTab == nil)

            Button("Reveal in Finder") {
                controller.revealSelectedInFinder()
            }
            .disabled(controller.selectedTab == nil)

            Divider()

            Button("Close Current Tab") {
                controller.closeSelectedTab()
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(controller.selectedTab == nil)
        }
    }
}
