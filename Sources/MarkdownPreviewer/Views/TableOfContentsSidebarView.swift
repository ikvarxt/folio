import SwiftUI

struct TableOfContentsSidebarView: View {
    @ObservedObject var controller: AppController
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if let tab = controller.selectedTab {
                ObservedTOCShell(tab: tab, onSelect: onSelect)
            } else {
                EmptyTOCShell()
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarSurface.opacity(0.88))
    }
}

private struct ObservedTOCShell: View {
    @ObservedObject var tab: DocumentTab
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Outline")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("\(tab.tableOfContents.count) entries")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mutedInk)
            }
            .padding(20)

            Divider()
                .overlay(Theme.line)

            if tab.tableOfContents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No headings yet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Headings from the current document appear here after the preview finishes rendering.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)

                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(tab.tableOfContents) { item in
                            Button(action: { onSelect(item.id) }) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: item.level <= 2 ? .semibold : .medium))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .padding(.leading, CGFloat(max(0, item.level - 1)) * 14)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Theme.panelSurface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Theme.line.opacity(0.55), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(12)
                }
            }
        }
    }
}

private struct EmptyTOCShell: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Outline")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Waiting for a file")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.mutedInk)
            }
            .padding(20)

            Divider()
                .overlay(Theme.line)

            VStack(alignment: .leading, spacing: 10) {
                Text("No headings yet")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Headings from the current document appear here after the preview finishes rendering.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            Spacer()
        }
    }
}
