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
    private let minimumVisibleDepthOnCollapseAll = 2

    @ObservedObject var tab: DocumentTab
    let onSelect: (String) -> Void
    @State private var collapsedNodeIDs: Set<String> = []

    private var outlineTree: [TableOfContentsNode] {
        TableOfContentsNode.tree(from: tab.tableOfContents)
    }

    private var collapsibleIDs: Set<String> {
        outlineTree.reduce(into: Set<String>()) { partial, node in
            partial.formUnion(node.collapsibleIDs)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outline")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("\(tab.tableOfContents.count) entries")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mutedInk)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button("Expand all") {
                        collapsedNodeIDs.removeAll()
                    }
                    .buttonStyle(OutlineActionButtonStyle())
                    .disabled(collapsibleIDs.isEmpty)

                    Button("Collapse all") {
                        collapsedNodeIDs = TableOfContentsNode.collapsedIDs(
                            in: outlineTree,
                            preservingVisibleDepth: minimumVisibleDepthOnCollapseAll
                        )
                    }
                    .buttonStyle(OutlineActionButtonStyle())
                    .disabled(collapsibleIDs.isEmpty)
                }
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
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(outlineTree) { node in
                            TableOfContentsNodeRow(
                                node: node,
                                depth: 0,
                                collapsedNodeIDs: $collapsedNodeIDs,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            collapsedNodeIDs = collapsedNodeIDs.intersection(collapsibleIDs)
        }
        .onChange(of: tab.tableOfContents.map(\.id), initial: false) {
            collapsedNodeIDs = collapsedNodeIDs.intersection(collapsibleIDs)
        }
    }
}

private struct TableOfContentsNodeRow: View {
    let node: TableOfContentsNode
    let depth: Int
    @Binding var collapsedNodeIDs: Set<String>
    let onSelect: (String) -> Void

    private var isCollapsed: Bool {
        collapsedNodeIDs.contains(node.id)
    }

    private var levelColor: Color {
        switch node.item.level {
        case 1:
            return Theme.accent
        case 2:
            return Theme.accent.opacity(0.82)
        case 3:
            return Theme.accent.opacity(0.64)
        default:
            return Theme.line.opacity(0.95)
        }
    }

    private var rowBackground: Color {
        depth == 0 ? Theme.panelSurface : Theme.panelSurface.opacity(0.76)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if node.hasChildren {
                    Button(action: toggleCollapsed) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.mutedInk)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                } else {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(levelColor.opacity(0.32))
                        .frame(width: 6, height: 6)
                        .frame(width: 16, height: 16)
                }

                Text("H\(node.item.level)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(levelColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(levelColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))

                Button(action: { onSelect(node.id) }) {
                    Text(node.item.title)
                        .font(.system(size: 12, weight: node.item.level <= 2 ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.line.opacity(0.5), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(levelColor)
                    .frame(width: depth == 0 ? 3 : 2)
                    .padding(.vertical, 10)
                    .padding(.leading, 8 + CGFloat(depth) * 16)
            }

            if node.hasChildren, !isCollapsed {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(node.children) { child in
                        TableOfContentsNodeRow(
                            node: child,
                            depth: depth + 1,
                            collapsedNodeIDs: $collapsedNodeIDs,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
    }

    private func toggleCollapsed() {
        if isCollapsed {
            collapsedNodeIDs.remove(node.id)
        } else {
            collapsedNodeIDs.insert(node.id)
        }
    }
}

private struct OutlineActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.panelSurface.opacity(configuration.isPressed ? 0.92 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.line.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
