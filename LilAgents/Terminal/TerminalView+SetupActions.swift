import AppKit

extension TerminalView {
    @objc func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        hideWelcomeSuggestionsPanel()
        clearTranscriptSuggestionView()

        let attachments = pendingAttachments
        inputField.stringValue = ""
        pendingAttachments.removeAll()
        refreshAttachmentPreviews()

        appendUser(text, attachments: attachments)
        isStreaming = true
        currentAssistantText = ""
        setLiveStatus("Getting things moving…", isBusy: true, isError: false)
        onSendMessage?(text, attachments)
    }

    @objc func sendOrStopTapped() {
        if composerStatusLabel.isHidden {
            inputSubmitted()
        } else {
            onStopRequested?()
        }
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
