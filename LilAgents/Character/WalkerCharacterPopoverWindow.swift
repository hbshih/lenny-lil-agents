import AppKit

extension WalkerCharacter {
    var resolvedTheme: PopoverTheme {
        (themeOverride ?? PopoverTheme.current).withCharacterColor(characterColor).withCustomFont()
    }

    func refreshPopoverHeader() {
        popoverTitleLabel?.stringValue = focusedExpert?.name ?? resolvedTheme.titleString
        popoverSubtitleLabel?.stringValue = focusedExpert?.title ?? "Your desktop shortcut to LennyData."
        popoverReturnButton?.isHidden = focusedExpert == nil
    }

    func createPopoverWindow() {
        let t = resolvedTheme
        let popoverWidth: CGFloat = 468
        let popoverHeight: CGFloat = WalkerCharacter.defaultPopoverHeight
        let shellCornerRadius: CGFloat = 18

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

        let container = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: popoverHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.popoverBg.cgColor
        container.layer?.cornerRadius = shellCornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = t.popoverBorderWidth
        container.layer?.borderColor = t.popoverBorder.cgColor
        container.autoresizingMask = [.width, .height]

        let titleBarHeight: CGFloat = 52
        let titleBar = NSView(frame: NSRect(x: 0, y: popoverHeight - titleBarHeight, width: popoverWidth, height: titleBarHeight))
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = t.titleBarBg.cgColor
        titleBar.layer?.cornerRadius = shellCornerRadius
        titleBar.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        titleBar.autoresizingMask = [.width, .minYMargin]
        container.addSubview(titleBar)

        let titleLabel = NSTextField(labelWithString: focusedExpert?.name ?? t.titleString)
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = t.titleText
        titleLabel.frame = NSRect(x: 20, y: 17, width: popoverWidth - 244, height: 22)
        titleBar.addSubview(titleLabel)
        popoverTitleLabel = titleLabel

        let subtitle = NSTextField(labelWithString: focusedExpert?.title ?? "Your desktop shortcut to LennyData.")
        subtitle.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = t.textDim.withAlphaComponent(0.75)
        subtitle.frame = NSRect(x: 20, y: 5, width: popoverWidth - 244, height: 14)
        titleBar.addSubview(subtitle)
        popoverSubtitleLabel = subtitle

        let controlButtonSize: CGFloat = 28
        let buttonSpacing: CGFloat = 6
        let closeButtonX = popoverWidth - 12 - controlButtonSize
        let pinButtonX = closeButtonX - buttonSpacing - controlButtonSize
        let expandButtonX = pinButtonX - buttonSpacing - controlButtonSize
        let settingsButtonX = expandButtonX - buttonSpacing - controlButtonSize

        let settingsButton = HoverButton(title: "", target: NSApp.delegate, action: #selector(AppDelegate.openSettings))
        settingsButton.frame = NSRect(x: settingsButtonX, y: (titleBarHeight - controlButtonSize) / 2, width: controlButtonSize, height: controlButtonSize)
        settingsButton.isBordered = false
        settingsButton.wantsLayer = true
        settingsButton.normalBg = t.separatorColor.withAlphaComponent(0.10).cgColor
        settingsButton.hoverBg = t.separatorColor.withAlphaComponent(0.22).cgColor
        settingsButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.10).cgColor
        settingsButton.layer?.cornerRadius = controlButtonSize / 2
        if let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Open settings") {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            settingsButton.image = image.withSymbolConfiguration(config)
        }
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.contentTintColor = t.textDim
        settingsButton.toolTip = "Open settings"
        titleBar.addSubview(settingsButton)
        popoverSettingsButton = settingsButton

