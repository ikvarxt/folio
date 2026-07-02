import Foundation

enum TextFileLoader {
    struct LoadedText: Sendable {
        let text: String
        let byteCount: Int
        let lineCount: Int
        let fileVersion: FileVersionSnapshot
    }

    static func load(from url: URL) throws -> LoadedText {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let text = try decode(data)
        let lineCount = max(1, text.reduce(into: 1) { partial, character in
            if character == "\n" {
                partial += 1
            }
        })

        return LoadedText(
            text: text,
            byteCount: data.count,
            lineCount: lineCount,
            fileVersion: FileVersionSnapshot.capture(for: url)
        )
    }

    private static func decode(_ data: Data) throws -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }

        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .ascii,
            .isoLatin1,
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}
