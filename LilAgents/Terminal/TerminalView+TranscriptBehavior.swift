import AppKit

extension TerminalView {
    private func scrollLatestTranscriptItemIntoView() {
        resizeTranscriptToFitContent()
        guard let lastView = transcriptStack.arrangedSubviews.last else {
            scrollToBottom()
            return
        }

        let targetRect = NSRect(
            x: 0,
            y: lastView.frame.minY,
            width: max(lastView.frame.width, transcriptStack.bounds.width),
            height: 1
        )
        _ = transcriptContainer.scrollToVisible(targetRect)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func appendBubble(text: NSAttributedString, isUser: Bool, speaker: TranscriptSpeaker, followUpExpert: ResponderExpert? = nil) {
        let followUpHandler: (() -> Void)? = {
            guard let followUpExpert, !self.isExpertMode else { return nil }
            return { [weak self] in
                guard let self else { return }
                self.onSelectExpert?(followUpExpert)
            }
        }()

        let bubble = ChatBubbleView(
            text: text,
            isUser: isUser,
            speaker: speaker,
            theme: theme,
            onCopy: {
                WalkerCharacter.playSelectionSound()
            },
            onFollowUp: followUpHandler
        )
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollLatestTranscriptItemIntoView()
    }

    func expertSuggestionCardHeight(for expertCount: Int) -> CGFloat {
        let count = CGFloat(expertCount)
        return 30 + (count * 54) + max(0, count - 1) * 8
    }

    private func appendSuggestionEntryView(_ entry: ExpertSuggestionEntry) {
        if entry.isCollapsed, entry.pickedExpert != nil {
            let compact = CompactSuggestionView(theme: theme, entry: entry)
            compact.onRetap = { [weak self] entryID in
                self?.onEditExpertSuggestion?(entryID)
            }
            transcriptStack.addArrangedSubview(compact)
            compact.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            compact.heightAnchor.constraint(equalToConstant: 46).isActive = true
            return
        }

        let suggestionsView = ExpertSuggestionCardView(theme: theme, entry: entry)
        suggestionsView.onExpertTapped = { [weak self] entryID, expert in
            self?.onSelectExpertSuggestion?(entryID, expert)
        }
        transcriptStack.addArrangedSubview(suggestionsView)
        suggestionsView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        suggestionsView.heightAnchor.constraint(equalToConstant: expertSuggestionCardHeight(for: entry.experts.count)).isActive = true
    }

    func showWelcomeGreeting() {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()
        isShowingInitialWelcomeState = true
        let t = theme
        let greeting = "I'm Lil-Lenny. Ask me anything about product, growth, leadership, pricing, startups, or AI.\n\nYour desktop shortcut to LennyData."
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary,
        ])
        appendBubble(text: attrText, isUser: false, speaker: TranscriptSpeaker(name: "Lil-Lenny", avatarPath: nil, kind: .lenny))

