import AppKit

extension TerminalView {
    func setupViews() {
        let t = theme
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        isExpertMode = false

        // Corner radius design system:
        //   Window: 18  ·  Composer shell: full pill  ·  Attachment strip: full pill  ·  Buttons: circle
        let composerRadius = Layout.composerHeight / 2
        let attachmentRadius = Layout.attachmentStripHeight / 2
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
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
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
            transcriptStack.topAnchor.constraint(equalTo: transcriptContainer.topAnchor)
        ])
        
        transcriptContainer.wantsLayer = true
        transcriptContainer.layer?.backgroundColor = NSColor.clear.cgColor
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
        expertSuggestionContainer.wantsLayer = true
        expertSuggestionContainer.layer?.backgroundColor = NSColor.clear.cgColor
        expertSuggestionContainer.layer?.borderWidth = 0
        expertSuggestionContainer.layer?.cornerRadius = 0
        expertSuggestionContainer.alphaValue = 0
        expertSuggestionContainer.isHidden = true
        addSubview(expertSuggestionContainer)

        expertSuggestionLabel.frame = NSRect(x: 16, y: 96, width: expertSuggestionContainer.frame.width - 32, height: 16)
        expertSuggestionLabel.autoresizingMask = [.width]
        expertSuggestionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        expertSuggestionLabel.textColor = t.textDim
        expertSuggestionLabel.stringValue = "Have follow-up questions? Chat with these experts."
        expertSuggestionLabel.isHidden = true
        expertSuggestionContainer.addSubview(expertSuggestionLabel)

        expertSuggestionStack.orientation = .vertical
        expertSuggestionStack.alignment = .width
        expertSuggestionStack.distribution = .fill
        expertSuggestionStack.spacing = 8
        expertSuggestionStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        expertSuggestionStack.frame = NSRect(x: 16, y: 12, width: expertSuggestionContainer.frame.width - 32, height: 76)
        expertSuggestionStack.autoresizingMask = [.width, .height]
        expertSuggestionContainer.addSubview(expertSuggestionStack)

        attachmentStrip.frame = NSRect(
            x: Layout.padding,
            y: Layout.bottomInset + Layout.composerHeight + Layout.panelGap,
            width: frame.width - Layout.padding * 2,
            height: Layout.attachmentStripHeight
        )
        attachmentStrip.autoresizingMask = [.width, .maxYMargin]
        stylePanel(
            attachmentStrip,
            background: t.inputBg.withAlphaComponent(0.96),
            border: t.separatorColor.withAlphaComponent(0.36),
            radius: attachmentRadius
        )
        attachmentStrip.isHidden = true
        addSubview(attachmentStrip)

        attachmentScrollView.frame = NSRect(x: 10, y: 8, width: attachmentStrip.frame.width - 20, height: Layout.attachmentChipHeight)
        attachmentScrollView.autoresizingMask = [.width]
        attachmentScrollView.drawsBackground = false
        attachmentScrollView.hasVerticalScroller = false
        attachmentScrollView.hasHorizontalScroller = false
        attachmentScrollView.borderType = .noBorder
        attachmentScrollView.backgroundColor = .clear

        attachmentPreviewDocumentView.wantsLayer = true
        attachmentPreviewDocumentView.layer?.backgroundColor = NSColor.clear.cgColor
        attachmentPreviewDocumentView.frame = NSRect(x: 0, y: 0, width: attachmentScrollView.contentSize.width, height: Layout.attachmentChipHeight)
        attachmentPreviewDocumentView.autoresizingMask = [.width]
        attachmentScrollView.documentView = attachmentPreviewDocumentView
        attachmentStrip.addSubview(attachmentScrollView)

        attachmentPreviewStack.orientation = .horizontal
        attachmentPreviewStack.alignment = .centerY
        attachmentPreviewStack.distribution = .gravityAreas
        attachmentPreviewStack.spacing = 8
        attachmentPreviewStack.translatesAutoresizingMaskIntoConstraints = false
        attachmentPreviewDocumentView.addSubview(attachmentPreviewStack)

        NSLayoutConstraint.activate([
            attachmentPreviewStack.leadingAnchor.constraint(equalTo: attachmentPreviewDocumentView.leadingAnchor),
            attachmentPreviewStack.topAnchor.constraint(equalTo: attachmentPreviewDocumentView.topAnchor),
            attachmentPreviewStack.bottomAnchor.constraint(equalTo: attachmentPreviewDocumentView.bottomAnchor)
        ])

        attachmentHintLabel.frame = NSRect(x: 14, y: 18, width: attachmentStrip.frame.width - 28, height: 16)
        attachmentHintLabel.autoresizingMask = [.width]
        attachmentHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        attachmentHintLabel.textColor = t.textDim
        attachmentHintLabel.alignment = .center
        attachmentHintLabel.stringValue = "Drop files, screenshots, code, or links here"
        attachmentHintLabel.isHidden = true
        attachmentStrip.addSubview(attachmentHintLabel)

        let composerPanel = NSView(frame: NSRect(
            x: Layout.padding,
            y: Layout.bottomInset,
            width: frame.width - Layout.padding * 2,
            height: Layout.composerHeight
        ))
        composerPanel.autoresizingMask = [.width, .maxYMargin]
        stylePanel(composerPanel, background: t.inputBg.withAlphaComponent(0.98), border: t.separatorColor.withAlphaComponent(0.40), radius: composerRadius)
        addSubview(composerPanel)

        let controlButtonSize: CGFloat = 34
        let rightInset: CGFloat = 11                                         // symmetric with left text inset (~11px from circle edge to panel edge)
        let sendY = (Layout.composerHeight - controlButtonSize) / 2
        let attachY = sendY
        let sendX = composerPanel.frame.width - rightInset - controlButtonSize
        let attachX = sendX - 10 - controlButtonSize

        sendButton.frame = NSRect(x: sendX, y: sendY, width: controlButtonSize, height: controlButtonSize)
        sendButton.autoresizingMask = [.minXMargin]
        sendButton.isBordered = false
        sendButton.wantsLayer = true
        sendButton.normalBg = t.accentColor.cgColor
        sendButton.hoverBg = t.accentColor.withAlphaComponent(0.80).cgColor
        sendButton.layer?.backgroundColor = t.accentColor.cgColor
        sendButton.layer?.cornerRadius = controlButtonSize / 2
        if let img = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send message") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            sendButton.image = img.withSymbolConfiguration(config)
        }
        sendButton.imageScaling = .scaleProportionallyDown
        sendButton.contentTintColor = .white
        sendButton.toolTip = "Send"
        sendButton.target = self
        sendButton.action = #selector(sendOrStopTapped)
        composerPanel.addSubview(sendButton)

        attachButton.frame = NSRect(x: attachX, y: attachY, width: controlButtonSize, height: controlButtonSize)
        attachButton.autoresizingMask = [.minXMargin]
        attachButton.isBordered = false
        attachButton.wantsLayer = true
        attachButton.normalBg = t.separatorColor.withAlphaComponent(0.14).cgColor
        attachButton.hoverBg = t.separatorColor.withAlphaComponent(0.28).cgColor
        attachButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.14).cgColor
        attachButton.layer?.cornerRadius = controlButtonSize / 2
        if let img = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Attach file") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            attachButton.image = img.withSymbolConfiguration(config)
        }
        attachButton.imageScaling = .scaleProportionallyDown
        attachButton.contentTintColor = t.textDim
        attachButton.toolTip = "Add attachment"
        attachButton.target = self
        attachButton.action = #selector(attachButtonTapped)
        composerPanel.addSubview(attachButton)

        inputField.frame = NSRect(
            x: 16,
            y: 8,
            width: attachX - 16 - 8,   // 16px left inset, 8px gap before attach button
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

        composerStatusLabel.isEditable = false
        composerStatusLabel.drawsBackground = false
        composerStatusLabel.isBordered = false
        composerStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        composerStatusLabel.textColor = t.textDim
        composerStatusLabel.lineBreakMode = .byTruncatingTail
        composerStatusLabel.isHidden = true
        composerStatusLabel.frame = NSRect(x: 16, y: (Layout.composerHeight - 18) / 2, width: composerPanel.frame.width - 16 - rightInset - controlButtonSize - 8, height: 18)
        composerStatusLabel.autoresizingMask = [.width]
        composerPanel.addSubview(composerStatusLabel)

        registerForDraggedTypes([.fileURL, .URL, .string, .tiff, .png])
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.refreshWelcomePreviewIfNeeded()
        }
        refreshComposerContentLayout()
        relayoutPanels()
    }

    func refreshComposerContentLayout(showingStatus: Bool? = nil) {
        guard let composerPanel = inputField.superview else { return }

        let isShowingStatus = showingStatus ?? !composerStatusLabel.isHidden
        let controlButtonSize: CGFloat = 34
        let rightInset: CGFloat = 11
        let sideInset: CGFloat = 16
        let controlGap: CGFloat = 10

        let sendY = (Layout.composerHeight - controlButtonSize) / 2
        let sendX = composerPanel.bounds.width - rightInset - controlButtonSize
        let attachX = sendX - controlGap - controlButtonSize

        sendButton.frame = NSRect(x: sendX, y: sendY, width: controlButtonSize, height: controlButtonSize)
        attachButton.frame = NSRect(x: attachX, y: sendY, width: controlButtonSize, height: controlButtonSize)

        inputField.frame = NSRect(
            x: sideInset,
            y: 8,
            width: max(80, attachX - sideInset - 8),
            height: Layout.composerHeight - 16
        )

        let statusLeading: CGFloat = sideInset
        let statusTrailingInset: CGFloat = isShowingStatus ? 16 : (rightInset + controlButtonSize + 8)
        composerStatusLabel.frame = NSRect(
            x: statusLeading,
            y: (Layout.composerHeight - 18) / 2,
            width: max(80, composerPanel.bounds.width - statusLeading - statusTrailingInset),
            height: 18
        )
    }
}
