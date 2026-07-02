import SwiftUI

struct TabSidebarView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Open files")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("\(controller.tabs.count) tab\(controller.tabs.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mutedInk)
                }

                Spacer()

                Button(action: controller.openPanel) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 30)
                        .background(Theme.panelSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.line.opacity(0.75), lineWidth: 1)
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
                .help("Open Markdown files")
            }
            .padding(20)

            Divider()
                .overlay(Theme.line)

            if controller.tabs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No files yet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Use Command-O to open one or more Markdown files. Already-open files are focused instead of duplicated.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(controller.tabs) { tab in
                            TabRowView(
                                tab: tab,
                                isSelected: controller.selectedTabID == tab.id,
                                onSelect: { controller.selectTab(tab.id) },
                                onClose: { controller.closeTab(id: tab.id) }
                            )
                        }
                    }
                    .padding(12)
                }
            }

            Divider()
                .overlay(Theme.line)

            Button(action: controller.openPanel) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                    Text("Open files")
                    Spacer()
                    Text("⌘O")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mutedInk)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarSurface)
    }
}

private struct TabRowView: View {
    @ObservedObject var tab: DocumentTab

    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)

                        if tab.needsReloadPrompt {
                            FileSyncIndicatorLight(status: tab.fileSyncStatus)
                        }
                    }
                    Text(tab.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mutedInk)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Theme.accentSoft : Theme.panelSurface.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Theme.accent.opacity(0.32) : Theme.line.opacity(0.55), lineWidth: 1)
                )
            }
            .buttonStyle(PressScaleButtonStyle())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mutedInk)
                    .frame(width: 28, height: 28)
                    .background(Theme.panelSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.line.opacity(0.65), lineWidth: 1)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .help("Close tab")
        }
    }
}