        showWelcomeSuggestionsPanel()
        scrollToTop()
    }

    func showExpertGreeting(for expert: ResponderExpert) {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()
        isShowingInitialWelcomeState = false

        let greeting = "I'm \(expert.name). What would you like to dig into?"
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: theme.font,
            .foregroundColor: theme.textPrimary,
        ])
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        appendBubble(text: attrText, isUser: false, speaker: TranscriptSpeaker(name: expert.name, avatarPath: expert.avatarPath, kind: .expert))
        currentAssistantText = ""
        scrollToTop()
    }

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        isShowingInitialWelcomeState = false
        let t = theme
        let visibleText = text.isEmpty ? "Sent with attachment" : text
        let attrText = NSMutableAttributedString(string: visibleText, attributes: [
            .font: t.fontBold,
            .foregroundColor: t.textPrimary
        ])

        if !attachments.isEmpty {
            let attachText = attachments.map(\.displayName).joined(separator: ", ")
            attrText.append(NSAttributedString(string: "\n📎 \(attachText)", attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: t.textDim
            ]))
        }

        appendBubble(text: attrText, isUser: true, speaker: TranscriptSpeaker(name: "You", avatarPath: nil, kind: .user))
    }

    func appendStreamingText(_ text: String) {
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                lastBubble.setText(formatted)
            } else {
                beginAssistantTurn(name: theme.titleString)
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                    lastBubble.setText(formatted)
                }
            }
            scrollLatestBubbleIntoView()
        }
    }

    func beginAssistantTurn(name: String?) {
        let labelName = name ?? theme.titleString
        let speaker = TranscriptSpeaker(name: labelName, avatarPath: nil, kind: labelName.lowercased() == "lil-lenny" ? .lenny : .system)
        appendBubble(text: NSAttributedString(string: ""), isUser: false, speaker: speaker)
    }

    func endStreaming() {
        isStreaming = false
    }

    func appendError(_ text: String) {
        let t = theme
        let errorText = NSAttributedString(string: text, attributes: [
            .font: t.font,
            .foregroundColor: t.errorColor
        ])
        appendBubble(text: errorText, isUser: false, speaker: TranscriptSpeaker(name: "System", avatarPath: nil, kind: .system))
    }

    func appendStatus(_ text: String) {
        // Handled entirely by live status pill
    }

    func renderTranscriptLiveStatus(_ text: String, experts: [ResponderExpert] = []) {
        if let statusView = transcriptLiveStatusView as? TranscriptStatusView {
            statusView.update(text: text, experts: experts)
        } else {
            let statusView = TranscriptStatusView(theme: theme, text: text, experts: experts)
            transcriptStack.addArrangedSubview(statusView)
            statusView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            transcriptLiveStatusView = statusView
        }
    }

    func clearTranscriptLiveStatus() {
        if let view = transcriptLiveStatusView {
            transcriptStack.removeArrangedSubview(view)
            view.removeFromSuperview()
            transcriptLiveStatusView = nil
        }
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = false
        renderTranscriptSuggestions()
    }

    func appendToolUse(toolName: String, summary: String, experts: [ResponderExpert] = []) {
        endStreaming()
        setLiveStatus(toolName, isBusy: true, isError: false, experts: experts)
    }

    func appendToolResult(summary: String, displaySummary: String? = nil, isError: Bool, experts: [ResponderExpert] = []) {
        setLiveStatus(displaySummary ?? summary, isBusy: !isError, isError: isError, experts: experts)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        replayConversation(messages, expertSuggestions: [])
    }

    func replayConversation(_ messages: [ClaudeSession.Message], expertSuggestions: [ExpertSuggestionEntry]) {
        let t = theme
        isShowingInitialWelcomeState = false
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        transcriptSuggestionView = nil
        transcriptLiveStatusView = nil
        hideWelcomeSuggestionsPanel()
        currentAssistantText = ""
        var lastRole: ClaudeSession.Message.Role?
        let suggestionsByAnchor = Dictionary(grouping: expertSuggestions, by: \.anchorHistoryCount)

        for (index, msg) in messages.enumerated() {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                let speaker = msg.speaker ?? TranscriptSpeaker(name: t.titleString, avatarPath: nil, kind: .lenny)
                let formatted = TerminalMarkdownRenderer.render(msg.text, theme: t)
                appendBubble(text: formatted, isUser: false, speaker: speaker, followUpExpert: msg.followUpExpert)
            case .error:
                appendError(msg.text)
            case .toolUse:
                continue
            case .toolResult:
                continue
            }
            lastRole = msg.role

            let anchorHistoryCount = index + 1
            if let entries = suggestionsByAnchor[anchorHistoryCount] {
                for entry in entries {
                    appendSuggestionEntryView(entry)
                }
            }
        }

        if lastRole == .assistant {
            endStreaming()
        }
        scrollLatestTranscriptItemIntoView()
    }

    func scrollToBottom() {
        resizeTranscriptToFitContent()
        if let docView = scrollView.documentView {
            let maxScroll = docView.bounds.height - scrollView.contentSize.height
            if maxScroll > 0 {
                docView.scroll(NSPoint(x: 0, y: maxScroll))
            }
        }
    }

    func scrollLatestBubbleIntoView() {
        scrollLatestTranscriptItemIntoView()
    }

    func scrollToTop() {
        resizeTranscriptToFitContent()
        scrollView.documentView?.scroll(NSPoint(x: 0, y: 0))
    }

    func resizeTranscriptToFitContent() {
        transcriptStack.layoutSubtreeIfNeeded()
        let stackHeight = transcriptStack.fittingSize.height
        let targetHeight = max(scrollView.contentSize.height, stackHeight + 10)
        transcriptContainer.frame.size.height = targetHeight
    }
}
