import SwiftUI

struct TabSidebarView: View {
    @ObservedObject var controller: AppController

    private var outdatedCount: Int {
        controller.outdatedTabs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Theme.line)

            if controller.tabs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(controller.tabs) { tab in
                            TabRowView(
                                tab: tab,
                                isSelected: controller.selectedTabID == tab.id,
                                onSelect: { controller.selectTab(tab.id) },
                                onClose: { controller.closeTab(id: tab.id) }
                            )
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .padding(.horizontal, Theme.Spacing.xs)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarSurface)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Open files")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundStyle(outdatedCount > 0 ? Theme.signalChanged : Theme.mutedInk)
                    .monospacedDigit()
            }

            Spacer(minLength: Theme.Spacing.xs)

            if outdatedCount > 0 {
                Button(action: { controller.reloadOutdatedTabs() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(IconButtonStyle(isProminent: true, tint: Theme.signalChanged))
                .help("Reload the \(outdatedCount == 1 ? "file" : "\(outdatedCount) files") that changed on disk (⌘R)")
                .accessibilityLabel("Reload changed files")
            }

            Button(action: controller.openPanel) {
                Image(systemName: "plus")
            }
            .buttonStyle(IconButtonStyle())
            .help("Open Markdown files (⌘O)")
            .accessibilityLabel("Open Markdown files")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var subtitleText: String {
        let tabCount = controller.tabs.count
        let base = "\(tabCount) file\(tabCount == 1 ? "" : "s")"

        guard outdatedCount > 0 else {
            return base
        }

        return "\(base) · \(outdatedCount) changed"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Nothing open")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Press ⌘O, or drop a Markdown file on the app icon. Reopening a file focuses its tab instead of duplicating it.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
    }
}

private struct TabRowView: View {
    @ObservedObject var tab: DocumentTab

    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(rowFill)

            // Thin rail rather than a filled block: keeps a dense file list
            // readable while still marking the active document.
            if isSelected {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 2)
                    .padding(.vertical, Theme.Spacing.xs)
            }

            HStack(spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(tab.title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if tab.needsReloadPrompt {
                            FileSyncIndicatorLight(status: tab.fileSyncStatus, size: 6)
                        }
                    }

                    Text(tab.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mutedInk)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Reserve the slot always so the label never reflows on hover.
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.mutedInk)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .help("Close tab (⌘W)")
                .accessibilityLabel("Close \(tab.title)")
                .opacity(isHovering || isSelected ? 1 : 0)
            }
            .padding(.leading, Theme.Spacing.sm)
            .padding(.trailing, Theme.Spacing.xxs)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var rowFill: Color {
        if isSelected {
            return Theme.accentSoft
        }

        return isHovering ? Theme.rowHover : .clear
    }
}
