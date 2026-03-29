import AppKit

private func resolvedExpertAvatarImage(at path: String) -> NSImage? {
    let resolvedPath = pngAvatarPath(for: path) ?? path
    return NSImage(contentsOfFile: resolvedPath)
}

private func pngAvatarPath(for path: String) -> String? {
    guard path.lowercased().hasSuffix(".webp"),
          let image = NSImage(contentsOfFile: path),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return nil
    }

    let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lenny-avatar-cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent + ".png"
    let pngURL = cacheDir.appendingPathComponent(fileName)

    if !FileManager.default.fileExists(atPath: pngURL.path) {
        try? pngData.write(to: pngURL)
    }

    return pngURL.path
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Hoverable chip card for welcome suggestions

class HoverChipView: NSView {
    var onTapped: (() -> Void)?
    private let normalBg: CGColor
    private let hoverBg: CGColor

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

        // Internal horizontal stack handles all alignment and padding
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.spacing = 10
        hStack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
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
    }

    required init?(coder: NSCoder) { fatalError() }

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

    // (SF Symbol, display label, full question sent on tap)
    private let suggestions: [(String, String, String)] = [
        ("dollarsign.circle",     "How should I price my SaaS?",         "How should I price my SaaS?"),
        ("arrow.up.right.circle", "Best B2B growth tactics",              "What are the best B2B growth tactics?"),
        ("map",                   "How do I build a product roadmap?",    "How do I build a product roadmap?"),
        ("lightbulb",             "What makes a great product manager?",  "What makes a great product manager?"),
    ]

    init(theme: PopoverTheme) {
        self.theme = theme
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

            var rowChips: [HoverChipView] = []
            for (symbol, label, sendText) in pair {
                let chip = HoverChipView(symbol: symbol, label: label, theme: theme)
                chip.onTapped = { [weak self] in self?.onChipTapped?(sendText) }
                rowStack.addArrangedSubview(chip)
                rowChips.append(chip)
            }
            // Ensure chips in the same row share an equal height
            if rowChips.count == 2 {
                rowChips[1].heightAnchor.constraint(equalTo: rowChips[0].heightAnchor).isActive = true
            }
            outerStack.addArrangedSubview(rowStack)
            rowStack.widthAnchor.constraint(equalTo: outerStack.widthAnchor).isActive = true
        }
    }
}

class ExpertSuggestionCardView: NSView {
    var onExpertTapped: ((UUID, ResponderExpert) -> Void)?
    private let theme: PopoverTheme
    private let entry: ExpertSuggestionEntry

    init(theme: PopoverTheme, entry: ExpertSuggestionEntry) {
        self.theme = theme
        self.entry = entry
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let shell = NSView()
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let titleLabel = NSTextField(labelWithString: "Want a more specific take? Pick a specialist.")
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = theme.textDim
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(titleLabel)

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.distribution = .fill
        list.spacing = 8
        list.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(list)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: shell.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -4),

            list.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            list.leadingAnchor.constraint(equalTo: shell.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: shell.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: shell.bottomAnchor)
        ])

        for expert in entry.experts {
            let chip = makeExpertChip(for: expert)
            list.addArrangedSubview(chip)
            chip.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
    }

    private func makeExpertChip(for expert: ResponderExpert) -> NSView {
        let button = HoverButton(title: "", target: nil, action: nil)
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.inputBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.06).cgColor
        button.layer?.backgroundColor = theme.inputBg.cgColor
        button.layer?.cornerRadius = 16
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.52).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: button.topAnchor),
            stack.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 54)
        ])

        let avatarContainer = NSView()
        avatarContainer.wantsLayer = true
        avatarContainer.layer?.backgroundColor = theme.accentColor.withAlphaComponent(0.10).cgColor
        avatarContainer.layer?.cornerRadius = 12
        avatarContainer.layer?.masksToBounds = true
        avatarContainer.layer?.borderWidth = 1
        avatarContainer.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.40).cgColor
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(equalToConstant: 24).isActive = true
        avatarContainer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(avatarContainer)

        if let image = resolvedExpertAvatarImage(at: expert.avatarPath) {
            let avatarView = NSImageView()
            avatarView.image = image
            avatarView.imageScaling = .scaleAxesIndependently
            avatarView.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(avatarView)

            NSLayoutConstraint.activate([
                avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                avatarView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
                avatarView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
                avatarView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
            ])
        } else {
            let icon = NSImageView()
            if let image = NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
                icon.image = image.withSymbolConfiguration(config)
            }
            icon.contentTintColor = theme.accentColor
            icon.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(icon)

            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 14),
                icon.heightAnchor.constraint(equalToConstant: 14)
            ])
        }

        let label = NSTextField(labelWithString: expert.name)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = theme.textPrimary
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(label)

        button.target = self
        button.action = #selector(expertTapped(_:))
        button.identifier = NSUserInterfaceItemIdentifier(expert.name)
        return button
    }

    @objc private func expertTapped(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue,
              let expert = entry.experts.first(where: { $0.name == name }) else { return }
        onExpertTapped?(entry.id, expert)
    }
}

