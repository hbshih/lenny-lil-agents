import AppKit

extension TerminalView {
    @objc func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        if isShowingInitialWelcomeState {
            transcriptStack.arrangedSubviews.forEach { view in
                transcriptStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            transcriptSuggestionView = nil
            transcriptLiveStatusView = nil
            currentAssistantText = ""
            isShowingInitialWelcomeState = false
        }

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
        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
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
