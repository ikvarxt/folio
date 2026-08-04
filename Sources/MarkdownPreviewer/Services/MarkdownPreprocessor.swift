import Down
import Foundation

struct MarkdownPreprocessor {
    private struct Fence {
        let character: Character
        let count: Int
    }

    private enum ColumnAlignment: String {
        case left
        case center
        case right

        var styleAttribute: String {
            " style=\"text-align: \(rawValue);\""
        }
    }

    func preprocess(_ markdown: String) throws -> String {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var output: [String] = []
        var index = 0
        var activeFence: Fence?

        while index < lines.count {
            let line = lines[index]

            if let fence = fenceMarker(for: line) {
                if let currentFence = activeFence {
                    if currentFence.character == fence.character, fence.count >= currentFence.count {
                        activeFence = nil
                    }
                } else {
                    activeFence = fence
                }

                output.append(line)
                index += 1
                continue
            }

            if activeFence == nil, let tableMatch = try parseTable(from: lines, startIndex: index) {
                output.append(tableMatch.html)
                index = tableMatch.nextIndex
                continue
            }

            output.append(activeFence == nil ? applyStrikethrough(to: line) : line)
            index += 1
        }

        return output.joined(separator: "\n")
    }

    /*
     * cmark ships without the GFM strikethrough extension, so "~~text~~" would
     * otherwise reach the preview as literal tildes. Rewrite it to <del> here,
     * the same place pipe tables are already desugared.
     *
     * Inline code spans are stepped over so "`a ~~ b`" survives untouched.
     * Indented (non-fenced) code blocks are not tracked, matching the existing
     * limitation of the table parser above.
     */
    func applyStrikethrough(to line: String) -> String {
        guard line.contains("~~") else {
            return line
        }

        var output = ""
        var plainSegment = ""
        var activeCodeSpan: Int?
        var index = line.startIndex

        while index < line.endIndex {
            guard line[index] == "`" else {
                if activeCodeSpan == nil {
                    plainSegment.append(line[index])
                } else {
                    output.append(line[index])
                }

                index = line.index(after: index)
                continue
            }

            let backtickRun = line[index...].prefix { $0 == "`" }

            if let openLength = activeCodeSpan {
                if backtickRun.count == openLength {
                    activeCodeSpan = nil
                }
            } else {
                output += strikethroughApplied(to: plainSegment)
                plainSegment = ""
                activeCodeSpan = backtickRun.count
            }

            output += backtickRun
            index = line.index(index, offsetBy: backtickRun.count)
        }

        return output + strikethroughApplied(to: plainSegment)
    }

    private func strikethroughApplied(to text: String) -> String {
        let segments = text.components(separatedBy: "~~")

        guard segments.count >= 3 else {
            return text
        }

        var result = segments[0]
        var segmentIndex = 1

        while segmentIndex < segments.count {
            let isClosed = segmentIndex + 1 < segments.count

            if isClosed, !segments[segmentIndex].isEmpty {
                result += "<del>\(segments[segmentIndex])</del>"
                result += segments[segmentIndex + 1]
                segmentIndex += 2
            } else {
                result += "~~\(segments[segmentIndex])"
                segmentIndex += 1
            }
        }

        return result
    }

    private func parseTable(from lines: [String], startIndex: Int) throws -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count,
              let headerCells = parseRow(lines[startIndex]),
              let alignments = parseAlignmentRow(lines[startIndex + 1]),
              headerCells.count == alignments.count else {
            return nil
        }

        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count, let rowCells = parseRow(lines[index]), rowCells.count == headerCells.count {
            rows.append(rowCells)
            index += 1
        }

        let html = try renderTableHTML(headers: headerCells, alignments: alignments, rows: rows)
        return (html, index)
    }

    private func parseRow(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|"), !trimmed.isEmpty else {
            return nil
        }

        var working = trimmed
        if working.hasPrefix("|") {
            working.removeFirst()
        }
        if working.hasSuffix("|") {
            working.removeLast()
        }

        let cells = working
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return cells.count >= 2 ? cells : nil
    }

    private func parseAlignmentRow(_ line: String) -> [ColumnAlignment]? {
        guard let cells = parseRow(line) else {
            return nil
        }

        var alignments: [ColumnAlignment] = []

        for cell in cells {
            let compact = cell.replacingOccurrences(of: " ", with: "")
            guard !compact.isEmpty else {
                return nil
            }

            let leftAligned = compact.hasPrefix(":")
            let rightAligned = compact.hasSuffix(":")
            let core = compact.trimmingCharacters(in: CharacterSet(charactersIn: ":"))

            guard core.count >= 3, core.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            switch (leftAligned, rightAligned) {
            case (true, true):
                alignments.append(.center)
            case (false, true):
                alignments.append(.right)
            default:
                alignments.append(.left)
            }
        }

        return alignments
    }

    private func renderTableHTML(headers: [String], alignments: [ColumnAlignment], rows: [[String]]) throws -> String {
        let renderedHeaders = try zip(headers, alignments).map { cell, alignment in
            try "<th\(alignment.styleAttribute)>\(renderInlineHTML(for: cell))</th>"
        }.joined()

        let renderedBody = try rows.map { row in
            let renderedCells = try zip(row, alignments).map { cell, alignment in
                try "<td\(alignment.styleAttribute)>\(renderInlineHTML(for: cell))</td>"
            }.joined()

            return "<tr>\(renderedCells)</tr>"
        }.joined()

        let bodySection = rows.isEmpty ? "" : "<tbody>\(renderedBody)</tbody>"

        return """
        <table>
          <thead>
            <tr>\(renderedHeaders)</tr>
          </thead>
          \(bodySection)
        </table>
        """
    }

    private func renderInlineHTML(for markdown: String) throws -> String {
        guard !markdown.isEmpty else {
            return ""
        }

        let html = try Down(markdownString: applyStrikethrough(to: markdown)).toHTML(.unsafe)
        return html.removingSingleParagraphWrapper()
    }

    private func fenceMarker(for line: String) -> Fence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("```") {
            return Fence(character: "`", count: trimmed.prefix { $0 == "`" }.count)
        }

        if trimmed.hasPrefix("~~~") {
            return Fence(character: "~", count: trimmed.prefix { $0 == "~" }.count)
        }

        return nil
    }
}
