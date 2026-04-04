import AppKit

extension WalkerCharacter {
    func setup() {
        loadDirectionalImages()

        let screen = NSScreen.main!
        let dockTopY = screen.visibleFrame.origin.y
        let bottomPadding = displayHeight * 0.15
        let y = dockTopY - bottomPadding + yOffset

        let contentRect = CGRect(x: 0, y: y, width: displayWidth, height: displayHeight)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let hostView = CharacterContentView(frame: CGRect(x: 0, y: 0, width: displayWidth, height: displayHeight))
        hostView.character = self
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor

        let imageView = NSImageView(frame: hostView.bounds)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.autoresizingMask = [.width, .height]
        hostView.addSubview(imageView)
        self.imageView = imageView
        setFacing(.front)

        window.contentView = hostView
        updateCharacterTooltip()
        window.orderFrontRegardless()
    }

    func handleClick() {
        if isCompanionAvatar, let representedExpert {
            focusedExpert = representedExpert
            claudeSession?.focusedExpert = representedExpert
            if isIdleForPopover {
                closePopover()
            } else {
                openPopover()
            }
            return
        }
        if isOnboarding {
            openOnboardingPopover()
            return
        }
        if isIdleForPopover {
            isPopoverPinned = false
            syncPopoverPinState()
            closePopover()
        } else {
            openPopover()
        }
    }

    func setMovementLocked(_ locked: Bool) {
        movementLocked = locked
        if locked {
            isWalking = false
            isPaused = true
            pauseEndTime = .greatestFiniteMagnitude
            setFacing(.front)
        } else if !isIdleForPopover && !isDraggingHorizontally {
            pauseEndTime = CACurrentMediaTime() + Double.random(in: 1.5...3.5)
        }
    }

    func beginHorizontalDrag(at event: NSEvent) {
        isDraggingHorizontally = true
        usesExpandedHorizontalRange = true
        isWalking = false
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + 8.0
        setFacing(.front)
        continueHorizontalDrag(with: event)
    }

    func continueHorizontalDrag(with event: NSEvent) {
        guard isDraggingHorizontally,
              let controller,
              let metrics = controller.currentDockMetrics()
        else { return }

        let bottomPadding = displayHeight * 0.15
        let pointerLocation = NSEvent.mouseLocation
        let horizontalMetrics = horizontalRangeMetrics(
            screen: metrics.screen,
            dockX: metrics.dockX,
            dockWidth: metrics.dockWidth
        )
        let visualX = pointerLocation.x - displayWidth / 2 - flipXOffset
        let rawProgress = horizontalMetrics.travelDistance > 0
            ? (visualX - horizontalMetrics.minX) / horizontalMetrics.travelDistance
            : 0
        positionProgress = min(max(rawProgress, 0), 1)

        let y = metrics.dockTopY - bottomPadding + yOffset
        window.setFrameOrigin(NSPoint(
            x: horizontalMetrics.minX + horizontalMetrics.travelDistance * positionProgress + flipXOffset,
            y: y
        ))
        updatePopoverPosition()
        updateThinkingBubble()
        updateExpertNameTag()
    }

