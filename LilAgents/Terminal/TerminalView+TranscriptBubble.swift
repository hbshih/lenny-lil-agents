import AppKit

class ChatBubbleView: NSView, NSTextViewDelegate {
    let textView = NSTextView()
    let headerLabel = NSTextField(labelWithString: "")
    let bubbleBackground = NSView()
    let avatarContainer = NSView()
    let headerRow = NSStackView()
    let actionRow = NSStackView()
    private let contentColumn = NSStackView()
    private let copyButton = HoverButton(title: "", target: nil, action: nil)
    private let followUpButton = HoverButton(title: "", target: nil, action: nil)
    let isUser: Bool
    private let showsSpeakerHeader: Bool
    private let theme: PopoverTheme
    var textWidthConstraint: NSLayoutConstraint?
    var textHeightConstraint: NSLayoutConstraint?
    var onCopy: (() -> Void)?
    var onFollowUp: (() -> Void)?

    init(
        text: NSAttributedString,
        isUser: Bool,
        speaker: TranscriptSpeaker,
        theme: PopoverTheme,
        showsSpeakerHeader: Bool = true,
        onCopy: (() -> Void)? = nil,
        onFollowUp: (() -> Void)? = nil
    ) {
        self.isUser = isUser
        self.showsSpeakerHeader = showsSpeakerHeader
        self.theme = theme
        self.onCopy = onCopy
        self.onFollowUp = onFollowUp
        super.init(frame: .zero)
        setupViews()
        populate(text: text, speaker: speaker)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        contentColumn.orientation = .vertical
        contentColumn.alignment = isUser ? .trailing : .leading
        contentColumn.spacing = showsSpeakerHeader ? 7 : 0
        contentColumn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentColumn)

        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addArrangedSubview(headerRow)

