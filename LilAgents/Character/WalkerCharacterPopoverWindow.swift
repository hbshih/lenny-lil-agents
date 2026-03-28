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
        let popoverWidth: CGFloat = 640
        let popoverHeight: CGFloat = 600

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

        let titleBarHeight: CGFloat = 64
        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight, width: popoverWidth, height: titleBarHeight))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.55).cgColor
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: focusedExpert?.name ?? t.titleString)
        titleLabel.font = NSFont.systemFont(ofSize: 21, weight: .semibold)
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 24, y: 27, width: popoverWidth - 220, height: 26)
        titleBar.addSubview(titleLabel)
        popoverTitleLabel = titleLabel

        let subtitle = NSTextField(labelWithString: focusedExpert == nil ? "Archive-grounded answers" : "Focused follow-up mode")
        subtitle.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        subtitle.textColor = t.textDim
        subtitle.frame = NSRect(x: 24, y: 11, width: popoverWidth - 220, height: 16)
        titleBar.addSubview(subtitle)
        popoverSubtitleLabel = subtitle

        let returnPill = NSButton(title: "", target: self, action: #selector(returnToGenieTapped))
        returnPill.frame = NSRect(x: popoverWidth - 150, y: 18, width: 126, height: 28)
        returnPill.isBordered = false
        returnPill.wantsLayer = true
        returnPill.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.88).cgColor
        returnPill.layer?.cornerRadius = 14
        returnPill.layer?.borderWidth = 0.75
        returnPill.layer?.borderColor = t.separatorColor.withAlphaComponent(0.50).cgColor
        returnPill.attributedTitle = NSAttributedString(
            string: "Back to Lenny",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: t.titleText
            ]
        )
        returnPill.isHidden = focusedExpert == nil
        titleBar.addSubview(returnPill)
        popoverReturnButton = returnPill

        let sep = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight - 1, width: popoverWidth, height: 0.5))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.35).cgColor
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
