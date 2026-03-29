import AppKit

class HoverButton: NSButton {
    var normalBg: CGColor = NSColor.clear.cgColor
    var hoverBg: CGColor = NSColor.clear.cgColor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = hoverBg
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().layer?.backgroundColor = normalBg
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension TerminalView {
    func showWelcomeSuggestionsPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let chips = WelcomeChipsView(theme: theme)
        chips.onChipTapped = { [weak self] text in
            guard let self else { return }
            self.hideWelcomeSuggestionsPanel()
            self.inputField.stringValue = text
            self.inputSubmitted()
        }

        expertSuggestionLabel.isHidden = true
        expertSuggestionStack.addArrangedSubview(chips)
        chips.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
        welcomeChipsView = chips
        expertSuggestionContainer.isHidden = false
        expertSuggestionContainer.alphaValue = 1
        relayoutPanels()
    }

    func hideWelcomeSuggestionsPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        welcomeChipsView = nil
        expertSuggestionContainer.isHidden = true
        expertSuggestionContainer.alphaValue = 0
        relayoutPanels()
    }

    func setExpertSuggestions(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = false
        renderTranscriptSuggestions()
    }

    func setExpertSuggestionsCollapsed(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = true
        renderTranscriptSuggestions()
    }

    func hideExpertSuggestions(clearState: Bool = true) {
        if clearState {
            currentExpertSuggestions = []
            expertSuggestionsCollapsed = false
        }
        clearTranscriptSuggestionView()
    }

    func setPickedExpert(_ expert: ResponderExpert) {
        lastPickedExpert = expert
        currentExpertSuggestions = []
        expertSuggestionsCollapsed = false
        clearTranscriptSuggestionView()
    }

    func showPickedExpertSummary(_ expert: ResponderExpert, suggestions: [ResponderExpert]) {
        lastPickedExpert = expert
        currentExpertSuggestions = suggestions
        expertSuggestionsCollapsed = true
        renderTranscriptSuggestions()
    }

    func clearTranscriptSuggestionView() {
        if let view = transcriptSuggestionView {
            transcriptStack.removeArrangedSubview(view)
            view.removeFromSuperview()
            transcriptSuggestionView = nil
        }
    }

    func renderTranscriptSuggestions() {
        clearTranscriptSuggestionView()
        expertSuggestionTargets.removeAll()

        if expertSuggestionsCollapsed, let picked = lastPickedExpert {
            let entry = ExpertSuggestionEntry(
                anchorHistoryCount: 0,
                experts: currentExpertSuggestions.isEmpty ? [picked] : currentExpertSuggestions,
                pickedExpert: picked,
                isCollapsed: true
            )
            let compact = CompactSuggestionView(theme: theme, entry: entry)
            compact.onRetap = { [weak self] _ in
                guard let self else { return }
                self.expertSuggestionsCollapsed = false
                self.renderTranscriptSuggestions()
            }
            transcriptStack.addArrangedSubview(compact)
            compact.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            compact.heightAnchor.constraint(equalToConstant: 46).isActive = true
            transcriptSuggestionView = compact
            scrollToBottom()
            return
        }

        guard !currentExpertSuggestions.isEmpty else { return }

        let entry = ExpertSuggestionEntry(anchorHistoryCount: 0, experts: currentExpertSuggestions)
        let suggestionsView = ExpertSuggestionCardView(theme: theme, entry: entry)
        suggestionsView.onExpertTapped = { [weak self] _, expert in
            guard let self else { return }
            self.lastPickedExpert = expert
            self.expertSuggestionsCollapsed = true
            self.onSelectExpert?(expert)
        }
        transcriptStack.addArrangedSubview(suggestionsView)
        suggestionsView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        suggestionsView.heightAnchor.constraint(equalToConstant: expertSuggestionCardHeight(for: currentExpertSuggestions.count)).isActive = true
        transcriptSuggestionView = suggestionsView
        scrollToBottom()
    }

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        guard !text.isEmpty else {
            clearLiveStatus()
            return
        }

        inputField.isHidden = true
        sendButton.isHidden = true
        attachButton.isHidden = true

        let mainColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        let attrStr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: mainColor
            ]
        )
        if isBusy && !isError && text.count < 52 {
            attrStr.append(NSAttributedString(
                string: "  ·  Close anytime",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: t.textDim
                ]
            ))
        }
        liveStatusLabel.attributedStringValue = attrStr

        liveStatusLabel.isHidden = false
        liveStatusSpinner.stopAnimation(nil)
        liveStatusSpinner.isHidden = true
        if isBusy && !isError {
            startLiveStatusAvatarShuffle()
        } else {
            stopLiveStatusAvatarShuffle()
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.attributedStringValue = NSAttributedString(string: "")
        liveStatusSpinner.stopAnimation(nil)
        stopLiveStatusAvatarShuffle()

        liveStatusSpinner.isHidden = true
        liveStatusLabel.isHidden = true
        inputField.isHidden = false
        sendButton.isHidden = false
        attachButton.isHidden = false
    }

    func normalizeExpertSuggestionID(_ name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    func startLiveStatusAvatarShuffle() {
        if liveStatusAvatarPaths.isEmpty {
            liveStatusAvatarPaths = randomExpertAvatarPaths(limit: Int.random(in: 12...20))
            liveStatusAvatarIndex = 0
        }
        guard !liveStatusAvatarPaths.isEmpty else {
            liveStatusAvatarView.isHidden = true
            return
        }

        liveStatusAvatarView.isHidden = false
        advanceLiveStatusAvatar()

        if liveStatusAvatarTimer == nil {
            liveStatusAvatarTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
                self?.advanceLiveStatusAvatar()
            }
            if let timer = liveStatusAvatarTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopLiveStatusAvatarShuffle() {
        liveStatusAvatarTimer?.invalidate()
        liveStatusAvatarTimer = nil
        liveStatusAvatarPaths.removeAll()
        liveStatusAvatarIndex = 0
        liveStatusAvatarView.image = nil
        liveStatusAvatarView.isHidden = true
    }

    func advanceLiveStatusAvatar() {
        guard !liveStatusAvatarPaths.isEmpty else { return }
        if liveStatusAvatarIndex >= liveStatusAvatarPaths.count {
            liveStatusAvatarPaths.shuffle()
            liveStatusAvatarIndex = 0
        }
        let path = liveStatusAvatarPaths[liveStatusAvatarIndex]
        liveStatusAvatarIndex += 1
        if let image = NSImage(contentsOfFile: path) {
            liveStatusAvatarView.image = image
        }
    }

    func randomExpertAvatarPaths(limit: Int) -> [String] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let directoryURL = resourceURL.appendingPathComponent("ExpertAvatars", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { ["png", "jpg", "jpeg", "webp"].contains($0.pathExtension.lowercased()) }
            .shuffled()
            .prefix(limit)
            .map(\.path)
    }
}