class CompactSuggestionView: NSView {
    var onRetap: ((UUID) -> Void)?
    private let theme: PopoverTheme
    private let entry: ExpertSuggestionEntry

    init(theme: PopoverTheme, entry: ExpertSuggestionEntry) {
        self.theme = theme
        self.entry = entry
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        let shell = NSView()
        shell.wantsLayer = true
        shell.layer?.backgroundColor = theme.inputBg.cgColor
        shell.layer?.cornerRadius = 14
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.30).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        let summary = NSTextField(labelWithString: "Now chatting with \(entry.pickedExpert?.name ?? "your specialist")")
        summary.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        summary.textColor = theme.textDim
        summary.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(summary)

        let button = HoverButton(title: "", target: self, action: #selector(retap))
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.bubbleBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.08).cgColor
        button.layer?.backgroundColor = theme.bubbleBg.cgColor
        button.layer?.cornerRadius = 11
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.42).cgColor
        button.attributedTitle = NSAttributedString(
            string: "Switch",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: theme.textPrimary
            ]
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(button)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            summary.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            summary.centerYAnchor.constraint(equalTo: shell.centerYAnchor),

            button.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -10),
            button.topAnchor.constraint(equalTo: shell.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 68),

            summary.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),
            shell.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    @objc private func retap() {
        onRetap?(entry.id)
    }
}

class ChatBubbleView: NSView, NSTextViewDelegate {
    let textView = NSTextView()
    let headerLabel = NSTextField(labelWithString: "")
    let bubbleBackground = NSView()
    private let isUser: Bool
    private let theme: PopoverTheme
    private var textWidthConstraint: NSLayoutConstraint?
    private var textHeightConstraint: NSLayoutConstraint?

    init(text: NSAttributedString, isUser: Bool, speakerName: String, theme: PopoverTheme) {
        self.isUser = isUser
        self.theme = theme
        super.init(frame: .zero)
        setupViews()
        populate(text: text, name: speakerName)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = isUser ? theme.textDim : theme.accentColor
        headerLabel.alignment = .left
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.drawsBackground = false
        addSubview(headerLabel)

        bubbleBackground.wantsLayer = true
        bubbleBackground.layer?.cornerRadius = theme.bubbleCornerRadius
        bubbleBackground.layer?.backgroundColor = isUser
            ? theme.accentColor.withAlphaComponent(0.10).cgColor
            : theme.bubbleBg.cgColor
        bubbleBackground.layer?.borderWidth = isUser ? 0 : 0.75
        bubbleBackground.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.36).cgColor
        bubbleBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubbleBackground)

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.linkTextAttributes = [
            .foregroundColor: theme.accentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 7
        p.alignment = .left
        textView.defaultParagraphStyle = p
        
        bubbleBackground.addSubview(textView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor, constant: 4),
            headerLabel.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor, constant: -4),

            bubbleBackground.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            bubbleBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: bubbleBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: bubbleBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor)
        ])

        if isUser {
            bubbleBackground.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            bubbleBackground.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 56).isActive = true
        } else {
            bubbleBackground.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            bubbleBackground.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56).isActive = true
        }
    }

    private func populate(text: NSAttributedString, name: String) {
        headerLabel.stringValue = name
        configureTextContainer()
        textView.textStorage?.setAttributedString(text)
        recalculateSize()
    }

    func setText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.setAttributedString(newText)
        recalculateSize()
    }

    func appendText(_ newText: NSAttributedString) {
        configureTextContainer()
        textView.textStorage?.append(newText)
        recalculateSize()
    }

    private func configureTextContainer() {
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
    }

    private func recalculateSize() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Start large
        textContainer.containerSize = NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        
        let targetContentWidth = rect.width
        let paddingWidth: CGFloat = 28 // left+right 14px

        let maxWidth: CGFloat = 380
        let desiredWidth = targetContentWidth + paddingWidth

        if let textWidthConstraint {
            textView.removeConstraint(textWidthConstraint)
            self.textWidthConstraint = nil
        }
        if let textHeightConstraint {
            textView.removeConstraint(textHeightConstraint)
            self.textHeightConstraint = nil
        }
        
        if desiredWidth >= maxWidth {
            textContainer.containerSize = NSSize(width: maxWidth - paddingWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let newRect = layoutManager.usedRect(for: textContainer)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: maxWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: newRect.height + 24)
        } else {
            let finalWidth = max(desiredWidth, 60)
            textWidthConstraint = textView.widthAnchor.constraint(equalToConstant: finalWidth)
            textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: rect.height + 24)
        }

        textWidthConstraint?.isActive = true
        textHeightConstraint?.isActive = true
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        var view: NSView? = self.superview
        while let v = view {
            if let terminal = v as? TerminalView {
                guard let url = link as? URL,
                      url.scheme == "lilagents-expert",
                      let host = url.host,
                      let expert = terminal.expertSuggestionTargets[host] else {
                    return false
                }
                terminal.onSelectExpert?(expert)
                return true
            }
            view = v.superview
        }
        return false
    }
}

