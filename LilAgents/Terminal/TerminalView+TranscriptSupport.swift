import AppKit

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Hoverable chip card for welcome suggestions

class HoverChipView: NSView {
    var onTapped: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor
    private weak var contentStack: NSStackView?

    init(symbol: String, label: String, theme: PopoverTheme) {
        self.normalBg = theme.inputBg.cgColor
        self.hoverBg = theme.accentColor.withAlphaComponent(0.06).cgColor
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = normalBg
        layer?.cornerRadius = 10
        layer?.borderWidth = 1.0
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.55).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack = hStack
        addSubview(hStack)

        let minimumHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        minimumHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            minimumHeight,
        ])

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = theme.accentColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        hStack.addArrangedSubview(iconView)

        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(textLabel)

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        guard let contentStack else { return super.intrinsicContentSize }
        let fitting = contentStack.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: max(48, fitting.height))
    }

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

    override func mouseDown(with event: NSEvent) {
        onTapped?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Welcome chips grid

class WelcomeChipsView: NSView {
    var onChipTapped: ((String) -> Void)?
    private let theme: PopoverTheme
    private weak var outerStackView: NSStackView?

    private let suggestions: [(String, String, String)]

    static let defaultSuggestionPool: [(String, String, String)] = [
        ("creditcard",                "Help me price a new product",       "Help me price a new product."),
        ("cursorarrow.rays",          "How should we position this?",      "How should we position this?"),
        ("building.2",                "What does enterprise want here?",   "What does enterprise want here?"),
        ("person.crop.circle.badge.checkmark", "How do I hire better PMs?", "How do I hire better PMs?"),
        ("chart.bar.doc.horizontal",  "How do we improve activation?",     "How do we improve activation?"),
        ("arrow.2.circlepath",        "How do we improve retention?",      "How do we improve retention?"),
        ("flag.pattern.checkered",    "How should we launch this?",        "How should we launch this?"),
        ("map",                       "What should we build next?",        "What should we build next?"),
        ("person.2",                  "How should I run interviews?",      "How should I run interviews?"),
        ("bubble.left.and.bubble.right", "How do I handle this conversation?", "How do I handle this conversation?"),
        ("waveform.path.ecg",         "What matters most in AI products?", "What matters most in AI products?"),
        ("person.badge.key",          "What should a founder focus on?",   "What should a founder focus on?"),
    ]

    static let starterPackSuggestionPool: [(String, String, String)] = [
        ("terminal",                  "How do I use Claude Code better?",  "How do I use Claude Code better?"),
        ("desktopcomputer",           "How do I use Codex better?",        "How do I use Codex better?"),
        ("curlybraces.square",        "How can PMs build with Cursor?",    "How can PMs build with Cursor?"),
        ("person.crop.circle.badge.plus", "What are people vibe coding?", "What are people vibe coding right now?"),
        ("shippingbox",               "How should I prototype with AI?",   "How should I prototype with AI?"),
        ("magnifyingglass.circle",    "What changed at Google AI?",        "What changed at Google AI?"),
        ("chart.bar.xaxis",           "How should we measure AI output?",  "How should we measure AI output?"),
        ("building.2.crop.circle",    "Why are PMs becoming builders?",    "Why are PMs becoming builders?"),
        ("network",                   "How is Block using AI?",            "How is Block using AI?"),
        ("sparkles.rectangle.stack",  "How did Gamma get to $100M ARR?",   "How did Gamma get to $100M ARR?"),
        ("megaphone",                 "What does strong GTM look like?",   "What does strong GTM look like?"),
        ("dollarsign.arrow.circlepath", "How does enterprise sales work now?", "How does enterprise sales work now?"),
        ("heart.text.square",         "How do you build products people love?", "How do you build products people love?"),
        ("person.3.sequence",         "How should I lead through chaos?",  "How should I lead through chaos?"),
        ("bubble.left.and.bubble.right", "How do I have this conversation?", "How do I have this conversation?"),
        ("building.columns",          "Why is scaling so hard now?",       "Why is scaling so hard now?"),
        ("person.crop.rectangle.stack", "What skill will still matter?",   "What skill will still matter most?"),
        ("chart.line.uptrend.xyaxis", "How did Duolingo restart growth?",  "How did Duolingo restart growth?"),
        ("briefcase",                 "What does the PM market look like?", "What does the PM market look like?"),
        ("chart.xyaxis.line",         "What should I ask when growth stalls?", "What should I ask when growth stalls?"),
        ("crown",                     "What leadership truth matters here?", "What leadership truth matters here?"),
        ("person.text.rectangle",     "How do I work with difficult adults?", "How do I work with difficult adults?"),
        ("paintbrush.pointed",        "How did Canva scale this far?",     "How did Canva scale this far?"),
    ]

    init(theme: PopoverTheme, suggestions: [(String, String, String)] = WelcomeChipsView.defaultSuggestionPool) {
        self.theme = theme
        self.suggestions = suggestions
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let outerStack = NSStackView()
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 8
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStackView = outerStack
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let pairs = stride(from: 0, to: suggestions.count, by: 2).map { i -> [(String, String, String)] in
            let end = min(i + 2, suggestions.count)
            return Array(suggestions[i..<end])
        }

        for pair in pairs {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for (symbol, label, sendText) in pair {
                let chip = HoverChipView(symbol: symbol, label: label, theme: theme)
                chip.onTapped = { [weak self] in self?.onChipTapped?(sendText) }
                rowStack.addArrangedSubview(chip)
            }
            outerStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor).isActive = true
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override var intrinsicContentSize: NSSize {
        guard let outerStackView else { return super.intrinsicContentSize }
        let fitting = outerStackView.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: fitting.height)
    }
}

class ConnectionSetupCardView: NSView {
    var onOpenSettings: (() -> Void)?

    private let theme: PopoverTheme

    init(theme: PopoverTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = theme.inputBg.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.45).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        let title = NSTextField(wrappingLabelWithString: "Set up your AI connection")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let body = NSTextField(wrappingLabelWithString: "Open Settings to connect Claude, Codex/ChatGPT, or OpenAI. Once one is connected, Lil-Lenny is ready to chat.")
        body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        body.textColor = theme.textDim
        body.maximumNumberOfLines = 0
        stack.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let settingsButton = HoverButton(title: "", target: self, action: #selector(openSettingsTapped))
        settingsButton.isBordered = false
        settingsButton.wantsLayer = true
        settingsButton.normalBg = theme.accentColor.cgColor
        settingsButton.hoverBg = theme.accentColor.withAlphaComponent(0.82).cgColor
        settingsButton.layer?.backgroundColor = settingsButton.normalBg
        settingsButton.layer?.cornerRadius = 12
        settingsButton.horizontalContentPadding = 16
        settingsButton.verticalContentPadding = 6
        settingsButton.attributedTitle = NSAttributedString(string: "Open Settings", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        stack.addArrangedSubview(settingsButton)

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @objc private func openSettingsTapped() {
        onOpenSettings?()
    }
}

class StarterPackUpsellCardView: NSView {
    var onConnectTapped: (() -> Void)?
    var onSettingsTapped: (() -> Void)?
    var onSkipTapped: (() -> Void)?

    private let theme: PopoverTheme
    private let compact: Bool
    private let showsSkipButton: Bool

    init(theme: PopoverTheme, compact: Bool = false, showsSkipButton: Bool = false) {
        self.theme = theme
        self.compact = compact
        self.showsSkipButton = showsSkipButton
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = theme.inputBg.cgColor
        layer?.cornerRadius = compact ? 12 : 16
        layer?.borderWidth = 1
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.45).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = compact ? 8 : 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let horizontalInset: CGFloat = 14
        let verticalInset: CGFloat = compact ? 12 : 16
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(compact ? 12 : 14))
        ])

        if !compact {
            let eyebrow = NSTextField(labelWithString: "Starter Pack")
            eyebrow.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
            eyebrow.textColor = theme.accentColor
            stack.addArrangedSubview(eyebrow)
        }

        let title = NSTextField(wrappingLabelWithString: compact ? "Unlock the full archive" : "Get the full Lenny archive")
        title.font = NSFont.systemFont(ofSize: compact ? 13 : 14, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let body = NSTextField(wrappingLabelWithString: compact
            ? "Connect LennyData for broader answers."
            : "Your starter pack covers the essentials. Connect the official Lenny MCP from lennysdata.com to unlock the full archive."
        )
        body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        body.textColor = theme.textDim
        body.maximumNumberOfLines = 0
        stack.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(buttonRow)

        let connectButton = makePrimaryButton(title: "Connect official MCP", action: #selector(connectTapped))
        buttonRow.addArrangedSubview(connectButton)

        if showsSkipButton {
            let skipButton = makeSecondaryButton(title: "Skip for now", action: #selector(skipTapped))
            buttonRow.addArrangedSubview(skipButton)
        } else if !compact {
            let settingsButton = makeSecondaryButton(title: "Open Settings", action: #selector(settingsTapped))
            buttonRow.addArrangedSubview(settingsButton)
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func makePrimaryButton(title: String, action: Selector) -> HoverButton {
        let button = HoverButton(title: "", target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.accentColor.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.82).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 12
        button.horizontalContentPadding = 16
        button.verticalContentPadding = 6
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    private func makeSecondaryButton(title: String, action: Selector) -> HoverButton {
        let button = HoverButton(title: "", target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.bubbleBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.08).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.42).cgColor
        button.horizontalContentPadding = 14
        button.verticalContentPadding = 6
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: theme.textPrimary
        ])
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    @objc private func connectTapped() {
        onConnectTapped?()
    }

    @objc private func settingsTapped() {
        onSettingsTapped?()
    }

    @objc private func skipTapped() {
        onSkipTapped?()
    }
}

class OfficialMCPConnectCardView: NSView {
    var onOpenWebsite: (() -> Void)?
    var onSave: ((OfficialMCPInstaller.InstallResult) -> Void)?
    var onBack: (() -> Void)?

    private let theme: PopoverTheme
    private let compact: Bool
    private let showsBackButton: Bool
    private let tokenField = NSSecureTextField()
    private let detectionLabel = NSTextField(labelWithString: "")
    private let saveButton = HoverButton(title: "", target: nil, action: nil)

    init(theme: PopoverTheme, compact: Bool = false, showsBackButton: Bool = false) {
        self.theme = theme
        self.compact = compact
        self.showsBackButton = showsBackButton
        super.init(frame: .zero)
        setupViews()
        refreshSaveState()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = theme.inputBg.cgColor
        layer?.cornerRadius = compact ? 12 : 16
        layer?.borderWidth = 1
        layer?.borderColor = theme.separatorColor.withAlphaComponent(0.45).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = compact ? 5 : 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let horizontalInset: CGFloat = 14
        let verticalInset: CGFloat = compact ? 8 : 14
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: verticalInset),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalInset)
        ])

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleRow)
        titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let title = NSTextField(wrappingLabelWithString: compact ? "Connect LennyData" : "Connect LennyData locally on this Mac")
        title.font = NSFont.systemFont(ofSize: compact ? 13 : 14, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 1
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addArrangedSubview(title)

        let compactBadge = makeInfoBadge(title: compact ? "Everything stays local" : "Everything stays local on this Mac.")
        compactBadge.setContentHuggingPriority(.required, for: .horizontal)
        compactBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleRow.addArrangedSubview(compactBadge)

        let titleSpacer = NSView()
        titleSpacer.translatesAutoresizingMaskIntoConstraints = false
        titleSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleRow.addArrangedSubview(titleSpacer)

        if compact {
            let body = NSTextField(wrappingLabelWithString: "Paste your auth key from lennysdata.com.")
            body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            body.textColor = theme.textDim
            body.maximumNumberOfLines = 1
            stack.addArrangedSubview(body)
            body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            let accessRow = NSStackView()
            accessRow.orientation = .horizontal
            accessRow.alignment = .centerY
            accessRow.spacing = 12
            accessRow.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(accessRow)
            accessRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            let tokenRow = makeTokenFieldRow()
            accessRow.addArrangedSubview(tokenRow)
            tokenRow.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

            let openButton = makeSecondaryButton(title: "Get auth key", action: #selector(openWebsiteTapped))
            openButton.setContentHuggingPriority(.required, for: .horizontal)
            openButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            accessRow.addArrangedSubview(openButton)
        } else {
            let body = NSTextField(wrappingLabelWithString: "Open lennysdata.com, copy your auth key, and paste it here to unlock the full archive.")
            body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            body.textColor = theme.textDim
            body.maximumNumberOfLines = 2
            stack.addArrangedSubview(body)
            body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

            let openButton = makeSecondaryButton(title: "Get auth key", action: #selector(openWebsiteTapped))
            stack.addArrangedSubview(openButton)

            let inputLabel = NSTextField(labelWithString: "Auth key")
            inputLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            inputLabel.textColor = theme.textDim
            stack.addArrangedSubview(inputLabel)
            inputLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            let tokenRow = makeTokenFieldRow()
            stack.addArrangedSubview(tokenRow)
            tokenRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        detectionLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        detectionLabel.textColor = theme.textDim
        detectionLabel.maximumNumberOfLines = 1
        detectionLabel.stringValue = OfficialMCPInstaller.compactInstallTargetHint()
        if compact {
            detectionLabel.isHidden = true
        } else {
            stack.addArrangedSubview(detectionLabel)
            detectionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(buttonRow)

        configurePrimaryButton(saveButton, title: compact ? "Connect" : "Save and connect", action: #selector(saveTapped))
        buttonRow.addArrangedSubview(saveButton)

        if showsBackButton {
            let backButton = makeSecondaryButton(title: "Back", action: #selector(backTapped))
            buttonRow.addArrangedSubview(backButton)
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func makeTokenFieldRow() -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.backgroundColor = theme.inputBg.cgColor
        row.layer?.cornerRadius = 12
        row.layer?.borderWidth = 1
        row.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.4).cgColor

        tokenField.translatesAutoresizingMaskIntoConstraints = false
        tokenField.placeholderString = "Paste auth key"
        tokenField.focusRingType = .none
        tokenField.isBordered = false
        tokenField.drawsBackground = false
        tokenField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        tokenField.target = self
        tokenField.action = #selector(tokenFieldChanged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tokenFieldDidChangeNotification(_:)),
            name: NSControl.textDidChangeNotification,
            object: tokenField
        )
        row.addSubview(tokenField)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: compact ? 34 : 38),
            tokenField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            tokenField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            tokenField.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeInfoBadge(title: String) -> NSView {
        let badge = NSView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.backgroundColor = theme.accentColor.withAlphaComponent(0.08).cgColor
        badge.layer?.cornerRadius = 12

        let lockIcon = NSImageView()
        if let img = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: compact ? 8 : 9, weight: .semibold)
            lockIcon.image = img.withSymbolConfiguration(config)
        }
        lockIcon.contentTintColor = theme.accentColor
        lockIcon.imageScaling = .scaleProportionallyDown
        lockIcon.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: compact ? 10 : 11, weight: .semibold)
        label.textColor = theme.accentColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = compact ? 4 : 5
        hStack.translatesAutoresizingMaskIntoConstraints = false
        hStack.addArrangedSubview(lockIcon)
        hStack.addArrangedSubview(label)
        badge.addSubview(hStack)

        NSLayoutConstraint.activate([
            lockIcon.widthAnchor.constraint(equalToConstant: compact ? 9 : 10),
            lockIcon.heightAnchor.constraint(equalToConstant: compact ? 10 : 12),
            hStack.topAnchor.constraint(equalTo: badge.topAnchor, constant: compact ? 4 : 5),
            hStack.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: compact ? 8 : 9),
            hStack.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -(compact ? 8 : 9)),
            hStack.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -(compact ? 4 : 5))
        ])

        return badge
    }

    private func configurePrimaryButton(_ button: HoverButton, title: String, action: Selector) {
        button.target = self
        button.action = action
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.accentColor.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.82).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 12
        button.horizontalContentPadding = 16
        button.verticalContentPadding = 6
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    private func makeSecondaryButton(title: String, action: Selector) -> HoverButton {
        let button = HoverButton(title: "", target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.bubbleBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.08).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.42).cgColor
        button.horizontalContentPadding = 14
        button.verticalContentPadding = 6
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: theme.textPrimary
        ])
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    private func refreshSaveState() {
        let hasToken = !tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        saveButton.isEnabled = hasToken
        saveButton.alphaValue = hasToken ? 1 : 0.5
    }

    @objc private func tokenFieldChanged() {
        refreshSaveState()
    }

    @objc private func tokenFieldDidChangeNotification(_ notification: Notification) {
        refreshSaveState()
    }

    @objc private func openWebsiteTapped() {
        onOpenWebsite?()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func saveTapped() {
        do {
            let result = try OfficialMCPInstaller.install(token: tokenField.stringValue)
            detectionLabel.textColor = theme.accentColor
            detectionLabel.isHidden = false
            if result.storedTokenOnly {
                detectionLabel.stringValue = "Connected. The key is stored locally for later."
            } else {
                let updated = result.updatedTargets.map(\.label)
                let preserved = result.preservedTargets.map(\.label)
                var parts: [String] = []
                if !updated.isEmpty {
                    parts.append("configured \(naturalList(updated))")
                }
                if !preserved.isEmpty {
                    parts.append("\(naturalList(preserved)) was already connected")
                }
                let suffix = parts.isEmpty ? "saved the local token" : parts.joined(separator: "; ")
                detectionLabel.stringValue = "Connected. Lil-Lenny \(suffix)."
            }
            onSave?(result)
        } catch {
            detectionLabel.textColor = theme.errorColor
            detectionLabel.isHidden = false
            detectionLabel.stringValue = error.localizedDescription
        }
    }

    private func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }
}
