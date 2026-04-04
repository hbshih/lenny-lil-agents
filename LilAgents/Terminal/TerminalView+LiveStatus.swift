import AppKit

extension TerminalView {

    // MARK: - Expert suggestions

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
        scrollLatestBubbleIntoView()
    }

    // MARK: - Live status

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false, experts: [ResponderExpert] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if isBusy {
                SessionDebugLogger.log("ui", "ignoring empty live status update while busy")
                return
            }
            clearLiveStatus()
            return
        }

        inputField.isHidden = isBusy
        attachButton.isHidden = isBusy
        composerStatusLabel.isHidden = !isBusy
        composerStatusLabel.stringValue = isBusy ? "Generating..." : ""
        sendButton.isHidden = false
        sendButton.toolTip = isBusy ? "Stop" : "Send"
        if let img = NSImage(systemSymbolName: isBusy ? "stop.fill" : "arrow.up", accessibilityDescription: isBusy ? "Stop generation" : "Send message") {
            let config = NSImage.SymbolConfiguration(pointSize: isBusy ? 10 : 11, weight: .bold)
            sendButton.image = img.withSymbolConfiguration(config)
        }
        sendButton.normalBg = isBusy ? theme.separatorColor.withAlphaComponent(0.16).cgColor : theme.accentColor.cgColor
        sendButton.hoverBg = isBusy ? theme.separatorColor.withAlphaComponent(0.28).cgColor : theme.accentColor.withAlphaComponent(0.80).cgColor
        sendButton.layer?.backgroundColor = sendButton.normalBg
        sendButton.contentTintColor = isBusy ? theme.textPrimary : .white

        renderTranscriptLiveStatus(trimmed, experts: experts)
        refreshComposerContentLayout(showingStatus: true)
    }

    func clearLiveStatus() {
        clearTranscriptLiveStatus()
        clearTranscriptApproval()
        composerStatusLabel.stringValue = "Generating..."
        composerStatusLabel.isHidden = true
        inputField.isHidden = false
        sendButton.isHidden = false
        attachButton.isHidden = false
        sendButton.toolTip = "Send"
        if let img = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Send message") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            sendButton.image = img.withSymbolConfiguration(config)
        }
        sendButton.normalBg = theme.accentColor.cgColor
        sendButton.hoverBg = theme.accentColor.withAlphaComponent(0.80).cgColor
        sendButton.layer?.backgroundColor = sendButton.normalBg
        sendButton.contentTintColor = .white
        refreshComposerContentLayout(showingStatus: false)
    }

    func setApprovalRequest(_ request: ClaudeSession.ApprovalRequest) {
        renderTranscriptApproval(request)
        refreshComposerContentLayout(showingStatus: true)
    }

    func clearApprovalRequest() {
        clearTranscriptApproval()
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

    // MARK: - Live status avatar shuffle

    func startLiveStatusAvatarShuffle() {
        if liveStatusAvatarPaths.isEmpty {
            liveStatusAvatarPaths = randomExpertAvatarPaths(limit: Int.random(in: 12...20))
            liveStatusAvatarIndex = 0
        }
        guard !liveStatusAvatarPaths.isEmpty else {
            liveStatusAvatarView.isHidden = true
            refreshComposerContentLayout(showingStatus: true)
            return
        }

        liveStatusAvatarView.isHidden = false
        advanceLiveStatusAvatar()
        refreshComposerContentLayout(showingStatus: true)

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
        refreshComposerContentLayout(showingStatus: true)
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
