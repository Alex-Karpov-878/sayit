import Foundation

/// An inert text scanner. Never hands untrusted clipboard HTML to WebKit or an
/// attributed-string HTML importer, which can fetch images and stylesheets.
enum HTMLTextExtractor {
    static func text(from source: String) -> String {
        var output = ""
        var cursor = source.startIndex
        while cursor < source.endIndex {
            guard source[cursor] == "<" else {
                output.append(source[cursor])
                cursor = source.index(after: cursor)
                continue
            }
            var end = source.index(after: cursor)
            guard end < source.endIndex,
                  source[end].isLetter || "/!?".contains(source[end]) else {
                output.append("<")
                cursor = end
                continue
            }
            var quote: Character?
            while end < source.endIndex {
                let character = source[end]
                if let current = quote {
                    if character == current { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    break
                }
                end = source.index(after: end)
            }
            // An unterminated tag is not readable text.
            guard end < source.endIndex else { break }
            cursor = source.index(after: end)
        }
        return decodeEntities(output)
    }

    private static func decodeEntities(_ text: String) -> String {
        let named = [
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
            "nbsp": " ", "ndash": "–", "mdash": "—", "hellip": "…",
            "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
            "copy": "©", "reg": "®", "trade": "™", "bull": "•"
        ]
        var output = ""
        var cursor = text.startIndex
        while cursor < text.endIndex {
            if text[cursor] == "&" {
                let start = text.index(after: cursor)
                let limit = text.index(start, offsetBy: 32, limitedBy: text.endIndex) ?? text.endIndex
                if let end = text[start..<limit].firstIndex(of: ";") {
                    let name = String(text[start..<end])
                    var decoded = named[name]
                    if name.hasPrefix("#") {
                        let hex = name.lowercased().hasPrefix("#x")
                        if let value = UInt32(name.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10),
                           let scalar = UnicodeScalar(value), value != 0 {
                            decoded = String(scalar)
                        }
                    }
                    if let decoded {
                        output += decoded
                        cursor = text.index(after: end)
                        continue
                    }
                }
            }
            output.append(text[cursor])
            cursor = text.index(after: cursor)
        }
        return output
    }
}
