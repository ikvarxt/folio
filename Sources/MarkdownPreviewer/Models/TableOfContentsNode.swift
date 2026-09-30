import Foundation

struct TableOfContentsNode: Identifiable, Equatable {
    let item: TableOfContentsItem
    var children: [TableOfContentsNode]

    var id: String { item.id }

    var hasChildren: Bool {
        !children.isEmpty
    }

    var collapsibleIDs: Set<String> {
        var ids = Set<String>()

        if hasChildren {
            ids.insert(id)
        }

        for child in children {
            ids.formUnion(child.collapsibleIDs)
        }

        return ids
    }

    /*
     * Everything collapsed except a chain of lone roots: a document with one H1
     * over the rest would otherwise collapse to a single row, which hides the
     * outline instead of summarising it.
     */
    static func collapseAllIDs(in nodes: [TableOfContentsNode]) -> Set<String> {
        var ids = nodes.reduce(into: Set<String>()) { $0.formUnion($1.collapsibleIDs) }
        var level = nodes

        while level.count == 1, let only = level.first, only.hasChildren {
            ids.remove(only.id)
            level = only.children
        }

        return ids
    }

    static func visibleRows(
        in nodes: [TableOfContentsNode],
        collapsedIDs: Set<String>
    ) -> [TableOfContentsRow] {
        var rows: [TableOfContentsRow] = []

        func visit(_ node: TableOfContentsNode, depth: Int) {
            rows.append(TableOfContentsRow(node: node, depth: depth))

            guard !collapsedIDs.contains(node.id) else {
                return
            }

            for child in node.children {
                visit(child, depth: depth + 1)
            }
        }

        for node in nodes {
            visit(node, depth: 0)
        }

        return rows
    }

    /// The row that stands in for `id`: itself when visible, otherwise the
    /// ancestor whose collapse is hiding it.
    static func visibleRowID(
        for id: String,
        in nodes: [TableOfContentsNode],
        collapsedIDs: Set<String>
    ) -> String? {
        func path(in nodes: [TableOfContentsNode]) -> [TableOfContentsNode]? {
            for node in nodes {
                if node.id == id {
                    return [node]
                }

                if let rest = path(in: node.children) {
                    return [node] + rest
                }
            }

            return nil
        }

        guard let path = path(in: nodes) else {
            return nil
        }

        return path.first(where: { collapsedIDs.contains($0.id) })?.id ?? id
    }

    static func tree(from items: [TableOfContentsItem]) -> [TableOfContentsNode] {
        final class MutableNode {
            let item: TableOfContentsItem
            var children: [MutableNode] = []

            init(item: TableOfContentsItem) {
                self.item = item
            }
        }

        func freeze(_ node: MutableNode) -> TableOfContentsNode {
            TableOfContentsNode(
                item: node.item,
                children: node.children.map(freeze)
            )
        }

        var roots: [MutableNode] = []
        var stack: [MutableNode] = []

        for item in items {
            let node = MutableNode(item: item)

            while let last = stack.last, last.item.level >= item.level {
                stack.removeLast()
            }

            if let parent = stack.last {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            stack.append(node)
        }

        return roots.map(freeze)
    }
}

struct TableOfContentsRow: Identifiable, Equatable {
    let node: TableOfContentsNode
    let depth: Int

    var id: String { node.id }
}
