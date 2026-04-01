import AppKit

extension ChatBubbleView {
    func setText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.setAttributedString(newText)
        updateTextAlignment()
        recalculateSize()
    }

    func appendText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.append(newText)
        updateTextAlignment()
        recalculateSize()
    }

    @objc func copyTapped() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        onCopy?()
    }

    @objc func followUpTapped() {
        WalkerCharacter.playSelectionSound()
        onFollowUp?()
    }

    func configureTextContainer() {
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    }

    func updateTextAlignment() {
        guard let storage = textView.textStorage else { return }

        let shouldLeftAlign = isUser && (storage.string.contains("\n") || storage.length > 72)
        let alignment: NSTextAlignment = shouldLeftAlign ? .left : (isUser ? .right : .left)

        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.alignment = alignment
            if style.lineSpacing == 0 {
                style.lineSpacing = 4
            }
            if style.paragraphSpacing == 0 {
                style.paragraphSpacing = 7
            }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        storage.endEditing()
        textView.alignment = alignment
    }

    func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)

        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28
        let maxWidth: CGFloat = 380
        let desiredWidth = targetContentWidth + paddingWidth

        if let textWidthConstraint {
            textView.removeConstraint(textWidthConstraint)
            self.textWidthConstraint = nil
        }
        if let textHeightConstraint {
            textView.removeConstraint(textHeightConstraint)
            self.textHeightConstraint = nil
        }

        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: maxWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: newRect.height + 24)
        } else {
            let finalWidth = max(desiredWidth, 60)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: finalWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: rect.height + 24)
        }

        textWidthConstraint?.isActive = true
        textHeightConstraint?.isActive = true
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
                WalkerCharacter.playSelectionSound()
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}
