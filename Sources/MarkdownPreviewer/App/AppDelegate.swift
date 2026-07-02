import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }

        Task { @MainActor in
            AppController.shared.openFiles(urls)
            sender.reply(toOpenOrPrint: .success)
        }
    }
}
