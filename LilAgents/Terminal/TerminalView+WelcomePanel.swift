import AppKit

extension TerminalView {
    func welcomeSuggestionPool(for archiveMode: AppSettings.ArchiveAccessMode) -> [(String, String, String)] {
        archiveMode == .starterPack
            ? WelcomeChipsView.starterPackSuggestionPool
            : WelcomeChipsView.defaultSuggestionPool
    }

    func ensureWelcomeSuggestionSelection(forceRefresh: Bool = false) {
        let archiveMode = welcomePreviewArchiveMode
        guard forceRefresh || currentWelcomeArchiveMode != archiveMode || currentWelcomeSuggestions.isEmpty else {
            return
        }

        currentWelcomeArchiveMode = archiveMode
        currentWelcomeSuggestions = Array(welcomeSuggestionPool(for: archiveMode).shuffled().prefix(4))
    }

    var welcomePreviewMode: AppSettings.WelcomePreviewMode {
        AppSettings.welcomePreviewMode
    }

    var welcomePreviewArchiveMode: AppSettings.ArchiveAccessMode {
        switch welcomePreviewMode {
        case .live:
            return AppSettings.effectiveArchiveAccessMode
        case .starterPackWithBanner, .starterPackConnected:
            return .starterPack
        case .officialConnected:
            return .officialMCP
        }
    }

    var shouldShowStarterPackUpsell: Bool {
        switch welcomePreviewMode {
        case .live:
            return AppSettings.effectiveArchiveAccessMode == .starterPack && !AppSettings.hasDetectedOfficialMCPConfiguration
        case .starterPackWithBanner:
            return true
        case .starterPackConnected, .officialConnected:
            return false
        }
    }

    var shouldPresentStarterPackWelcomeBanner: Bool {
        shouldShowStarterPackUpsell && !starterPackWelcomeBannerDismissed
    }

    var welcomeSuggestions: [(String, String, String)] {
        ensureWelcomeSuggestionSelection()
        return currentWelcomeSuggestions
    }

    func openOfficialMCPURL() {
        NSWorkspace.shared.open(officialMCPURL)
    }

    func completeOfficialMCPSetupFlow() {
        isShowingOfficialMCPSetupPanel = false
        starterPackWelcomeBannerDismissed = true
        currentWelcomeArchiveMode = nil
        showWelcomeSuggestionsPanel()
    }

    func showOfficialMCPSetupPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        isShowingOfficialMCPSetupPanel = true

        let setupCard = OfficialMCPConnectCardView(theme: theme, compact: true, showsBackButton: true)
        setupCard.onOpenWebsite = { [weak self] in
            self?.openOfficialMCPURL()
        }
        setupCard.onBack = { [weak self] in
            guard let self else { return }
            self.isShowingOfficialMCPSetupPanel = false
            self.showWelcomeSuggestionsPanel()
        }
        setupCard.onSave = { [weak self] in
            self?.completeOfficialMCPSetupFlow()
        }

        expertSuggestionLabel.isHidden = true
        expertSuggestionStack.addArrangedSubview(setupCard)
        setupCard.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
        welcomeChipsView = nil
        expertSuggestionContainer.isHidden = false
        expertSuggestionContainer.alphaValue = 1
        relayoutPanels()
    }

    func openAppSettings() {
        NSApp.sendAction(#selector(AppDelegate.openSettings), to: NSApp.delegate, from: self)
    }

    func showWelcomeSuggestionsPanel() {
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if isShowingOfficialMCPSetupPanel {
            showOfficialMCPSetupPanel()
            return
        }

        if shouldPresentStarterPackWelcomeBanner {
            let upsell = StarterPackUpsellCardView(theme: theme, compact: true, showsSkipButton: true)
            upsell.onConnectTapped = { [weak self] in
                self?.showOfficialMCPSetupPanel()
            }
            upsell.onSkipTapped = { [weak self] in
                self?.starterPackWelcomeBannerDismissed = true
                self?.showWelcomeSuggestionsPanel()
            }
            expertSuggestionLabel.isHidden = true
            expertSuggestionStack.addArrangedSubview(upsell)
            upsell.widthAnchor.constraint(equalTo: expertSuggestionStack.widthAnchor).isActive = true
            welcomeChipsView = nil
            expertSuggestionContainer.isHidden = false
            expertSuggestionContainer.alphaValue = 1
            relayoutPanels()
            return
        }

        let chips = WelcomeChipsView(
            theme: theme,
            suggestions: welcomeSuggestions
        )
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

    func firstRunConfigurationSignature() -> String {
        [
            "welcome:\(welcomePreviewMode.rawValue)",
            "archive:\(AppSettings.archiveAccessMode.rawValue)",
            "transport:\(AppSettings.preferredTransport.rawValue)",
            "official:\(AppSettings.hasDetectedOfficialMCPConfiguration ? "1" : "0")",
            "token:\(AppSettings.officialLennyMCPToken != nil ? "1" : "0")",
            "openai:\(AppSettings.openAIAPIKey != nil ? "1" : "0")",
            "setup:\(requiresInitialConnectionSetup ? "1" : "0")"
        ].joined(separator: "|")
    }

    func refreshFirstRunStateIfNeeded(forceRefresh: Bool = false) {
        let signature = firstRunConfigurationSignature()
        guard forceRefresh || lastObservedFirstRunConfigurationSignature != signature else { return }

        lastObservedFirstRunConfigurationSignature = signature
        starterPackWelcomeBannerDismissed = false
        currentWelcomeArchiveMode = nil
        currentWelcomeSuggestions = []
        lastRenderedWelcomeSignature = nil
        lastObservedWelcomePreviewMode = welcomePreviewMode

        guard isShowingInitialWelcomeState, !isExpertMode else { return }

        if requiresInitialConnectionSetup {
            onRefreshSetupState?()
            return
        }

        showWelcomeGreeting(forceRefresh: true)
    }

    func refreshWelcomePreviewIfNeeded() {
        refreshFirstRunStateIfNeeded()
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
}
