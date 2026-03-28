import AppKit

extension TerminalView {
    func setupViews() {
        let t = theme
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let panelRadius = max(t.inputCornerRadius, 12)

        scrollView.frame = NSRect(
            x: Layout.padding,
            y: 120,
            width: frame.width - Layout.padding * 2,
            height: max(160, frame.height - 160)
        )
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 8, right: 0)

        transcriptStack.orientation = .vertical
        transcriptStack.alignment = .leading
        transcriptStack.distribution = .fill
        transcriptStack.spacing = 20
        transcriptStack.translatesAutoresizingMaskIntoConstraints = false
        transcriptContainer.addSubview(transcriptStack)
        
        NSLayoutConstraint.activate([
            transcriptStack.leadingAnchor.constraint(equalTo: transcriptContainer.leadingAnchor),
            transcriptStack.trailingAnchor.constraint(equalTo: transcriptContainer.trailingAnchor),
            transcriptStack.bottomAnchor.constraint(equalTo: transcriptContainer.bottomAnchor)
        ])
        
        transcriptContainer.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: scrollView.contentSize.height)
        transcriptContainer.autoresizingMask = [.width]
        scrollView.documentView = transcriptContainer
        addSubview(scrollView)

        liveStatusContainer.isHidden = true

        expertSuggestionContainer.frame = NSRect(
            x: Layout.padding,
            y: 84,
            width: frame.width - Layout.padding * 2,
            height: 128
        )
        expertSuggestionContainer.autoresizingMask = [.width, .maxYMargin]
        stylePanel(expertSuggestionContainer, background: t.inputBg.withAlphaComponent(0.96), border: t.separatorColor.withAlphaComponent(0.34), radius: panelRadius)
        expertSuggestionContainer.alphaValue = 0
        expertSuggestionContainer.isHidden = true
        addSubview(expertSuggestionContainer)

        expertSuggestionLabel.frame = NSRect(x: 14, y: 96, width: expertSuggestionContainer.frame.width - 28, height: 16)
        expertSuggestionLabel.autoresizingMask = [.width]
        expertSuggestionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        expertSuggestionLabel.textColor = t.textDim
        expertSuggestionLabel.stringValue = "Open an expert for a more specific follow-up."
        expertSuggestionContainer.addSubview(expertSuggestionLabel)

        expertSuggestionStack.orientation = .vertical
        expertSuggestionStack.alignment = .width
        expertSuggestionStack.distribution = .fill
        expertSuggestionStack.spacing = 8
        expertSuggestionStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        expertSuggestionStack.frame = NSRect(x: 14, y: 12, width: expertSuggestionContainer.frame.width - 28, height: 76)
        expertSuggestionStack.autoresizingMask = [.width, .height]
        expertSuggestionContainer.addSubview(expertSuggestionStack)

        attachmentLabel.frame = NSRect(
            x: Layout.padding + 2,
            y: 74,
            width: frame.width - Layout.padding * 2 - 4,
            height: Layout.attachmentHeight
        )
        attachmentLabel.autoresizingMask = [.width]
        attachmentLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        attachmentLabel.textColor = t.textDim
        attachmentLabel.lineBreakMode = .byTruncatingMiddle
        attachmentLabel.isHidden = true
        addSubview(attachmentLabel)

        let composerPanel = NSView(frame: NSRect(
            x: Layout.padding,
            y: Layout.bottomInset,
            width: frame.width - Layout.padding * 2,
            height: Layout.composerHeight
        ))
        composerPanel.autoresizingMask = [.width, .maxYMargin]
        stylePanel(composerPanel, background: t.inputBg.withAlphaComponent(0.98), border: t.separatorColor.withAlphaComponent(0.40), radius: panelRadius + 4)
        addSubview(composerPanel)

        let sendButtonSize: CGFloat = 34
        let attachButtonSize: CGFloat = 28
        let rightInset: CGFloat = 12
        let sendY = (Layout.composerHeight - sendButtonSize) / 2
        let attachY = (Layout.composerHeight - attachButtonSize) / 2
        let sendX = composerPanel.frame.width - rightInset - sendButtonSize
        let attachX = sendX - 8 - attachButtonSize

        sendButton.frame = NSRect(x: sendX, y: sendY, width: sendButtonSize, height: sendButtonSize)
        sendButton.autoresizingMask = [.minXMargin]
        sendButton.isBordered = false
        sendButton.wantsLayer = true
        sendButton.layer?.backgroundColor = t.accentColor.cgColor
        sendButton.layer?.cornerRadius = sendButtonSize / 2
        if let img = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send message") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            sendButton.image = img.withSymbolConfiguration(config)
        }
        sendButton.imageScaling = .scaleProportionallyDown
        sendButton.contentTintColor = .white
        sendButton.target = self
        sendButton.action = #selector(inputSubmitted)
        composerPanel.addSubview(sendButton)

        attachButton.frame = NSRect(x: attachX, y: attachY, width: attachButtonSize, height: attachButtonSize)
        attachButton.autoresizingMask = [.minXMargin]
        attachButton.isBordered = false
        attachButton.wantsLayer = true
        attachButton.layer?.backgroundColor = t.bubbleBg.withAlphaComponent(0.85).cgColor
        attachButton.layer?.cornerRadius = attachButtonSize / 2
        if let img = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Attach file") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            attachButton.image = img.withSymbolConfiguration(config)
        }
        attachButton.imageScaling = .scaleProportionallyDown
        attachButton.contentTintColor = t.textDim
        attachButton.target = self
        attachButton.action = #selector(attachButtonTapped)
        composerPanel.addSubview(attachButton)

        inputField.frame = NSRect(
            x: 14,
            y: 8,
            width: attachX - 24,
            height: Layout.composerHeight - 16
        )
        inputField.autoresizingMask = [.width]
        inputField.focusRingType = .none
        inputField.wantsLayer = true
        inputField.layer?.backgroundColor = NSColor.clear.cgColor
        let paddedCell = PaddedTextFieldCell(textCell: "")
        paddedCell.isEditable = true
        paddedCell.isScrollable = true
        paddedCell.font = t.font
        paddedCell.textColor = t.textPrimary
        paddedCell.drawsBackground = false
        paddedCell.isBezeled = false
        paddedCell.fieldBackgroundColor = nil
        paddedCell.fieldCornerRadius = 0
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: placeholderText,
            attributes: [.font: t.font, .foregroundColor: t.textDim]
        )
        inputField.cell = paddedCell
        inputField.target = self
        inputField.action = #selector(inputSubmitted)
        composerPanel.addSubview(inputField)

        liveStatusSpinner.style = .spinning
        liveStatusSpinner.controlSize = .small
        liveStatusSpinner.frame = NSRect(x: 20, y: (Layout.composerHeight - 16) / 2, width: 16, height: 16)
        liveStatusSpinner.isDisplayedWhenStopped = false
        liveStatusSpinner.isHidden = true
        composerPanel.addSubview(liveStatusSpinner)

        liveStatusLabel.isEditable = false
        liveStatusLabel.drawsBackground = false
        liveStatusLabel.isBordered = false
        liveStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        liveStatusLabel.textColor = t.accentColor
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusLabel.isHidden = true
        liveStatusLabel.frame = NSRect(x: 46, y: (Layout.composerHeight - 16) / 2 - 1, width: composerPanel.frame.width - 60, height: 16)
        liveStatusLabel.autoresizingMask = [.width]
        composerPanel.addSubview(liveStatusLabel)

        registerForDraggedTypes([.fileURL])
        relayoutPanels()
    }

    @objc func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        let attachments = pendingAttachments
        inputField.stringValue = ""
        pendingAttachments.removeAll()
        refreshAttachmentLabel()

        appendUser(text, attachments: attachments)
        isStreaming = true
        currentAssistantText = ""
        onSendMessage?(text, attachments)
    }

    @objc func returnToLennyTapped() {
        onReturnToLenny?()
    }

    @objc func attachButtonTapped() {
        presentAttachmentPicker()
    }

    func updatePlaceholder(_ text: String) {
        placeholderText = text
        guard let paddedCell = inputField.cell as? PaddedTextFieldCell else { return }
        let t = theme
        paddedCell.placeholderAttributedString = NSAttributedString(
            string: text,
            attributes: [.font: t.font, .foregroundColor: t.textDim]
        )
        inputField.needsDisplay = true
    }
}
