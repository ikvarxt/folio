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

    static func collapsedIDs(
        in nodes: [TableOfContentsNode],
        preservingVisibleDepth visibleDepth: Int
    ) -> Set<String> {
        let deepestExpandedDepth = max(visibleDepth - 1, 0)

        func collect(from node: TableOfContentsNode, depth: Int) -> Set<String> {
            guard node.hasChildren else {
                return []
            }

            if depth >= deepestExpandedDepth {
                return [node.id]
            }

            return node.children.reduce(into: Set<String>()) { partial, child in
                partial.formUnion(collect(from: child, depth: depth + 1))
            }
        }

        return nodes.reduce(into: Set<String>()) { partial, node in
            partial.formUnion(collect(from: node, depth: 0))
        }
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
