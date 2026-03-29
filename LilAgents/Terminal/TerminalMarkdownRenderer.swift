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

    private static func appendHeading(_ text: String, level: Int, to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let sizeOffset: CGFloat
        switch level {
        case 1: sizeOffset = 4
        case 2: sizeOffset = 2
        default: sizeOffset = 1
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 10
        paragraph.paragraphSpacingBefore = level == 1 ? 8 : 6
        result.append(NSAttributedString(
            string: text.trimmingCharacters(in: .whitespaces) + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: t.font.pointSize + sizeOffset, weight: .semibold),
                .foregroundColor: t.accentColor,
                .paragraphStyle: paragraph
            ]
        ))
    }

    private static func appendParagraph(_ text: String, to result: NSMutableAttributedString, theme t: PopoverTheme) {
        if let note = noteContent(for: text) {
            appendCallout(label: "Note", text: note, to: result, theme: t)
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        paragraph.paragraphSpacingBefore = 1
        result.append(attributedBlock(renderInlineMarkdown(text + "\n", theme: t), paragraph: paragraph))
    }

    private static func appendQuote(_ text: String, to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        paragraph.headIndent = 14
        paragraph.firstLineHeadIndent = 0

        let quote = NSMutableAttributedString()
        quote.append(NSAttributedString(
            string: "▍ ",
            attributes: [
                .font: t.fontBold,
                .foregroundColor: t.accentColor,
                .paragraphStyle: paragraph
            ]
        ))
        quote.append(attributedBlock(renderInlineMarkdown(text + "\n", theme: t, colorOverride: t.textDim), paragraph: paragraph))
        result.append(quote)
    }

    private static func appendListItem(_ item: ListItem, to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let marker = item.ordered ? "\(item.number ?? 1)." : "•"
        let indent = CGFloat(item.depth) * 18
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 4
        paragraph.firstLineHeadIndent = indent
        paragraph.headIndent = indent + 16

        let line = NSMutableAttributedString()
        line.append(NSAttributedString(
            string: marker + " ",
            attributes: [
                .font: t.font,
                .foregroundColor: t.accentColor,
                .paragraphStyle: paragraph
            ]
        ))
        line.append(attributedBlock(renderInlineMarkdown(item.content + "\n", theme: t), paragraph: paragraph))
        result.append(line)
    }

    private static func appendCodeBlock(_ lines: [String], to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let codeFont = NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        result.append(NSAttributedString(
            string: lines.joined(separator: "\n") + "\n",
            attributes: [
                .font: codeFont,
                .foregroundColor: t.textPrimary,
                .backgroundColor: t.inputBg,
                .paragraphStyle: paragraph
            ]
        ))
    }

    private static func appendTable(_ lines: [String], to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let rows = lines.map(parseTableRow)
        guard rows.count >= 2 else {
            lines.forEach { appendParagraph($0, to: result, theme: t) }
            return
        }

        let header = rows[0]
        let body = Array(rows.dropFirst(2))
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return }

        if columnCount == 2 {
            appendTwoColumnTable(header: header, body: body, to: result, theme: t)
            return
        }

        var widths = Array(repeating: 0, count: columnCount)
        for row in [header] + body {
            for index in 0..<columnCount {
                let cell = index < row.count ? normalizedCellText(row[index]) : ""
                widths[index] = min(max(widths[index], cell.count), 28)
            }
        }

        let tabStops: [NSTextTab] = widths.enumerated().map { index, width in
            let precedingWidth = widths.prefix(index).reduce(0, +)
            let location = CGFloat(precedingWidth + (index * 4))
            return NSTextTab(textAlignment: .left, location: location * 7.2, options: [:])
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = tabStops
        paragraph.defaultTabInterval = 120
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 4

        let monoFont = NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: t.font.pointSize - 0.5, weight: .semibold)

        let renderedHeader = tabbedRow(header, widths: widths)
        result.append(NSAttributedString(
            string: renderedHeader + "\n",
            attributes: [
                .font: monoBold,
                .foregroundColor: t.accentColor,
                .paragraphStyle: paragraph,
                .backgroundColor: t.inputBg
            ]
        ))

        let divider = widths.map { String(repeating: "—", count: max($0, 3)) }.joined(separator: "\t")
        result.append(NSAttributedString(
            string: divider + "\n",
            attributes: [
                .font: monoFont,
                .foregroundColor: t.separatorColor,
                .paragraphStyle: paragraph,
                .backgroundColor: t.inputBg
            ]
        ))

        for row in body {
            result.append(NSAttributedString(
                string: tabbedRow(row, widths: widths) + "\n",
                attributes: [
                    .font: monoFont,
                    .foregroundColor: t.textPrimary,
                    .paragraphStyle: paragraph,
                    .backgroundColor: t.inputBg
                ]
            ))
        }
    }

    private static func appendTwoColumnTable(header: [String], body: [[String]], to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let detailLabel = normalizedCellText(header[safe: 1] ?? "Details")
        let headerParagraph = NSMutableParagraphStyle()
        headerParagraph.lineSpacing = 2
        headerParagraph.paragraphSpacing = 8

        let headerLine = [header[safe: 0], header[safe: 1]]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")

        if !headerLine.isEmpty {
            result.append(NSAttributedString(
                string: headerLine + "\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: t.font.pointSize - 0.5, weight: .semibold),
                    .foregroundColor: t.textDim,
                    .paragraphStyle: headerParagraph
                ]
            ))
        }

        for row in body {
            let title = normalizedCellText(row[safe: 0] ?? "")
            let detail = normalizedCellText(row[safe: 1] ?? "")
            guard !title.isEmpty || !detail.isEmpty else { continue }

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 3
            paragraph.paragraphSpacing = 10

            let block = NSMutableAttributedString()
            if !title.isEmpty {
                block.append(NSAttributedString(
                    string: title + "\n",
                    attributes: [
                        .font: t.fontBold,
                        .foregroundColor: t.textPrimary,
                        .paragraphStyle: paragraph
                    ]
                ))
            }

            if !detail.isEmpty {
                let detailPrefix = NSMutableAttributedString(
                    string: "\(detailLabel): ",
                    attributes: [
                        .font: t.fontBold,
                        .foregroundColor: t.accentColor,
                        .paragraphStyle: paragraph
                    ]
                )
                detailPrefix.append(attributedBlock(renderInlineMarkdown(detail + "\n", theme: t), paragraph: paragraph))
                block.append(detailPrefix)
            }

            result.append(block)
        }
    }

    private static func appendCallout(label: String, text: String, to result: NSMutableAttributedString, theme t: PopoverTheme) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 10
        paragraph.headIndent = 14
        paragraph.firstLineHeadIndent = 0

        let callout = NSMutableAttributedString()
        callout.append(NSAttributedString(
            string: "▌ ",
            attributes: [
                .font: t.fontBold,
                .foregroundColor: t.accentColor,
                .paragraphStyle: paragraph
            ]
        ))
        callout.append(NSAttributedString(
            string: "\(label): ",
            attributes: [
                .font: t.fontBold,
                .foregroundColor: t.textDim,
                .paragraphStyle: paragraph
            ]
        ))
        callout.append(attributedBlock(renderInlineMarkdown(text + "\n", theme: t, colorOverride: t.textDim), paragraph: paragraph))
        result.append(callout)
    }

    private static func attributedBlock(_ string: NSAttributedString, paragraph: NSParagraphStyle) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: string)
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    private static func tabbedRow(_ row: [String], widths: [Int]) -> String {
        widths.indices.map { index in
            let cell = index < row.count ? normalizedCellText(row[index]) : ""
            return pad(cell, to: widths[index])
        }.joined(separator: "\t")
    }

    private static func pad(_ text: String, to width: Int) -> String {
        let truncated = text.count > width ? String(text.prefix(max(width - 1, 1))) + "…" : text
        let padding = max(width - truncated.count, 0)
        return truncated + String(repeating: " ", count: padding)
    }

    private static func normalizedCellText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\|", with: "|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func renderInlineMarkdown(_ text: String, theme t: PopoverTheme, colorOverride: NSColor? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseColor = colorOverride ?? t.textPrimary
        var index = text.startIndex

        while index < text.endIndex {
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

    private static func headingLevel(for line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("### ") { return 3 }
        if trimmed.hasPrefix("## ") { return 2 }
        if trimmed.hasPrefix("# ") { return 1 }
        return nil
    }

    private static func blockquoteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        return trimmed.drop { $0 == ">" || $0 == " " }.description
    }

    private static func listItemContent(for line: String) -> ListItem? {
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

    private static func isMarkdownTable(at index: Int, in lines: [String]) -> Bool {
        guard index + 1 < lines.count else { return false }
        let current = lines[index]
        let next = lines[index + 1]
        return current.contains("|") && isTableSeparator(next)
    }

    private static func collectTableLines(startingAt index: Int, in lines: [String]) -> [String] {
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

    private static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: "|", with: "").replacingOccurrences(of: ":", with: "")
        let trimmed = stripped.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.allSatisfy { $0 == "-" }
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func noteContent(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("note:") {
            return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.lowercased().hasPrefix("**note:**") {
            return String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func enclosedRange(in text: String, marker: String, from start: String.Index) -> (content: Range<String.Index>, end: String.Index)? {
        guard text[start...].hasPrefix(marker) else { return nil }
        let contentStart = text.index(start, offsetBy: marker.count)
        guard contentStart < text.endIndex,
              let closing = text.range(of: marker, range: contentStart..<text.endIndex)
        else { return nil }
        return (contentStart..<closing.lowerBound, closing.upperBound)
    }

    private static func markdownLink(in text: String, from start: String.Index) -> (label: String, url: String, end: String.Index)? {
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

    private static func rawURL(in text: String, from start: String.Index) -> (url: String, end: String.Index)? {
        let remaining = String(text[start...])
        guard remaining.hasPrefix("https://") || remaining.hasPrefix("http://") else { return nil }
        var end = start
        while end < text.endIndex, !text[end].isWhitespace, text[end] != ")" {
            end = text.index(after: end)
        }
        return (String(text[start..<end]), end)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ListItem {
    let content: String
    let ordered: Bool
    let number: Int?
    let depth: Int
}
