import AppKit

enum TerminalMarkdownRenderer {
    static func render(_ text: String, theme t: PopoverTheme) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = text.components(separatedBy: .newlines)
        var index = 0
        var inCodeBlock = false
        var codeLines: [String] = []

        while index < lines.count {
            let line = lines[index]

            if line.hasPrefix("```") {
                if inCodeBlock {
                    appendCodeBlock(codeLines, to: result, theme: t)
                    codeLines.removeAll()
                }
                inCodeBlock.toggle()
                index += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                index += 1
                continue
            }

            if isMarkdownTable(at: index, in: lines) {
                let tableLines = collectTableLines(startingAt: index, in: lines)
                appendTable(tableLines, to: result, theme: t)
                index += tableLines.count
                continue
            }

            if let heading = headingLevel(for: line) {
                appendHeading(String(line.dropFirst(heading + 1)), level: heading, to: result, theme: t)
                index += 1
                continue
            }

            if let quote = blockquoteContent(for: line) {
                appendQuote(quote, to: result, theme: t)
                index += 1
                continue
            }

            if let listItem = listItemContent(for: line) {
                appendListItem(listItem, to: result, theme: t)
                index += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(NSAttributedString(string: "\n"))
                index += 1
                continue
            }

            appendParagraph(line, to: result, theme: t)
            index += 1
        }

        if inCodeBlock, !codeLines.isEmpty {
            appendCodeBlock(codeLines, to: result, theme: t)
        }

        return result
    }
}
