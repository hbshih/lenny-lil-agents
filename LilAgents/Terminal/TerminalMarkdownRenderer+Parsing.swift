import AppKit

extension TerminalMarkdownRenderer {
    static func renderInlineMarkdown(_ text: String, theme t: PopoverTheme, colorOverride: NSColor? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseColor = colorOverride ?? t.textPrimary
        var index = text.startIndex

        while index < text.endIndex {
            if let mentionRange = atMentionRange(in: text, from: index) {
                let mention = String(text[mentionRange.range])
                result.append(NSAttributedString(
                    string: mention,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: t.font.pointSize, weight: .semibold),
                        .foregroundColor: t.accentColor
                    ]
                ))
                index = mentionRange.end
                continue
            }

            if text[index] == "`",
               let closeIndex = text[text.index(after: index)...].firstIndex(of: "`") {
                let code = String(text[text.index(after: index)..<closeIndex])
                result.append(NSAttributedString(
                    string: code,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .regular),
                        .foregroundColor: t.accentColor,
                        .backgroundColor: t.inputBg
                    ]
                ))
                index = text.index(after: closeIndex)
                continue
            }

            if let boldRange = enclosedRange(in: text, marker: "**", from: index) {
                result.append(NSAttributedString(
                    string: String(text[boldRange.content]),
                    attributes: [
                        .font: t.fontBold,
                        .foregroundColor: baseColor
                    ]
                ))
                index = boldRange.end
                continue
            }

            if let italicRange = enclosedRange(in: text, marker: "*", from: index) {
                result.append(NSAttributedString(
                    string: String(text[italicRange.content]),
                    attributes: [
                        .font: NSFontManager.shared.convert(t.font, toHaveTrait: .italicFontMask),
                        .foregroundColor: baseColor
                    ]
                ))
                index = italicRange.end
                continue
            }

            if let linkRange = markdownLink(in: text, from: index) {
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: t.font,
                    .foregroundColor: t.accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                if let url = URL(string: linkRange.url) {
                    attributes[.link] = url
                    attributes[.cursor] = NSCursor.pointingHand
                }
                result.append(NSAttributedString(string: linkRange.label, attributes: attributes))
                index = linkRange.end
                continue
            }

            if let urlRange = rawURL(in: text, from: index) {
                var attributes: [NSAttributedString.Key: Any] = [
                    .font: t.font,
                    .foregroundColor: t.accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                if let url = URL(string: urlRange.url) {
                    attributes[.link] = url
                }
                result.append(NSAttributedString(string: urlRange.url, attributes: attributes))
                index = urlRange.end
                continue
            }

            result.append(NSAttributedString(
                string: String(text[index]),
                attributes: [
                    .font: t.font,
                    .foregroundColor: baseColor
                ]
            ))
            index = text.index(after: index)
        }

        return result
    }

    static func headingLevel(for line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("### ") { return 3 }
        if trimmed.hasPrefix("## ") { return 2 }
        if trimmed.hasPrefix("# ") { return 1 }
        return nil
    }

    static func blockquoteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        return trimmed.drop { $0 == ">" || $0 == " " }.description
    }

    static func listItemContent(for line: String) -> ListItem? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
            return ListItem(
                content: String(trimmed.dropFirst(2)),
                ordered: false,
                number: nil,
                depth: leadingSpaces / 2
            )
        }

        let matcher = try? NSRegularExpression(pattern: #"^(\d+)\.\s+(.*)$"#)
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        if let match = matcher?.firstMatch(in: trimmed, range: nsRange),
           let numberRange = Range(match.range(at: 1), in: trimmed),
           let contentRange = Range(match.range(at: 2), in: trimmed) {
            return ListItem(
                content: String(trimmed[contentRange]),
                ordered: true,
                number: Int(trimmed[numberRange]),
                depth: leadingSpaces / 2
            )
        }

        return nil
    }

    static func isMarkdownTable(at index: Int, in lines: [String]) -> Bool {
        guard index + 1 < lines.count else { return false }
        let current = lines[index]
        let next = lines[index + 1]
        return current.contains("|") && isTableSeparator(next)
    }

    static func collectTableLines(startingAt index: Int, in lines: [String]) -> [String] {
        var result: [String] = []
        var current = index
        while current < lines.count {
            let line = lines[current]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || !line.contains("|") {
                break
            }
            result.append(line)
            current += 1
        }
        return result
    }

    static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ":", with: "")
        let trimmed = stripped.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.allSatisfy { $0 == "-" }
    }

    static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func noteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("note:") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.lowercased().hasPrefix("**note:**") {
            return String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func enclosedRange(in text: String, marker: String, from start: String.Index) -> (content: Range<String.Index>, end: String.Index)? {
        guard text[start...].hasPrefix(marker) else { return nil }
        let contentStart = text.index(start, offsetBy: marker.count)
        guard contentStart < text.endIndex,
              let closing = text.range(of: marker, range: contentStart..<text.endIndex)
        else { return nil }
        return (contentStart..<closing.lowerBound, closing.upperBound)
    }

    static func markdownLink(in text: String, from start: String.Index) -> (label: String, url: String, end: String.Index)? {
        guard text[start] == "[" else { return nil }
        guard let closeBracket = text[start...].firstIndex(of: "]") else { return nil }
        let parenStart = text.index(after: closeBracket)
        guard parenStart < text.endIndex, text[parenStart] == "(" else { return nil }
        let urlStart = text.index(after: parenStart)
        guard let closeParen = text[urlStart...].firstIndex(of: ")") else { return nil }
        let label = String(text[text.index(after: start)..<closeBracket])
        let url = String(text[urlStart..<closeParen])
        return (label, url, text.index(after: closeParen))
    }

    static func rawURL(in text: String, from start: String.Index) -> (url: String, end: String.Index)? {
        let remaining = String(text[start...])
        guard remaining.hasPrefix("https://") || remaining.hasPrefix("http://") else { return nil }
        var end = start
        while end < text.endIndex, !text[end].isWhitespace, text[end] != ")" {
            end = text.index(after: end)
        }
        return (String(text[start..<end]), end)
    }

    static func atMentionRange(in text: String, from start: String.Index) -> (range: Range<String.Index>, end: String.Index)? {
        guard text[start] == "@" else { return nil }
        if start > text.startIndex {
            let previous = text[text.index(before: start)]
            if previous.isLetter || previous.isNumber {
                return nil
            }
        }

        let contentStart = text.index(after: start)
        guard contentStart < text.endIndex else { return nil }

        var end = contentStart
        var sawContent = false
        var lastWasSpace = false

        while end < text.endIndex {
            let ch = text[end]
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "." || ch == "'" {
                sawContent = true
                lastWasSpace = false
                end = text.index(after: end)
                continue
            }

            if ch == " " {
                guard sawContent, !lastWasSpace else { break }
                lastWasSpace = true
                end = text.index(after: end)
                continue
            }

            break
        }

        while end > contentStart, text[text.index(before: end)] == " " {
            end = text.index(before: end)
        }

        guard sawContent, end > contentStart else { return nil }
        return (start..<end, end)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ListItem {
    let content: String
    let ordered: Bool
    let number: Int?
    let depth: Int
}
