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

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 18, height: 16)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 12
        defaultPara.lineSpacing = 3
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        scrollView.documentView = textView
        addSubview(scrollView)

        liveStatusContainer.frame = NSRect(
            x: Layout.padding,
            y: frame.height - Layout.topInset - Layout.topControlHeight,
            width: frame.width - Layout.padding * 2,
            height: Layout.topControlHeight
        )
        liveStatusContainer.autoresizingMask = [.width, .minYMargin]
        stylePanel(liveStatusContainer, background: t.inputBg.withAlphaComponent(0.92), border: t.separatorColor.withAlphaComponent(0.34), radius: Layout.topControlHeight / 2)
        liveStatusContainer.alphaValue = 0
        liveStatusContainer.isHidden = true
        addSubview(liveStatusContainer)

        liveStatusSpinner.style = .spinning
        liveStatusSpinner.controlSize = .small
        liveStatusSpinner.frame = NSRect(x: 12, y: 8, width: 14, height: 14)
        liveStatusSpinner.isDisplayedWhenStopped = false
        liveStatusContainer.addSubview(liveStatusSpinner)

        liveStatusLabel.frame = NSRect(x: 34, y: 7, width: liveStatusContainer.frame.width - 46, height: 16)
        liveStatusLabel.autoresizingMask = [.width]
        liveStatusLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        liveStatusLabel.textColor = t.textDim
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusContainer.addSubview(liveStatusLabel)

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