        avatarContainer.wantsLayer = true
        avatarContainer.layer?.cornerRadius = 14
        avatarContainer.layer?.masksToBounds = true
        avatarContainer.layer?.borderWidth = 1
        avatarContainer.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.30).cgColor
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.widthAnchor.constraint(equalToConstant: isUser ? 0 : 28).isActive = true
        avatarContainer.heightAnchor.constraint(equalToConstant: isUser ? 0 : 28).isActive = true
        avatarContainer.isHidden = isUser
        headerRow.addArrangedSubview(avatarContainer)

        headerLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = isUser ? theme.textDim : theme.accentColor
        headerLabel.alignment = .left
        headerLabel.lineBreakMode = .byTruncatingTail
        headerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.isEditable = false
        headerLabel.isBordered = false
        headerLabel.drawsBackground = false
        headerRow.addArrangedSubview(headerLabel)

        bubbleBackground.wantsLayer = true
        bubbleBackground.layer?.cornerRadius = theme.bubbleCornerRadius
        bubbleBackground.layer?.backgroundColor = isUser
            ? theme.accentColor.withAlphaComponent(0.10).cgColor
            : theme.bubbleBg.cgColor
        bubbleBackground.layer?.borderWidth = isUser ? 0 : 0.75
        bubbleBackground.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.36).cgColor
        bubbleBackground.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addArrangedSubview(bubbleBackground)

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
        p.alignment = isUser ? .right : .left
        textView.defaultParagraphStyle = p
        bubbleBackground.addSubview(textView)

        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 4
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        contentColumn.addArrangedSubview(actionRow)

        NSLayoutConstraint.activate([
            contentColumn.topAnchor.constraint(equalTo: topAnchor),
            contentColumn.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentColumn.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentColumn.bottomAnchor.constraint(equalTo: bottomAnchor),

            textView.topAnchor.constraint(equalTo: bubbleBackground.topAnchor),
            textView.bottomAnchor.constraint(equalTo: bubbleBackground.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: bubbleBackground.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: bubbleBackground.trailingAnchor),

            bubbleBackground.leadingAnchor.constraint(greaterThanOrEqualTo: contentColumn.leadingAnchor, constant: isUser ? 56 : 0),
            bubbleBackground.trailingAnchor.constraint(equalTo: contentColumn.trailingAnchor, constant: isUser ? 0 : -56),
        ])

        contentColumn.setContentHuggingPriority(.required, for: .vertical)
        contentColumn.setContentCompressionResistancePriority(.required, for: .vertical)
        bubbleBackground.setContentHuggingPriority(.required, for: .vertical)
        bubbleBackground.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func configureCopyAction(_ button: HoverButton, action: Selector) {
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = .clear
        button.hoverBg = theme.accentColor.withAlphaComponent(0.10).cgColor
        button.layer?.backgroundColor = .clear
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 0
        button.contentTintColor = theme.textDim
        if let image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: "Copy message") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }
        button.imageScaling = .scaleProportionallyDown
        button.title = ""
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 16).isActive = true
        button.heightAnchor.constraint(equalToConstant: 16).isActive = true
    }

    private func configureFollowUpAction(_ button: HoverButton, action: Selector) {
        button.isBordered = false
        button.wantsLayer = true
        button.normalBg = theme.inputBg.cgColor
        button.hoverBg = theme.accentColor.withAlphaComponent(0.08).cgColor
        button.layer?.backgroundColor = button.normalBg
        button.layer?.cornerRadius = 15
        button.layer?.borderWidth = 1
        button.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.40).cgColor
        button.contentTintColor = theme.textPrimary
        button.attributedTitle = NSAttributedString(string: "Ask follow-up", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: theme.textPrimary
        ])
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 124).isActive = true
    }

    private func populate(text: NSAttributedString, speaker: TranscriptSpeaker) {
        headerLabel.stringValue = speaker.name
        populateAvatar(for: speaker)
        configureHeaderVisibility()
        configureTextContainer()
        textView.textStorage?.setAttributedString(text)
        updateTextAlignment()
        configureActions(for: speaker)
        recalculateSize()
    }

    private func configureHeaderVisibility() {
        if showsSpeakerHeader {
            if headerRow.superview == nil {
                contentColumn.insertArrangedSubview(headerRow, at: 0)
            }
        } else if headerRow.superview != nil {
            contentColumn.removeArrangedSubview(headerRow)
            headerRow.removeFromSuperview()
        }
    }

    private func populateAvatar(for speaker: TranscriptSpeaker) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }
        guard !isUser else { return }

        let image: NSImage?
        if let avatarPath = speaker.avatarPath {
            image = resolvedAvatarImage(at: avatarPath)
        } else if speaker.kind == .lenny {
            image = resolvedLennyAvatarImage()
        } else {
            image = nil
        }

        if let image {
            let avatarView = NSImageView()
            avatarView.image = image
            avatarView.imageScaling = .scaleProportionallyUpOrDown
            avatarView.imageAlignment = .alignCenter
            avatarView.translatesAutoresizingMaskIntoConstraints = false
            avatarContainer.addSubview(avatarView)
            NSLayoutConstraint.activate([
                avatarView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                avatarView.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
                avatarView.trailingAnchor.constraint(equalTo: avatarContainer.trailingAnchor),
                avatarView.bottomAnchor.constraint(equalTo: avatarContainer.bottomAnchor)
            ])
            return
        }

        let icon = NSImageView()
        let symbolName = speaker.kind == .lenny ? "sparkles" : "person.crop.circle.fill"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            icon.image = image.withSymbolConfiguration(config)
        }
        icon.contentTintColor = theme.accentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: avatarContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 15),
            icon.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    private func configureActions(for speaker: TranscriptSpeaker) {
        actionRow.arrangedSubviews.forEach {
            actionRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if speaker.kind == .expert, onCopy != nil {
            configureCopyAction(copyButton, action: #selector(copyTapped))
            actionRow.addArrangedSubview(copyButton)
        }

        if speaker.kind == .expert, onFollowUp != nil {
            configureFollowUpAction(followUpButton, action: #selector(followUpTapped))
            actionRow.addArrangedSubview(followUpButton)
        }

        if actionRow.arrangedSubviews.isEmpty {
            contentColumn.removeArrangedSubview(actionRow)
            actionRow.removeFromSuperview()
        } else if actionRow.superview == nil {
            contentColumn.addArrangedSubview(actionRow)
        }
    }

    override var intrinsicContentSize: NSSize {
        let fitting = contentColumn.fittingSize
        return NSSize(width: NSView.noIntrinsicMetric, height: fitting.height)
    }
}
