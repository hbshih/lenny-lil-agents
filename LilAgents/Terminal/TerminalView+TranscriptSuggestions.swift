import AppKit

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

        let titleLabel = NSTextField(labelWithString: "Have follow-up questions? Chat with these experts.")
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

        if let image = resolvedAvatarImage(at: expert.avatarPath) {
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
        WalkerCharacter.playSelectionSound()
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
