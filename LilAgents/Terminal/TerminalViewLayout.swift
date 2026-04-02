import AppKit

extension TerminalView {
    enum Layout {
        static let padding: CGFloat = 16
        static let topInset: CGFloat = 12
        static let topControlHeight: CGFloat = 30
        static let attachmentStripHeight: CGFloat = 58
        static let attachmentChipHeight: CGFloat = 42
        static let composerHeight: CGFloat = 56
        static let bottomInset: CGFloat = 14
        static let interSectionSpacing: CGFloat = 24
        static let panelGap: CGFloat = 6
        static let welcomePanelGapFromComposer: CGFloat = 12
    }

    func relayoutPanels() {
        let width = frame.width - Layout.padding * 2
        let composerTop = Layout.bottomInset + Layout.composerHeight

        var bottomCursor = composerTop

        if attachmentStrip.isHidden {
            attachmentStrip.frame = NSRect(x: Layout.padding, y: bottomCursor, width: width, height: 0)
        } else {
            let attachmentY = bottomCursor + Layout.panelGap
            attachmentStrip.frame = NSRect(x: Layout.padding, y: attachmentY, width: width, height: Layout.attachmentStripHeight)
            attachmentScrollView.frame = NSRect(x: 10, y: 8, width: width - 20, height: Layout.attachmentChipHeight)
            attachmentHintLabel.frame = NSRect(x: 14, y: 18, width: width - 28, height: 16)
            bottomCursor = attachmentY + Layout.attachmentStripHeight
        }

        let welcomePanelHeight: CGFloat
        if expertSuggestionContainer.isHidden {
            welcomePanelHeight = 0
        } else {
            expertSuggestionStack.layoutSubtreeIfNeeded()
            welcomePanelHeight = ceil(expertSuggestionStack.fittingSize.height)
        }

        let welcomePanelY = welcomePanelHeight > 0 ? bottomCursor + Layout.welcomePanelGapFromComposer : bottomCursor
        expertSuggestionContainer.frame = NSRect(x: Layout.padding, y: welcomePanelY, width: width, height: welcomePanelHeight)
        expertSuggestionLabel.frame = NSRect(x: 16, y: max(0, welcomePanelHeight - 28), width: width - 32, height: 16)
        expertSuggestionStack.frame = NSRect(x: 0, y: 0, width: width, height: max(0, welcomePanelHeight))
        bottomCursor = welcomePanelY + welcomePanelHeight

        let scrollTop = frame.height - Layout.topInset
        let scrollY = bottomCursor + Layout.interSectionSpacing
        let scrollHeight = max(160, scrollTop - scrollY)
        scrollView.frame = NSRect(x: Layout.padding, y: scrollY, width: width, height: scrollHeight)
        
        transcriptContainer.frame.size.width = width
        
        resizeTranscriptToFitContent()
        layoutAttachmentPreviewDocument()
        refreshComposerContentLayout()
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

    func layoutAttachmentPreviewDocument() {
        attachmentPreviewStack.layoutSubtreeIfNeeded()
        let stackWidth = attachmentPreviewStack.fittingSize.width
        let viewportWidth = attachmentScrollView.contentSize.width
        let contentWidth = max(viewportWidth, stackWidth)
        attachmentPreviewDocumentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: Layout.attachmentChipHeight)
    }
}