extension TerminalView {
    func expertSuggestionCardHeight(for expertCount: Int) -> CGFloat {
        let count = CGFloat(expertCount)
        return 30 + (count * 54) + max(0, count - 1) * 8
    }

    private func appendSuggestionEntryView(_ entry: ExpertSuggestionEntry) {
        if entry.isCollapsed, entry.pickedExpert != nil {
            let compact = CompactSuggestionView(theme: theme, entry: entry)
            compact.onRetap = { [weak self] entryID in
                self?.onEditExpertSuggestion?(entryID)
            }
            transcriptStack.addArrangedSubview(compact)
            compact.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
            compact.heightAnchor.constraint(equalToConstant: 46).isActive = true
            return
        }

        let suggestionsView = ExpertSuggestionCardView(theme: theme, entry: entry)
        suggestionsView.onExpertTapped = { [weak self] entryID, expert in
            self?.onSelectExpertSuggestion?(entryID, expert)
        }
        transcriptStack.addArrangedSubview(suggestionsView)
        suggestionsView.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        suggestionsView.heightAnchor.constraint(equalToConstant: expertSuggestionCardHeight(for: entry.experts.count)).isActive = true
    }

    func showWelcomeGreeting() {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()
        let t = theme
        let greeting = "I'm Lenny. I pull from my newsletter and podcast archive to help with product, growth, pricing, startups, and AI.\n\nWhat are you working through?"
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: t.font,
            .foregroundColor: t.textPrimary,
        ])
        let bubble = ChatBubbleView(text: attrText, isUser: false, speakerName: "Lenny", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true

        showWelcomeSuggestionsPanel()
        scrollToTop()
    }

    func showExpertGreeting(for expert: ResponderExpert) {
        clearTranscriptSuggestionView()
        hideWelcomeSuggestionsPanel()

        let greeting = "I'm \(expert.name). What would you like to dig into?"
        let attrText = NSAttributedString(string: greeting, attributes: [
            .font: theme.font,
            .foregroundColor: theme.textPrimary,
        ])
        let bubble = ChatBubbleView(text: attrText, isUser: false, speakerName: expert.name, theme: theme)
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        currentAssistantText = ""
        scrollToTop()
    }

    func appendUser(_ text: String, attachments: [SessionAttachment] = []) {
        let t = theme
        let visibleText = text.isEmpty ? "Sent with attachment" : text
        let attrText = NSMutableAttributedString(string: visibleText, attributes: [
            .font: t.fontBold,
            .foregroundColor: t.textPrimary
        ])

        if !attachments.isEmpty {
            let attachText = attachments.map(\.displayName).joined(separator: ", ")
            attrText.append(NSAttributedString(string: "\n📎 \(attachText)", attributes: [
                .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: t.textDim
            ]))
        }
        
        let bubble = ChatBubbleView(text: attrText, isUser: true, speakerName: "You", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        var cleaned = text
        if currentAssistantText.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
        }
        currentAssistantText += cleaned
        if !cleaned.isEmpty {
            if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                lastBubble.setText(formatted)
            } else {
                beginAssistantTurn(name: theme.titleString)
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(currentAssistantText, theme: theme)
                    lastBubble.setText(formatted)
                }
            }
            scrollToBottom()
        }
    }

    func beginAssistantTurn(name: String?) {
        let labelName = name ?? theme.titleString
        let bubble = ChatBubbleView(text: NSAttributedString(string: ""), isUser: false, speakerName: labelName, theme: theme)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func endStreaming() {
        isStreaming = false
    }

    func appendError(_ text: String) {
        let t = theme
        let errorText = NSAttributedString(string: text, attributes: [
            .font: t.font,
            .foregroundColor: t.errorColor
        ])
        let bubble = ChatBubbleView(text: errorText, isUser: false, speakerName: "System", theme: t)
        transcriptStack.addArrangedSubview(bubble)
        bubble.widthAnchor.constraint(equalTo: transcriptStack.widthAnchor).isActive = true
        scrollToBottom()
    }

    func appendStatus(_ text: String) {
        // Handled entirely by live status pill
    }

    func appendExpertSuggestion(_ experts: [ResponderExpert]) {
        currentExpertSuggestions = experts
        expertSuggestionsCollapsed = false
        renderTranscriptSuggestions()
    }

    func appendToolUse(toolName: String, summary: String) {
        endStreaming()
        let statusText = summary.isEmpty ? toolName : "\(toolName): \(summary)"
        setLiveStatus(statusText, isBusy: true, isError: false)
    }

    func appendToolResult(summary: String, isError: Bool) {
        setLiveStatus(summary, isBusy: !isError, isError: isError)
    }

    func replayHistory(_ messages: [ClaudeSession.Message]) {
        replayConversation(messages, expertSuggestions: [])
    }

    func replayConversation(_ messages: [ClaudeSession.Message], expertSuggestions: [ExpertSuggestionEntry]) {
        let t = theme
        transcriptStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        transcriptSuggestionView = nil
        hideWelcomeSuggestionsPanel()
        currentAssistantText = ""
        var lastRole: ClaudeSession.Message.Role?
        let suggestionsByAnchor = Dictionary(grouping: expertSuggestions, by: \.anchorHistoryCount)
        
        for (index, msg) in messages.enumerated() {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                if lastRole != .assistant {
                    beginAssistantTurn(name: t.titleString)
                }
                if let lastBubble = transcriptStack.arrangedSubviews.last as? ChatBubbleView {
                    let formatted = TerminalMarkdownRenderer.render(msg.text + "\n", theme: t)
                    lastBubble.appendText(formatted)
                }
            case .error:
                appendError(msg.text)
            case .toolUse, .toolResult:
                continue
            }
            lastRole = msg.role

            let anchorHistoryCount = index + 1
            if let entries = suggestionsByAnchor[anchorHistoryCount] {
                for entry in entries {
                    appendSuggestionEntryView(entry)
                }
            }
        }

        if lastRole == .assistant {
            endStreaming()
        }
        scrollToBottom()
    }

    func scrollToBottom() {
        resizeTranscriptToFitContent()
        if let docView = scrollView.documentView {
            let maxScroll = docView.bounds.height - scrollView.contentSize.height
            if maxScroll > 0 {
                docView.scroll(NSPoint(x: 0, y: maxScroll))
            }
        }
    }

    func scrollToTop() {
        resizeTranscriptToFitContent()
        scrollView.documentView?.scroll(NSPoint(x: 0, y: 0))
    }

    func resizeTranscriptToFitContent() {
        transcriptStack.layoutSubtreeIfNeeded()
        let stackHeight = transcriptStack.fittingSize.height
        let targetHeight = max(scrollView.contentSize.height, stackHeight + 10)
        transcriptContainer.frame.size.height = targetHeight
    }
}
