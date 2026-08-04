import Foundation

extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let components = components
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }
}

extension TimeInterval {
    var formattedRenderTime: String {
        if self < 1 {
            return "\(Int((self * 1_000).rounded())) ms"
        }

        return String(format: "%.2f s", self)
    }
}