    func endHorizontalDrag() {
        isDraggingHorizontally = false
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 4.0...8.0)
    }

    func cancelHorizontalDrag() {
        isDraggingHorizontally = false
    }

    func configureCompanionAvatar(expert: ResponderExpert, position: CGFloat) {
        representedExpert = expert
        isCompanionAvatar = true
        focusedExpert = nil
        isOnboarding = false
        isIdleForPopover = false
        isWalking = false
        isPaused = true
        pauseEndTime = .greatestFiniteMagnitude
        positionProgress = position
        hideBubble()
        setPersona(.expert(expert))
        updateCharacterTooltip()
        updateExpertNameTag()
        window.orderFrontRegardless()
    }

    func hideCompanionAvatar() {
        representedExpert = nil
        isCompanionAvatar = false
        updateCharacterTooltip()
        hideBubble()
        hideExpertNameTag()
        window.orderOut(nil)
    }

    func focus(on expert: ResponderExpert?) {
        focusedExpert = expert
        claudeSession?.focusedExpert = expert
        if let expert {
            setPersona(.expert(expert))
        } else {
            setPersona(.lenny)
        }
        updateCharacterTooltip()
        updateExpertNameTag()
        refreshPopoverHeader()
        if !isIdleForPopover {
            openPopover()
        } else {
            restoreTranscriptState()
        }
    }

    func restoreTranscriptState() {
        updateInputPlaceholder()
        terminalView?.setReturnToLennyVisible(focusedExpert != nil)
        terminalView?.isExpertMode = focusedExpert != nil

        guard let session = claudeSession, let terminalView else { return }
        let activeHistory = session.history(for: focusedExpert)
        let conversationKey = session.key(for: focusedExpert)

        if let expert = focusedExpert {
            if activeHistory.isEmpty {
                terminalView.renderedConversationKey = conversationKey
                terminalView.showExpertGreeting(for: expert)
                if session.isBusy, !currentActivityStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    terminalView.setLiveStatus(
                        currentActivityStatus,
                        isBusy: true,
                        isError: false,
                        experts: [expert]
                    )
                } else {
                    terminalView.clearTranscriptLiveStatus()
                }
                terminalView.hideExpertSuggestions(clearState: false)
                return
            }

            terminalView.replayConversation(activeHistory, expertSuggestions: session.expertSuggestionEntries(for: expert))
            terminalView.renderedConversationKey = conversationKey
            if session.isBusy, !currentActivityStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                terminalView.setLiveStatus(
                    currentActivityStatus,
                    isBusy: true,
                    isError: false,
                    experts: [expert]
                )
            } else {
                terminalView.clearTranscriptLiveStatus()
            }
            terminalView.hideExpertSuggestions(clearState: false)
            return
        }

        if activeHistory.isEmpty {
            terminalView.renderedConversationKey = conversationKey
            terminalView.showWelcomeGreeting()
            if session.isBusy, !currentActivityStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                terminalView.setLiveStatus(
                    currentActivityStatus,
                    isBusy: true,
                    isError: false,
                    experts: session.livePresenceExperts
                )
            } else {
                terminalView.clearTranscriptLiveStatus()
            }
            terminalView.hideExpertSuggestions()
            return
        }

        terminalView.replayConversation(activeHistory, expertSuggestions: session.expertSuggestionEntries(for: nil))
        terminalView.renderedConversationKey = conversationKey

        if session.isBusy, !currentActivityStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            terminalView.setLiveStatus(
                currentActivityStatus,
                isBusy: true,
                isError: false,
                experts: session.livePresenceExperts
            )
        } else {
            terminalView.clearTranscriptLiveStatus()
        }

        let persistedEntries = session.expertSuggestionEntries(for: nil)
        guard persistedEntries.isEmpty else {
            terminalView.hideExpertSuggestions(clearState: false)
            return
        }

        let controllerSuggestions = controller?.suggestedExperts ?? []
        let suggestions = controllerSuggestions.isEmpty
            ? terminalView.currentExpertSuggestions
            : controllerSuggestions
        if suggestions.isEmpty {
            terminalView.hideExpertSuggestions()
        } else {
            terminalView.setExpertSuggestionsCollapsed(suggestions)
        }
    }

    private func loadDirectionalImages() {
        directionalImages[.front] = loadImage(named: "main-front.png")
        directionalImages[.left] = loadImage(named: "lenny-walk-left.gif", fallback: "main-left.png")
        directionalImages[.right] = loadImage(named: "lenny-walk-right.gif", fallback: "main-right.png")
        directionalImages[.back] = loadImage(named: "main-back.png")
    }

    private func loadImage(named name: String, fallback: String? = nil) -> NSImage {
        guard let resourceURL = Bundle.main.resourceURL else {
            return NSImage(size: NSSize(width: displayWidth, height: displayHeight))
        }
        let baseURL = resourceURL.appendingPathComponent(WalkerCharacterAssets.lennyAssetsDirectory)
        let primaryPath = baseURL.appendingPathComponent(name).path
        if let image = NSImage(contentsOfFile: primaryPath) {
            return image
        }
        if let fallback {
            let fallbackPath = baseURL.appendingPathComponent(fallback).path
            if let image = NSImage(contentsOfFile: fallbackPath) {
                return image
            }
        }
        return NSImage(size: NSSize(width: displayWidth, height: displayHeight))
    }

    func setFacing(_ facing: WalkerFacing) {
        imageView?.image = directionalImages[facing] ?? directionalImages[.front]
    }

    private func setPersona(_ persona: WalkerPersona) {
        let previousPersona = self.persona
        self.persona = persona

        switch persona {
        case .lenny:
            loadDirectionalImages()
            characterColor = NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0)

        case .expert(let expert):
            let avatar = loadExpertAvatar(at: expert.avatarPath)
            directionalImages[.front] = avatar
            directionalImages[.left] = avatar
            directionalImages[.right] = avatar
            directionalImages[.back] = avatar
            characterColor = .white
        }

        setFacing(.front)
            animatePersonaSwap()
        if let terminalView {
            terminalView.characterColor = characterColor
        }
        playHandoffEffect(from: previousPersona, to: persona)
    }

    private func updateCharacterTooltip() {
        let tooltip: String
        if let expert = focusedExpert ?? representedExpert {
            tooltip = "Ask \(expert.name)"
        } else {
            tooltip = "Ask Lil-Lenny"
        }
        window.contentView?.toolTip = tooltip
    }

    private func loadExpertAvatar(at path: String) -> NSImage {
        NSImage(contentsOfFile: path) ?? NSImage(size: NSSize(width: displayWidth, height: displayHeight))
    }
}
