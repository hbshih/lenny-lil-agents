import AppKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

class ChatBubbleView: NSView, NSTextViewDelegate {
    let textView = NSTextView()
    let headerLabel = NSTextField(labelWithString: "")
    let bubbleBackground = NSView()
    private let isUser: Bool
    private let theme: PopoverTheme

    init(text: NSAttributedString, isUser: Bool, speakerName: String, theme: PopoverTheme) {
        self.isUser = isUser
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
        populate(text: text, name: speakerName)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = isUser ? theme.textDim : theme.accentColor
        headerLabel.alignment = .left
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.drawsBackground = false
        addSubview(headerLabel)

        bubbleBackground.wantsLayer = true
        bubbleBackground.layer?.cornerRadius = 14
        bubbleBackground.layer?.backgroundColor = isUser ? theme.accentColor.withAlphaComponent(0.12).cgColor : theme.bubbleBg.cgColor
        bubbleBackground.layer?.borderWidth = isUser ? 0 : 0.75
        bubbleBackground.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.4).cgColor
        bubbleBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleBackground)

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: theme.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 3
        p.paragraphSpacing = 6
        p.alignment = .left 
        textView.defaultParagraphStyle = p
        
        bubbleBackground.addSubview(textView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor, constant: 4),
            headerLabel.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor, constant: -4),

            bubbleBackground.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            bubbleBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: bubbleBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: bubbleBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor)
        ])

        if isUser {
            bubbleBackground.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            bubbleBackground.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40).isActive = true
        } else {
            bubbleBackground.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            bubbleBackground.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40).isActive = true
        }
    }

    private func populate(text: NSAttributedString, name: String) {
        headerLabel.stringValue = name
        
        // Disable automatic tracking so we can set explicit sizes
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        
        textView.textStorage?.setAttributedString(text)
        recalculateSize()
    }

    func appendText(_ newText: NSAttributedString) {
        textView.textStorage?.append(newText)
        recalculateSize()
    }

    private func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Start large
        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        
        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28 // left+right 14px

        let maxWidth: CGFloat = 500
        let desiredWidth = targetContentWidth + paddingWidth

        // Cleanup old layout constraints
        textView.constraints.filter { $0.firstAttribute == .width || $0.firstAttribute == .height }.forEach { textView.removeConstraint($0) }
        
        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textView.widthAnchor.constraint(equalToConstant: maxWidth).isActive = true
            textView.heightAnchor.constraint(equalToConstant: newRect.height + 24).isActive = true
        } else {
            let finalWidth = max(desiredWidth, 60)
            textView.widthAnchor.constraint(equalToConstant: finalWidth).isActive = true
            textView.heightAnchor.constraint(equalToConstant: rect.height + 24).isActive = true
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        var view: NSView? = self.superview
        while let v = view {
            if let terminal = v as? TerminalView {
                guard let url = link as? URL,
                      url.scheme == "lilagents-expert",
                      let host = url.host,
                      let expert = terminal.expertSuggestionTargets[host] else {
                    return false
                }
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}

extension TerminalView {
    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        let visibleText = text.isEmpty ? "(with attachments)" : text
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
        
        let bubble = ChatBubbleView(text: attrText, isUser: true, speakerName: "You", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                let formatted = TerminalMarkdownRenderer.render(cleaned, theme: theme)
                lastBubble.appendText(formatted)
            } else {
                beginAssistantTurn(name: theme.titleString)
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(cleaned, theme: theme)
                    lastBubble.appendText(formatted)
                }
            }
            scrollToBottom()
        }
    }

    func beginAssistantTurn(name: String?) {
        let labelName = name ?? theme.titleString
        let bubble = ChatBubbleView(text: NSAttributedString(string: ""), isUser: false, speakerName: labelName, theme: theme)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
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
        let bubble = ChatBubbleView(text: errorText, isUser: false, speakerName: "System", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStatus(_ text: String) {
        // Handled entirely by live status pill
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        // Handled by Panel
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        let statusText = summary.isEmpty ? toolName : "\(toolName): \(summary)"
        setLiveStatus(statusText, isBusy: true, isError: false)
    }

    func appendToolResult(summary: String, isError: Bool) {
        setLiveStatus(summary, isBusy: !isError, isError: isError)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        let t = theme
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentAssistantText = ""
        var lastRole: ClaudeSession.Message.Role?
        
        for msg in messages {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                if lastRole != .assistant {
                    beginAssistantTurn(name: t.titleString)
                }
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(msg.text + "\n", theme: t)
                    lastBubble.appendText(formatted)
                }
            case .error:
                appendError(msg.text)
            case .toolUse, .toolResult:
                continue
            }
            lastRole = msg.role
        }

        if lastRole == .assistant {
            endStreaming()
        }
        scrollToBottom()
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

    func resizeTranscriptToFitContent() {
        transcriptStack.layoutSubtreeIfNeeded()
        let stackHeight = transcriptStack.fittingSize.height
        let targetHeight = max(scrollView.contentSize.height, stackHeight + 10)
        transcriptContainer.frame.size.height = targetHeight
    }
}
