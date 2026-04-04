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