        let expandButton = HoverButton(title: "", target: self, action: #selector(expandToggleTapped))
        expandButton.frame = NSRect(x: expandButtonX, y: (titleBarHeight - controlButtonSize) / 2, width: controlButtonSize, height: controlButtonSize)
        expandButton.isBordered = false
        expandButton.wantsLayer = true
        expandButton.normalBg = t.separatorColor.withAlphaComponent(0.10).cgColor
        expandButton.hoverBg = t.separatorColor.withAlphaComponent(0.22).cgColor
        expandButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.10).cgColor
        expandButton.layer?.cornerRadius = controlButtonSize / 2
        if let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Expand") {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            expandButton.image = img.withSymbolConfiguration(config)
        }
        expandButton.imageScaling = .scaleProportionallyDown
        expandButton.contentTintColor = t.textDim
        expandButton.toolTip = "Expand"
        titleBar.addSubview(expandButton)
        popoverExpandButton = expandButton

        let pinButton = HoverButton(title: "", target: self, action: #selector(togglePopoverPinned))
        pinButton.frame = NSRect(x: pinButtonX, y: (titleBarHeight - controlButtonSize) / 2, width: controlButtonSize, height: controlButtonSize)
        pinButton.isBordered = false
        pinButton.wantsLayer = true
        pinButton.normalBg = t.separatorColor.withAlphaComponent(0.10).cgColor
        pinButton.hoverBg = t.separatorColor.withAlphaComponent(0.22).cgColor
        pinButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.10).cgColor
        pinButton.layer?.cornerRadius = controlButtonSize / 2
        pinButton.imageScaling = .scaleProportionallyDown
        pinButton.contentTintColor = t.textDim
        pinButton.toolTip = "Pin"
        titleBar.addSubview(pinButton)
        popoverPinButton = pinButton

        let closeButton = HoverButton(title: "", target: self, action: #selector(closePopoverFromButton))
        closeButton.frame = NSRect(x: closeButtonX, y: (titleBarHeight - controlButtonSize) / 2, width: controlButtonSize, height: controlButtonSize)
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        closeButton.normalBg = t.separatorColor.withAlphaComponent(0.10).cgColor
        closeButton.hoverBg = t.errorColor.withAlphaComponent(0.20).cgColor
        closeButton.layer?.backgroundColor = t.separatorColor.withAlphaComponent(0.10).cgColor
        closeButton.layer?.cornerRadius = controlButtonSize / 2
        if let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            closeButton.image = image.withSymbolConfiguration(config)
        }
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.contentTintColor = t.textDim
        closeButton.toolTip = "Close"
        titleBar.addSubview(closeButton)
        popoverCloseButton = closeButton

        let returnPill = HoverButton(title: "", target: self, action: #selector(returnToGenieTapped))
        let returnPillWidth: CGFloat = 118
        returnPill.frame = NSRect(x: settingsButtonX - 8 - returnPillWidth, y: 14, width: returnPillWidth, height: 26)
        returnPill.isBordered = false
        returnPill.wantsLayer = true
        returnPill.normalBg = t.inputBg.withAlphaComponent(0.90).cgColor
        returnPill.hoverBg = t.accentColor.withAlphaComponent(0.08).cgColor
        returnPill.layer?.backgroundColor = t.inputBg.withAlphaComponent(0.90).cgColor
        returnPill.layer?.cornerRadius = 13
        returnPill.layer?.borderWidth = 0.75
        returnPill.layer?.borderColor = t.separatorColor.withAlphaComponent(0.55).cgColor
        returnPill.attributedTitle = NSAttributedString(
            string: "Back to Lil-Lenny",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: t.accentColor
            ]
        )
        returnPill.toolTip = "Return to Lil-Lenny"
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
        terminal.isPinnedOpen = isPopoverPinned
        terminal.onSendMessage = { [weak self] message, attachments in
            self?.noteLiveStatusEvent()
            self?.setCurrentActivityStatus("Getting things moving…")
            self?.updateExpertNameTag()
            self?.claudeSession?.focusedExpert = self?.focusedExpert
            self?.claudeSession?.send(message: message, attachments: attachments)
        }
        terminal.onStopRequested = { [weak self] in
            self?.claudeSession?.cancelActiveTurn()
            self?.setCurrentActivityStatus("")
            self?.terminalView?.endStreaming()
            self?.terminalView?.clearLiveStatus()
        }
        terminal.onReturnToLenny = { [weak self] in
            self?.controller?.returnToGenie()
        }
        terminal.onSelectExpert = { [weak self] expert in
            self?.controller?.focus(on: expert)
        }
        terminal.onSelectExpertSuggestion = { [weak self] entryID, expert in
            guard let self else { return }
            self.claudeSession?.collapseExpertSuggestionEntry(entryID, pickedExpert: expert, for: self.focusedExpert)
            self.controller?.focus(on: expert)
        }
        terminal.onEditExpertSuggestion = { [weak self] entryID in
            guard let self else { return }
            self.claudeSession?.expandExpertSuggestionEntry(entryID, for: self.focusedExpert)
            self.restoreTranscriptState()
        }
        terminal.onTogglePinned = { [weak self] in
            self?.togglePopoverPinned()
        }
        terminal.onCloseRequested = { [weak self] in
            self?.closePopoverFromButton()
        }
        terminal.onRefreshSetupState = { [weak self] in
            guard let self, let session = self.claudeSession, !session.isRunning else { return }
            session.focusedExpert = self.focusedExpert
            session.start()
        }
        terminal.setReturnToLennyVisible(false)
        container.addSubview(terminal)

        win.contentView = container
        popoverWindow = win
        terminalView = terminal
        refreshPopoverHeader()
        syncPopoverPinState()
    }
}
