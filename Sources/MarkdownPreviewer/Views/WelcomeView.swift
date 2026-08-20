import SwiftUI

/*
 * Utility empty state, not a landing page: name the app, offer the one action
 * that gets you out of here, and list the two shortcuts worth knowing.
 */
struct WelcomeView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Markdown Previewer")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Open a file to start reading.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.mutedInk)

            Button(action: openAction) {
                Text("Open files…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.accent)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.top, Theme.Spacing.xxs)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ShortcutRow(keys: "⌘O", detail: "Open one or more files")
                ShortcutRow(keys: "⌘R", detail: "Reload every open file that changed on disk")
                ShortcutRow(keys: "⌘Z", detail: "Hide both sidebars")
            }
            .padding(.top, Theme.Spacing.sm)
        }
        .frame(maxWidth: 380, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panelSurface)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(keys)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 26, alignment: .leading)

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
