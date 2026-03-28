import AppKit

extension TerminalView {
    enum Layout {
        static let padding: CGFloat = 16
        static let topInset: CGFloat = 12
        static let topControlHeight: CGFloat = 30
        static let attachmentHeight: CGFloat = 20
        static let composerHeight: CGFloat = 56
        static let bottomInset: CGFloat = 14
        static let interSectionSpacing: CGFloat = 10
        static let panelGap: CGFloat = 6
    }

    func relayoutPanels() {
        let width = frame.width - Layout.padding * 2
        let composerTop = Layout.bottomInset + Layout.composerHeight

        var bottomCursor = composerTop

        if attachmentLabel.isHidden {
            attachmentLabel.frame = NSRect(x: Layout.padding + 2, y: bottomCursor, width: width - 4, height: 0)
        } else {
            let attachmentY = bottomCursor + Layout.panelGap
            attachmentLabel.frame = NSRect(x: Layout.padding + 2, y: attachmentY, width: width - 4, height: Layout.attachmentHeight)
            bottomCursor = attachmentY + Layout.attachmentHeight
        }

        if expertSuggestionContainer.isHidden || expertSuggestionStack.arrangedSubviews.isEmpty {
            expertSuggestionContainer.frame = NSRect(x: Layout.padding, y: bottomCursor, width: width, height: 0)
        } else {
            let buttonCount = CGFloat(expertSuggestionStack.arrangedSubviews.count)
            let buttonHeight: CGFloat = 36
            let stackHeight = max(buttonHeight, buttonCount * buttonHeight + max(0, buttonCount - 1) * expertSuggestionStack.spacing)
            let suggestionHeight = 14 + 16 + 10 + stackHeight + 14
            let suggestionY = bottomCursor + Layout.interSectionSpacing
            expertSuggestionContainer.frame = NSRect(x: Layout.padding, y: suggestionY, width: width, height: suggestionHeight)
            expertSuggestionLabel.frame = NSRect(x: 14, y: suggestionHeight - 30, width: width - 28, height: 16)
            expertSuggestionStack.frame = NSRect(x: 14, y: 14, width: width - 28, height: stackHeight)
            bottomCursor = suggestionY + suggestionHeight
        }

        let scrollTop = frame.height - Layout.topInset
        let scrollY = bottomCursor + Layout.interSectionSpacing
        let scrollHeight = max(160, scrollTop - scrollY)
        scrollView.frame = NSRect(x: Layout.padding, y: scrollY, width: width, height: scrollHeight)
        
        transcriptContainer.frame.size.width = width
        
        resizeTranscriptToFitContent()
    }

    func stylePanel(_ view: NSView, background: NSColor, border: NSColor, radius: CGFloat) {
        view.wantsLayer = true
        view.layer?.backgroundColor = background.cgColor
        view.layer?.cornerRadius = radius
        view.layer?.borderWidth = 0.75
        view.layer?.borderColor = border.cgColor
    }

    func setPanelVisibility(_ view: NSView, hidden: Bool) {
        view.isHidden = hidden
        view.alphaValue = hidden ? 0 : 1
    }
}
