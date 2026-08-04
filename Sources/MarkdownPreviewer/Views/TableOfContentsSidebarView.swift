import SwiftUI

struct TableOfContentsSidebarView: View {
    @ObservedObject var controller: AppController
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if let tab = controller.selectedTab {
                ObservedTOCShell(tab: tab, onSelect: onSelect)
            } else {
                OutlineShell(subtitle: "No file open") {
                    OutlinePlaceholder(text: "Open a Markdown file to see its headings here.")
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarSurface)
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
        OutlineShell(
            subtitle: "\(tab.tableOfContents.count) heading\(tab.tableOfContents.count == 1 ? "" : "s")",
            actions: {
                if !collapsibleIDs.isEmpty {
                    Button {
                        collapsedNodeIDs.removeAll()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Expand all headings")
                    .accessibilityLabel("Expand all headings")

                    Button {
                        collapsedNodeIDs = TableOfContentsNode.collapsedIDs(
                            in: outlineTree,
                            preservingVisibleDepth: minimumVisibleDepthOnCollapseAll
                        )
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Collapse to the top two levels")
                    .accessibilityLabel("Collapse headings")
                }
            },
            content: {
                if tab.tableOfContents.isEmpty {
                    OutlinePlaceholder(text: "This document has no headings.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(outlineTree) { node in
                                TableOfContentsNodeRow(
                                    node: node,
                                    depth: 0,
                                    activeHeadingID: tab.activeHeadingID,
                                    collapsedNodeIDs: $collapsedNodeIDs,
                                    onSelect: onSelect
                                )
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        .padding(.horizontal, Theme.Spacing.xs)
                    }
                }
            }
        )
        .onAppear {
            collapsedNodeIDs = collapsedNodeIDs.intersection(collapsibleIDs)
        }
        .onChange(of: tab.tableOfContents.map(\.id), initial: false) {
            collapsedNodeIDs = collapsedNodeIDs.intersection(collapsibleIDs)
        }
    }
}

private struct OutlineShell<Actions: View, Content: View>: View {
    let subtitle: String
    @ViewBuilder var actions: Actions
    @ViewBuilder var content: Content

    init(subtitle: String, @ViewBuilder actions: () -> Actions = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.subtitle = subtitle
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Outline")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mutedInk)
                        .monospacedDigit()
                }

                Spacer(minLength: Theme.Spacing.xs)

                actions
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()
                .overlay(Theme.line)

            content

            Spacer(minLength: 0)
        }
    }
}

private struct OutlinePlaceholder: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
    }
}

/*
 * Heading level is carried by indent plus type weight. An explicit "H2" badge
 * on every row triples the furniture without adding information the indent
 * does not already give.
 */
private struct TableOfContentsNodeRow: View {
    let node: TableOfContentsNode
    let depth: Int
    let activeHeadingID: String?
    @Binding var collapsedNodeIDs: Set<String>
    let onSelect: (String) -> Void

    @State private var isHovering = false

    private let disclosureWidth: CGFloat = 14
    private let indentPerLevel: CGFloat = 11

    private var isCollapsed: Bool {
        collapsedNodeIDs.contains(node.id)
    }

    private var isActive: Bool {
        node.id == activeHeadingID
    }

    private var titleFont: Font {
        switch node.item.level {
        case 1:
            return .system(size: 12, weight: .semibold)
        case 2:
            return .system(size: 12, weight: .medium)
        default:
            return .system(size: 11)
        }
    }

    private var titleColor: Color {
        if isActive {
            return Theme.accent
        }

        switch node.item.level {
        case 1, 2:
            return Theme.ink
        case 3:
            return Theme.inkSoft
        default:
            return Theme.mutedInk
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs) {
                if node.hasChildren {
                    Button(action: toggleCollapsed) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.mutedInk)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .frame(width: disclosureWidth, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(isCollapsed ? "Expand \(node.item.title)" : "Collapse \(node.item.title)")
                } else {
                    // Fixed placeholder, not a Spacer: a Spacer in an HStack
                    // still negotiates width and leaves childless rows a few
                    // points off the rows that do have a chevron.
                    Color.clear
                        .frame(width: disclosureWidth, height: 14)
                }

                Text(node.item.title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, Theme.Spacing.xs + CGFloat(depth) * indentPerLevel)
            .padding(.trailing, Theme.Spacing.xs)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(rowFill)
            )
            // Same thin rail the file list uses for its selection, so "where I
            // am" reads the same way in both sidebars.
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: 2)
                        .padding(.vertical, 3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(node.id)
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.15), value: isActive)

            if node.hasChildren, !isCollapsed {
                ForEach(node.children) { child in
                    TableOfContentsNodeRow(
                        node: child,
                        depth: depth + 1,
                        activeHeadingID: activeHeadingID,
                        collapsedNodeIDs: $collapsedNodeIDs,
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    private var rowFill: Color {
        if isActive {
            return Theme.accentSoft.opacity(0.6)
        }

        return isHovering ? Theme.rowHover : .clear
    }

    private func toggleCollapsed() {
        if isCollapsed {
            collapsedNodeIDs.remove(node.id)
        } else {
            collapsedNodeIDs.insert(node.id)
        }
    }
}
