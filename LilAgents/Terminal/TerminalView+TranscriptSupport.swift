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
        ("dollarsign.circle",         "B2B SaaS pricing",                  "How should I price a B2B SaaS product?"),
        ("creditcard",                "Pricing tiers",                     "How should I design pricing tiers and packages?"),
        ("arrow.up.right.circle",     "Grow a B2B product",                "What are the best B2B growth tactics right now?"),
        ("chart.xyaxis.line",         "Growth loops",                      "What growth loops are worth exploring for a SaaS product?"),
        ("square.3.layers.3d.top.filled", "Improve onboarding",           "How can I redesign onboarding so users reach value faster?"),
        ("arrow.2.circlepath",        "Improve retention",                 "How do I improve retention for a product that stalls after signup?"),
        ("target",                    "Find product-market fit",           "How do I know if I have product-market fit?"),
        ("cursorarrow.rays",          "Sharpen positioning",               "How should I sharpen product positioning?"),
        ("map",                       "Build a roadmap",                   "How do I build a strong product roadmap?"),
        ("checklist",                 "Prioritize the roadmap",            "How should I prioritize a roadmap with too many competing asks?"),
        ("lightbulb",                 "Great PM traits",                   "What makes a great product manager?"),
        ("person.crop.circle.badge.checkmark", "Hiring PMs",              "How do I hire strong product managers?"),
        ("person.2",                  "Run interviews",                    "How should I run better customer interviews?"),
        ("bubble.left.and.bubble.right", "Handle hard conversations",     "How do I handle difficult conversations with my team?"),
        ("person.3.sequence",         "Lead through change",               "How should I lead a team through fast change and scale?"),
        ("gearshape.2",               "Team operating rhythm",             "What operating rhythms should a strong product team have?"),
        ("shippingbox",               "Launch a product",                  "How should I launch a new product?"),
        ("flag.pattern.checkered",    "B2B go-to-market",                  "What does a strong B2B go-to-market motion look like?"),
        ("building.2",                "Enterprise sales",                  "How should I think about enterprise sales from $1M to $10M ARR?"),
        ("waveform.path.ecg",         "Build AI products",                 "What should I keep in mind when building an AI product?"),
        ("hammer",                    "Keep quality high",                 "How do strong teams keep product quality high as they scale?"),
        ("briefcase",                 "Operator career advice",            "What should an ambitious operator focus on next?"),
        ("person.badge.key",          "Founder priorities",                "What should a founder focus on in the early stages of a company?"),
        ("chart.bar.doc.horizontal",  "Improve activation",               "How should I improve product activation?"),
    ]

    static let starterPackSuggestionPool: [(String, String, String)] = [
        ("terminal",                  "Use Claude Code better",            "How should I use Claude Code more effectively?"),
        ("desktopcomputer",           "Use Codex better",                  "What are the best power-user techniques for Codex?"),
        ("curlybraces.square",        "Cursor for non-tech PMs",           "How can a non-technical PM build with Cursor?"),
        ("person.crop.circle.badge.plus", "What people vibe code",        "What are people vibe coding and actually using?"),
        ("shippingbox",               "Prototype with AI",                 "How should product managers prototype with AI tools?"),
        ("magnifyingglass.circle",    "Google's AI turnaround",            "What drove Google's AI search turnaround?"),
        ("chart.bar.xaxis",           "Measure AI productivity",           "How should teams measure AI developer productivity in 2025?"),
        ("building.2.crop.circle",    "LinkedIn PMs as builders",          "Why is LinkedIn turning PMs into AI-powered full stack builders?"),
        ("network",                   "How Block uses AI",                 "How is Block becoming an AI-native enterprise?"),
        ("sparkles.rectangle.stack",  "How Gamma hit $100M ARR",           "How did Gamma go from a dumb idea to $100M ARR?"),
        ("megaphone",                 "World-class B2B GTM",               "What does world-class GTM look like in 2026?"),
        ("dollarsign.arrow.circlepath", "Enterprise sales playbook",      "What is the enterprise sales playbook from $1M to $10M ARR?"),
        ("heart.text.square",         "Build products people love",        "What mental models help build products people love?"),
        ("person.3.sequence",         "Lead through chaos",                "How should I lead through chaos, change, and scale?"),
        ("bubble.left.and.bubble.right", "Have hard conversations",       "How do I have difficult conversations and build high-trust teams?"),
        ("building.columns",          "Starting vs scaling",               "Why is it easier than ever to start a company and harder than ever to scale one?"),
        ("person.crop.rectangle.stack", "Influence AI can't replace",     "What is the most important skill AI can't replace?"),
        ("chart.line.uptrend.xyaxis", "Duolingo's growth comeback",        "How did Duolingo reignite user growth?"),
        ("briefcase",                 "PM job market in 2025",             "What does the product job market look like in 2025?"),
        ("chart.xyaxis.line",         "When growth stalls",                "What five questions should I ask when product growth stalls?"),
        ("crown",                     "Leadership truths",                 "What contrarian leadership truths matter as a company scales?"),
        ("person.text.rectangle",     "Working with difficult adults",     "How should I work with difficult adults on a team?"),
        ("paintbrush.pointed",        "How Canva scaled",                  "How did Canva become a $42B company?"),
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
        stack.edgeInsets = NSEdgeInsets(top: compact ? 12 : 16, left: 14, bottom: compact ? 12 : 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if !compact {
            let eyebrow = NSTextField(labelWithString: "Starter Pack")
            eyebrow.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
            eyebrow.textColor = theme.accentColor
            stack.addArrangedSubview(eyebrow)
        }

        let title = NSTextField(wrappingLabelWithString: compact
            ? "Connect the full archive for broader results."
            : "Connect the full archive for broader results."
        )
        title.font = NSFont.systemFont(ofSize: compact ? 13 : 14, weight: .semibold)
        title.textColor = theme.textPrimary
        title.maximumNumberOfLines = 0
        stack.addArrangedSubview(title)

        let body = NSTextField(wrappingLabelWithString: compact
            ? "Use the official Lenny MCP at lennydata.com."
            : "The starter pack is bundled locally. Connect the official Lenny MCP at lennydata.com, or skip for now and explore what is already included."
        )
        body.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        body.textColor = theme.textDim
        body.maximumNumberOfLines = 0
        stack.addArrangedSubview(body)

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
