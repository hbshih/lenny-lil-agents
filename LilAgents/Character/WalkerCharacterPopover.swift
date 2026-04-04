import AppKit

extension WalkerCharacter {
    func openOnboardingPopover() {
        showingCompletion = false
        hideBubble()

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        if popoverWindow == nil {
            createPopoverWindow()
        }

        terminalView?.inputField.isEditable = false
        terminalView?.updatePlaceholder("")
        let welcome = """
        Ask Lil-Lenny anything about product, growth, leadership, pricing, startups, or AI.

        Your desktop shortcut to LennyData.
        """
        terminalView?.appendStreamingText(welcome)
        terminalView?.endStreaming()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        syncPopoverPinState()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.closeOnboarding()
        }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closeOnboarding(); return nil }
            return event
        }
    }

    private func closeOnboarding() {
        removeEventMonitors()
        popoverWindow?.orderOut(nil)
        popoverWindow = nil
        terminalView = nil
        isIdleForPopover = false
        isOnboarding = false
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.0...3.0)
        setFacing(.front)
        controller?.completeOnboarding()
    }

    func openPopover() {
        if let siblings = controller?.characters {
            for sibling in siblings where sibling !== self && sibling.isIdleForPopover {
                if sibling.isPopoverPinned { continue }
                sibling.closePopover()
            }
        }

        isIdleForPopover = true
        isWalking = false
        isPaused = true
        setFacing(.front)

        showingCompletion = false
        hideBubble()

        if popoverWindow == nil {
            createPopoverWindow()
        }

        if claudeSession == nil {
            let session = ClaudeSession()
            session.focusedExpert = focusedExpert
            claudeSession = session
            wireSession(session)
            session.start()
        } else if claudeSession?.isRunning != true {
            claudeSession?.focusedExpert = focusedExpert
            claudeSession?.start()
        }

        refreshPopoverHeader()
        restoreTranscriptState()

        updatePopoverPosition()
        popoverWindow?.orderFrontRegardless()
        popoverWindow?.makeKey()
        syncPopoverPinState()

        if let terminal = terminalView {
            popoverWindow?.makeFirstResponder(terminal.inputField)
        }

        refreshPopoverEventMonitors()
    }

    @objc func expandToggleTapped() {
        guard let popover = popoverWindow, let screen = NSScreen.main else { return }
        isPopoverExpanded = !isPopoverExpanded

        let newHeight: CGFloat
        if isPopoverExpanded {
            let charFrame = window.frame
            let popoverBottomY = charFrame.maxY - 10
            let maxAvailable = screen.visibleFrame.maxY - 4 - popoverBottomY
            newHeight = min(max(maxAvailable, 500), screen.visibleFrame.height - 20)
        } else {
            newHeight = WalkerCharacter.defaultPopoverHeight
        }

        let currentFrame = popover.frame
        let charFrame = window.frame
        let desiredBottomY = charFrame.maxY - 10
        let clampedBottomY = max(
            screen.visibleFrame.minY + 4,
            min(desiredBottomY, screen.visibleFrame.maxY - newHeight - 4)
        )
        let newFrame = NSRect(x: currentFrame.minX, y: clampedBottomY, width: currentFrame.width, height: newHeight)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            popover.animator().setFrame(newFrame, display: true)
        }

        let symbolName = isPopoverExpanded
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            popoverExpandButton?.image = img.withSymbolConfiguration(config)
        }
    }

    func closePopover() {
        guard isIdleForPopover else { return }

        isPopoverExpanded = false
        if let btn = popoverExpandButton,
           let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            btn.image = img.withSymbolConfiguration(config)
        }
        // Reset window to default height before hiding
        if let popover = popoverWindow, popover.frame.height != WalkerCharacter.defaultPopoverHeight {
            let f = popover.frame
            let newFrame = NSRect(x: f.minX, y: f.minY, width: f.width, height: WalkerCharacter.defaultPopoverHeight)
            popover.setFrame(newFrame, display: false)
        }

        popoverWindow?.orderOut(nil)
        removeEventMonitors()

        isIdleForPopover = false

        if showingCompletion {
            completionBubbleExpiry = CACurrentMediaTime() + 3.0
            showBubble(text: currentPhrase, isCompletion: true)
        } else if isClaudeBusy {
            if currentActivityStatus.isEmpty {
                currentPhrase = ""
                lastPhraseUpdate = 0
                updateThinkingPhrase()
                showBubble(text: currentPhrase, isCompletion: false)
            } else {
                hideBubble()
            }
        } else {
            setFacing(.front)
        }

        let delay = Double.random(in: 2.0...5.0)
        pauseEndTime = CACurrentMediaTime() + delay
    }

    @objc func togglePopoverPinned() {
        isPopoverPinned.toggle()
        syncPopoverPinState()
        refreshPopoverEventMonitors()
    }

    @objc func closePopoverFromButton() {
        isPopoverPinned = false
        syncPopoverPinState()
        if isOnboarding {
            closeOnboarding()
            return
        }
        closePopover()
    }

    @objc func returnToGenieTapped() {
        controller?.returnToGenie()
    }

    func syncPopoverPinState() {
        if let pinButton = popoverPinButton {
            let symbolName = isPopoverPinned ? "pin.fill" : "pin"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: isPopoverPinned ? "Unpin" : "Pin") {
                let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
                pinButton.image = image.withSymbolConfiguration(config)
            }

            let t = resolvedTheme
            let normalBg = isPopoverPinned
                ? t.accentColor.withAlphaComponent(0.22).cgColor
                : t.separatorColor.withAlphaComponent(0.10).cgColor
            let hoverBg = isPopoverPinned
                ? t.accentColor.withAlphaComponent(0.32).cgColor
                : t.separatorColor.withAlphaComponent(0.22).cgColor
            pinButton.normalBg = normalBg
            pinButton.hoverBg = hoverBg
            pinButton.layer?.backgroundColor = normalBg
            pinButton.contentTintColor = isPopoverPinned ? t.accentColor : t.textDim
        }

        terminalView?.isPinnedOpen = isPopoverPinned
    }

    func refreshPopoverEventMonitors() {
        removeEventMonitors()
        guard isIdleForPopover, !isPopoverPinned else { return }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let popover = self.popoverWindow else { return }
            let popoverFrame = popover.frame
            let charFrame = self.window.frame
            if !popoverFrame.contains(NSEvent.mouseLocation) && !charFrame.contains(NSEvent.mouseLocation) {
                self.closePopover()
            }
        }

        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePopover()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
    }

    func updateInputPlaceholder() {
        if let expert = focusedExpert {
            terminalView?.updatePlaceholder("Ask \(expert.name) a follow-up")
        } else {
            terminalView?.updatePlaceholder("Ask a question or drop in a file")
        }
    }
}
