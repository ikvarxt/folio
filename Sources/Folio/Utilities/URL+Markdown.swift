import Foundation

extension URL {
    var isMarkdownLike: Bool {
        let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "txt"]
        return markdownExtensions.contains(pathExtension.lowercased())
    }

    var tildePath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    func isSameDocumentAnchor(as other: URL?) -> Bool {
        guard let other else {
            return false
        }

        guard var lhsComponents = URLComponents(url: self, resolvingAgainstBaseURL: false),
              var rhsComponents = URLComponents(url: other, resolvingAgainstBaseURL: false) else {
            return false
        }

        lhsComponents.fragment = nil
        rhsComponents.fragment = nil

        return lhsComponents.string == rhsComponents.string && fragment != nil
    }
}
