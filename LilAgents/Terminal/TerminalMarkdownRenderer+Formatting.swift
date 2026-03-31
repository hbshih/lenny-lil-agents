import AppKit

extension TerminalMarkdownRenderer {
    static func appendHeading(_ text: String, level: Int, to result: NSMutableAttributedString, theme t: PopoverTheme) {
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

    static func appendParagraph(_ text: String, to result: NSMutableAttributedString, theme t: PopoverTheme) {
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

    static func appendQuote(_ text: String, to result: NSMutableAttributedString, theme t: PopoverTheme) {
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

    static func appendListItem(_ item: ListItem, to result: NSMutableAttributedString, theme t: PopoverTheme) {
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

    static func appendCodeBlock(_ lines: [String], to result: NSMutableAttributedString, theme t: PopoverTheme) {
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

    static func appendTable(_ lines: [String], to result: NSMutableAttributedString, theme t: PopoverTheme) {
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
}
