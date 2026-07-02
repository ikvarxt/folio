import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var controller: AppController

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(controller.isZenModeEnabled ? "Exit Zen Mode" : "Enter Zen Mode") {
                controller.toggleZenMode()
            }
            .keyboardShortcut("z", modifiers: [.command])
        }

        CommandGroup(after: .newItem) {
            Button("Open Markdown Files…") {
                controller.openPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        CommandMenu("Preview") {
            Button(controller.selectedTab?.needsReloadPrompt == true ? "Reload Updated File" : "Reload Current Tab") {
                controller.reloadSelectedTab()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(controller.selectedTab == nil)

            Button("Reveal in Finder") {
                controller.revealSelectedInFinder()
            }
            .disabled(controller.selectedTab == nil)

            Divider()

            Button(controller.isZenModeEnabled ? "Exit Zen Mode" : "Enter Zen Mode") {
                controller.toggleZenMode()
            }

            Divider()

            Button("Close Current Tab") {
                controller.closeSelectedTab()
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(controller.selectedTab == nil)
        }
    }
}
