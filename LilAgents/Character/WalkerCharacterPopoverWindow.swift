import AppKit

extension WalkerCharacter {
    var resolvedTheme: PopoverTheme {
        (themeOverride ?? PopoverTheme.current).withCharacterColor(characterColor).withCustomFont()
    }

    func refreshPopoverHeader() {
        popoverTitleLabel?.stringValue = focusedExpert?.name ?? resolvedTheme.titleString
        popoverSubtitleLabel?.stringValue = focusedExpert == nil ? "Archive-grounded answers" : "Focused follow-up mode"
        popoverReturnButton?.isHidden = focusedExpert == nil
    }

    func createPopoverWindow() {
        let t = resolvedTheme
        let popoverWidth: CGFloat = 560
        let popoverHeight: CGFloat = 460

        let win = KeyableWindow(
            contentRect: CGRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let rgbPopoverBackground = t.rgbPopoverBackground
        let brightness = rgbPopoverBackground.redComponent * 0.299 + rgbPopoverBackground.greenComponent * 0.587 + rgbPopoverBackground.blueComponent * 0.114
        let isDark = brightness < 0.5
        win.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        container.material = isDark ? .hudWindow : .sidebar
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = t.popoverCornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor
        container.autoresizingMask = [.width, .height]

        let tintView = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        tintView.wantsLayer = true
        let origAlpha = t.popoverBg.cgColor.alpha
        tintView.layer?.backgroundColor = t.popoverBg.withAlphaComponent(min(origAlpha * 0.86, 0.92)).cgColor
        tintView.autoresizingMask = [.width, .height]
        container.addSubview(tintView)

        let titleBarHeight: CGFloat = 52
        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight, width: popoverWidth, height: titleBarHeight))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.50).cgColor
        titleBar.autoresizingMask = [.width, .minYMargin]
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: focusedExpert?.name ?? t.titleString)
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 22, y: 17, width: popoverWidth - 200, height: 22)
        titleBar.addSubview(titleLabel)
        popoverTitleLabel = titleLabel

        let subtitle = NSTextField(labelWithString: focusedExpert == nil ? "Archive-grounded answers" : "Focused follow-up mode")
        subtitle.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = t.textDim.withAlphaComponent(0.75)
        subtitle.frame = NSRect(x: 22, y: 5, width: popoverWidth - 200, height: 14)
        titleBar.addSubview(subtitle)
        popoverSubtitleLabel = subtitle

        let expandButtonSize: CGFloat = 28
        let expandButtonX = popoverWidth - 16 - expandButtonSize
        let expandButton = HoverButton(title: "", target: self, action: #selector(expandToggleTapped))
        expandButton.frame = NSRect(x: expandButtonX, y: (titleBarHeight - expandButtonSize) / 2, width: expandButtonSize, height: expandButtonSize)
        expandButton.isBordered = false
        expandButton.wantsLayer = true
        expandButton.normalBg = t.separatorColor.withAlphaComponent(0.10).cgColor
        expandButton.hoverBg = t.separatorColor.withAlphaComponent(0.22).cgColor
        expandButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.10).cgColor
        expandButton.layer?.cornerRadius = expandButtonSize / 2
        if let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Expand") {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            expandButton.image = img.withSymbolConfiguration(config)
        }
        expandButton.imageScaling = .scaleProportionallyDown
        expandButton.contentTintColor = t.textDim
        titleBar.addSubview(expandButton)
        popoverExpandButton = expandButton

        let returnPill = HoverButton(title: "", target: self, action: #selector(returnToGenieTapped))
        let returnPillWidth: CGFloat = 118
        returnPill.frame = NSRect(x: expandButtonX - 8 - returnPillWidth, y: 14, width: returnPillWidth, height: 26)
        returnPill.isBordered = false
        returnPill.wantsLayer = true
        returnPill.normalBg = t.inputBg.withAlphaComponent(0.90).cgColor
        returnPill.hoverBg = t.accentColor.withAlphaComponent(0.08).cgColor
        returnPill.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.90).cgColor
        returnPill.layer?.cornerRadius = 13
        returnPill.layer?.borderWidth = 0.75
        returnPill.layer?.borderColor = t.separatorColor.withAlphaComponent(0.55).cgColor
        returnPill.attributedTitle = NSAttributedString(
            string: "← Back to Lenny",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: t.accentColor
            ]
        )
        returnPill.isHidden = focusedExpert == nil
        titleBar.addSubview(returnPill)
        popoverReturnButton = returnPill

        let sep = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight - 1, width: popoverWidth, height: 0.5))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.30).cgColor
        sep.autoresizingMask = [.width, .minYMargin]
        container.addSubview(sep)

        let terminal = TerminalView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight - titleBarHeight - 1))
        terminal.characterColor = characterColor
        terminal.themeOverride = themeOverride
        terminal.autoresizingMask = [.width, .height]
        terminal.onSendMessage = { [weak self] message, attachments in
            self?.claudeSession?.focusedExpert = self?.focusedExpert
            self?.claudeSession?.send(message: message, attachments: attachments)
        }
        terminal.onReturnToLenny = { [weak self] in
            self?.controller?.returnToGenie()
        }
        terminal.onSelectExpert = { [weak self] expert in
            self?.controller?.openDialog(for: expert)
        }
        terminal.setReturnToLennyVisible(false)
        container.addSubview(terminal)

        win.contentView = container
        popoverWindow = win
        terminalView = terminal
        refreshPopoverHeader()
    }
}
