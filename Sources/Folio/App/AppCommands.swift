import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var controller: AppController

    private var outdatedCount: Int {
        controller.outdatedTabs.count
    }

    private var reloadTitle: String {
        switch outdatedCount {
        case 0:
            return "Reload Current Tab"
        case 1:
            return "Reload 1 Changed File"
        default:
            return "Reload \(outdatedCount) Changed Files"
        }
    }

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

        /*
         * Nothing in this window takes text input, so ⌘V is free to mean "open
         * the clipboard". Copy and Select All still go down the responder
         * chain, where the preview's web view handles them.
         */
        CommandGroup(replacing: .pasteboard) {
            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button("Paste as New Document") {
                controller.pasteAsDocument()
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
        }

        CommandMenu("Preview") {
            Button(reloadTitle) {
                controller.reloadOutdatedTabs()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(controller.tabs.isEmpty)

            Button("Reload All Open Files") {
                controller.reloadAllTabs()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(controller.tabs.isEmpty)

            Button("Reveal in Finder") {
                controller.revealSelectedInFinder()
            }
            .disabled(controller.selectedTab == nil)

            Divider()

            Toggle("Reload Automatically on Save", isOn: Binding(
                get: { controller.isAutoReloadEnabled },
                set: { controller.setAutoReload($0) }
            ))

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
