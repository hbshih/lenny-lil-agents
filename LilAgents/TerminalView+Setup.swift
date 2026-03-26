import AppKit

extension TerminalView {
    func setupViews() {
        let t = theme
        let inputHeight: CGFloat = 30
        let attachmentHeight: CGFloat = 22
        let topControlHeight: CGFloat = 52
        let padding: CGFloat = 10

        scrollView.frame = NSRect(
            x: padding, y: inputHeight + attachmentHeight + padding + 8,
            width: frame.width - padding * 2,
            height: frame.height - inputHeight - attachmentHeight - topControlHeight - padding - 14
        )
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = t.textPrimary
        textView.font = t.font
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 2, height: 4)
        let defaultPara = NSMutableParagraphStyle()
        defaultPara.paragraphSpacing = 8
        textView.defaultParagraphStyle = defaultPara
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: t.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scrollView.documentView = textView
        addSubview(scrollView)

        returnButton.frame = NSRect(
            x: frame.width - 118,
            y: frame.height - topControlHeight - 6,
            width: 108,
            height: 24
        )
        returnButton.autoresizingMask = [.minXMargin, .minYMargin]
        returnButton.bezelStyle = .rounded
        returnButton.font = NSFont.systemFont(ofSize: max(11, t.font.pointSize - 1), weight: .semibold)
        returnButton.contentTintColor = t.accentColor
        returnButton.target = self
        returnButton.action = #selector(returnToLennyTapped)
        returnButton.isHidden = true
        addSubview(returnButton)

        liveStatusContainer.frame = NSRect(
            x: padding,
            y: frame.height - topControlHeight - 4,
            width: frame.width - padding * 2 - 126,
            height: 24
        )
        liveStatusContainer.autoresizingMask = [.width, .minYMargin]
        liveStatusContainer.wantsLayer = true
        liveStatusContainer.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.42).cgColor
        liveStatusContainer.layer?.cornerRadius = 12
        liveStatusContainer.layer?.borderWidth = 1
        liveStatusContainer.layer?.borderColor = t.separatorColor.cgColor
        liveStatusContainer.isHidden = true
        addSubview(liveStatusContainer)

        liveStatusSpinner.style = .spinning
        liveStatusSpinner.controlSize = .small
        liveStatusSpinner.frame = NSRect(x: 8, y: 4, width: 16, height: 16)
        liveStatusSpinner.isDisplayedWhenStopped = false
        liveStatusContainer.addSubview(liveStatusSpinner)

        liveStatusLabel.frame = NSRect(x: 30, y: 3, width: liveStatusContainer.frame.width - 38, height: 18)
        liveStatusLabel.autoresizingMask = [.width]
        liveStatusLabel.font = NSFont.systemFont(ofSize: max(11, t.font.pointSize - 0.5), weight: .medium)
        liveStatusLabel.textColor = t.textDim
        liveStatusLabel.lineBreakMode = .byTruncatingTail
        liveStatusContainer.addSubview(liveStatusLabel)

        attachmentLabel.frame = NSRect(
            x: padding, y: inputHeight + 8,
            width: frame.width - padding * 2,
            height: attachmentHeight
        )
        attachmentLabel.autoresizingMask = [.width]
        attachmentLabel.font = NSFont.systemFont(ofSize: max(11, t.font.pointSize - 1), weight: .medium)
        attachmentLabel.textColor = t.textDim
        attachmentLabel.lineBreakMode = .byTruncatingMiddle
        attachmentLabel.isHidden = true
        addSubview(attachmentLabel)

        inputField.frame = NSRect(
            x: padding, y: 6,
            width: frame.width - padding * 2,
            height: inputHeight
        )
        inputField.autoresizingMask = [.width]
        inputField.focusRingType = .none
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
        addSubview(inputField)

        registerForDraggedTypes([.fileURL])
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

    func setReturnToLennyVisible(_ visible: Bool) {
        returnButton.isHidden = !visible
    }

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        liveStatusContainer.isHidden = text.isEmpty
        guard !text.isEmpty else {
            liveStatusSpinner.stopAnimation(nil)
            return
        }

        liveStatusContainer.layer?.borderColor = (isError ? t.errorColor : t.separatorColor).cgColor
        liveStatusContainer.layer?.backgroundColor = (isError ? t.errorColor.withAlphaComponent(0.08) : t.inputBg.withAlphaComponent(0.42)).cgColor
        liveStatusLabel.textColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        liveStatusLabel.stringValue = text

        if isBusy {
            liveStatusSpinner.startAnimation(nil)
        } else {
            liveStatusSpinner.stopAnimation(nil)
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.stringValue = ""
        liveStatusSpinner.stopAnimation(nil)
        liveStatusContainer.isHidden = true
    }
}
