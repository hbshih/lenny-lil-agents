import AppKit

extension TerminalView {
    var messageSpacing: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = 8
        return p
    }

    private func ensureNewline() {
        if let storage = textView.textStorage, storage.length > 0 {
            if !storage.string.hasSuffix("\n") {
                storage.append(NSAttributedString(string: "\n"))
            }
        }
    }

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        ensureNewline()
        let para = messageSpacing
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "You\n", attributes: [
            .font: NSFont.systemFont(ofSize: max(11, t.font.pointSize - 2), weight: .semibold),
            .foregroundColor: t.textDim,
            .paragraphStyle: para
        ]))
        let visibleText = text.isEmpty ? "(with attachments)" : text
        attributed.append(NSAttributedString(string: "\(visibleText)\n\n", attributes: [
            .font: t.fontBold, .foregroundColor: t.textPrimary, .paragraphStyle: para
        ]))
        if !attachments.isEmpty {
            let attachmentText = attachments.map(\.displayName).joined(separator: ", ")
            attributed.append(NSAttributedString(string: "Attached: \(attachmentText)\n", attributes: [
                .font: NSFont.systemFont(ofSize: max(11, t.font.pointSize - 2), weight: .medium),
                .foregroundColor: t.textDim,
                .paragraphStyle: para
            ]))
        }
        textView.textStorage?.append(attributed)
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            textView.textStorage?.append(TerminalMarkdownRenderer.render(cleaned, theme: theme))
            scrollToBottom()
        }
    }

    func endStreaming() {
        if isStreaming {
            isStreaming = false
        }
    }

    func appendError(_ text: String) {
        let t = theme
        textView.textStorage?.append(NSAttributedString(string: text + "\n", attributes: [
            .font: t.font, .foregroundColor: t.errorColor
        ]))
        scrollToBottom()
    }

    func appendStatus(_ text: String) {
        let t = theme
        ensureNewline()
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.paragraphSpacingBefore = 2
        textView.textStorage?.append(NSAttributedString(
            string: "· \(text) ·\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: t.textDim.withAlphaComponent(0.6),
                .paragraphStyle: para
            ]
        ))
        scrollToBottom()
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        guard !experts.isEmpty else { return }

        let t = theme
        ensureNewline()

        let prompt = NSMutableAttributedString(string: "I found a few people who seem stronger on this topic. Spin one up:\n", attributes: [
            .font: t.fontBold,
            .foregroundColor: t.accentColor
        ])

        for expert in experts {
            let identifier = normalizeExpertSuggestionID(expert.name)
            expertSuggestionTargets[identifier] = expert

            let line = NSMutableAttributedString(string: "  • ", attributes: [
                .font: t.font,
                .foregroundColor: t.accentColor
            ])

            line.append(NSAttributedString(string: expert.name, attributes: [
                .font: t.fontBold,
                .foregroundColor: t.accentColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: URL(string: "lilagents-expert://\(identifier)") as Any
            ]))

            line.append(NSAttributedString(string: " — click to switch the conversation to this expert\n", attributes: [
                .font: t.font,
                .foregroundColor: t.textDim
            ]))

            prompt.append(line)
        }

        textView.textStorage?.append(prompt)
        scrollToBottom()
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        setLiveStatus(summary.isEmpty ? toolName : "\(toolName): \(summary)", isBusy: true, isError: false)
    }

    func appendToolResult(summary: String, isError: Bool) {
        setLiveStatus(summary, isBusy: false, isError: isError)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        let t = theme
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        for msg in messages {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                textView.textStorage?.append(TerminalMarkdownRenderer.render(msg.text + "\n", theme: t))
            case .error:
                appendError(msg.text)
            case .toolUse, .toolResult:
                continue
            }
        }
        scrollToBottom()
    }

    private func scrollToBottom() {
        resizeTranscriptToFitContent()
        textView.scrollToEndOfDocument(nil)
    }

    func resizeTranscriptToFitContent() {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let targetHeight = max(scrollView.contentSize.height, ceil(usedRect.height + textView.textContainerInset.height * 2 + 12))

        if abs(textView.frame.height - targetHeight) > 1 {
            textView.frame.size.height = targetHeight
        }
    }
}
