import AppKit
import SwiftUI

struct TableOfContentsSidebarView: View {
    @ObservedObject var controller: AppController
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if let tab = controller.selectedTab {
                ObservedTOCShell(tab: tab, onSelect: onSelect)
            } else {
                OutlineShell {
                    OutlinePlaceholder(text: "Open a Markdown file to see its headings here.")
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Theme.sidebarSurface)
    }
}

private struct ObservedTOCShell: View {
    @ObservedObject var tab: DocumentTab
    let onSelect: (String) -> Void

    private let foldAnimation = Animation.easeOut(duration: 0.15)

    private var outlineTree: [TableOfContentsNode] {
        TableOfContentsNode.tree(from: tab.tableOfContents)
    }

    var body: some View {
        let tree = outlineTree
        let collapsed = tab.collapsedOutlineIDs
        let collapseAllIDs = TableOfContentsNode.collapseAllIDs(in: tree)
        let isFullyCollapsed = !collapseAllIDs.isEmpty && collapseAllIDs.isSubset(of: collapsed)
        let rows = TableOfContentsNode.visibleRows(in: tree, collapsedIDs: collapsed)
        let activeRowID = tab.activeHeadingID.flatMap {
            TableOfContentsNode.visibleRowID(for: $0, in: tree, collapsedIDs: collapsed)
        }

        OutlineShell(
            actions: {
                if !collapseAllIDs.isEmpty {
                    Button {
                        withAnimation(foldAnimation) {
                            tab.collapsedOutlineIDs = isFullyCollapsed ? [] : collapseAllIDs
                        }
                    } label: {
                        Image(systemName: isFullyCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    }
                    .buttonStyle(IconButtonStyle())
                    .help(isFullyCollapsed ? "Expand all headings" : "Collapse all headings")
                    .accessibilityLabel(isFullyCollapsed ? "Expand all headings" : "Collapse all headings")
                }
            },
            content: {
                if rows.isEmpty {
                    OutlinePlaceholder(text: "This document has no headings.")
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(rows) { row in
                                    TableOfContentsRowView(
                                        row: row,
                                        isActive: row.id == activeRowID,
                                        isCollapsed: collapsed.contains(row.id),
                                        onToggle: { recursive in toggle(row.node, recursive: recursive) },
                                        onSelect: { select(row.node) }
                                    )
                                    .id(row.id)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xxs)
                            .padding(.horizontal, Theme.Spacing.xs)
                        }
                        // Follow the reader: an anchor of nil scrolls only as far
                        // as needed, so the outline stays put while the row is on screen.
                        .onChange(of: activeRowID) { _, id in
                            guard let id else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(id)
                            }
                        }
                    }
                }
            }
        )
        .onChange(of: tab.tableOfContents.map(\.id), initial: true) {
            let valid = outlineTree.reduce(into: Set<String>()) { $0.formUnion($1.collapsibleIDs) }
            if !tab.collapsedOutlineIDs.isSubset(of: valid) {
                tab.collapsedOutlineIDs.formIntersection(valid)
            }
        }
    }

    /// Option-click folds or unfolds the whole subtree, as in Finder's list view.
    private func toggle(_ node: TableOfContentsNode, recursive: Bool) {
        let ids = recursive ? node.collapsibleIDs : [node.id]

        withAnimation(foldAnimation) {
            if tab.collapsedOutlineIDs.contains(node.id) {
                tab.collapsedOutlineIDs.subtract(ids)
            } else {
                tab.collapsedOutlineIDs.formUnion(ids)
            }
        }
    }

    // Jumping to a folded section opens it: the reader is headed there anyway.
    private func select(_ node: TableOfContentsNode) {
        withAnimation(foldAnimation) {
            _ = tab.collapsedOutlineIDs.remove(node.id)
        }
        onSelect(node.id)
    }
}

private struct OutlineShell<Actions: View, Content: View>: View {
    @ViewBuilder var actions: Actions
    @ViewBuilder var content: Content

    init(@ViewBuilder actions: () -> Actions = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.xs) {
                SidebarHeading("Outline")

                Spacer(minLength: Theme.Spacing.xs)

                actions
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xs)
            .frame(height: Theme.headerHeight)

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
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
    }
}

/*
 * Heading level is carried by indent plus type weight. An explicit "H2" badge
 * on every row triples the furniture without adding information the indent
 * does not already give.
 */
private struct TableOfContentsRowView: View {
    let row: TableOfContentsRow
    let isActive: Bool
    let isCollapsed: Bool
    let onToggle: (_ recursive: Bool) -> Void
    let onSelect: () -> Void

    @State private var isHovering = false

    private let disclosureWidth: CGFloat = 18
    private let indentPerLevel: CGFloat = 12
    // One line of 12pt text plus the title's vertical padding, so the chevron
    // centres on the first line when a title wraps.
    private let firstLineHeight: CGFloat = 25

    private var node: TableOfContentsNode {
        row.node
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
        HStack(alignment: .top, spacing: 0) {
            disclosure

            Text(node.item.title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)
        }
        .padding(.leading, CGFloat(row.depth) * indentPerLevel)
        .padding(.trailing, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(isHovering ? Theme.rowHover : .clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    // The whole gutter column is the hit target, not just the glyph.
    @ViewBuilder
    private var disclosure: some View {
        if node.hasChildren {
            Button {
                onToggle(NSEvent.modifierFlags.contains(.option))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isHovering ? Theme.inkSoft : Theme.mutedInk)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: disclosureWidth, height: firstLineHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Option-click to fold or unfold every level below")
            .accessibilityLabel(isCollapsed ? "Expand \(node.item.title)" : "Collapse \(node.item.title)")
        } else {
            Color.clear
                .frame(width: disclosureWidth, height: firstLineHeight)
        }
    }
}
