import Foundation

struct TableOfContentsItem: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let level: Int
}
