import SwiftUI

struct TabSidebarView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        VStack(spacing: 0) {
            header

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
            SidebarHeading("Open files")

            Spacer(minLength: Theme.Spacing.xs)

            Button(action: controller.openPanel) {
                Image(systemName: "plus")
            }
            .buttonStyle(IconButtonStyle())
            .help("Open Markdown files (⌘O)")
            .accessibilityLabel("Open Markdown files")
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.xs)
        .frame(height: Theme.headerHeight)
    }

    private var emptyState: some View {
        Text("No files open")
            .font(.system(size: 11))
            .foregroundStyle(Theme.mutedInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
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

            HStack(spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(tab.title)
                            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
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
            return Theme.rowSelected
        }

        return isHovering ? Theme.rowHover : .clear
    }
}
