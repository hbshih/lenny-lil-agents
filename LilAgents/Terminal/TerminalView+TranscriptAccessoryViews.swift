import AppKit

class TranscriptStatusView: NSView {
    private let theme: PopoverTheme
    private let avatarContainer = NSView()
    private let contentStack = NSStackView()
    private let headerStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let textLabel = NSTextField(labelWithString: "")
    private let shell = NSView()
    private var avatarWidthConstraint: NSLayoutConstraint?

    init(theme: PopoverTheme, text: String, experts: [ResponderExpert] = []) {
        self.theme = theme
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        update(text: text, experts: experts)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        shell.wantsLayer = true
        shell.layer?.backgroundColor = theme.bubbleBg.cgColor
        shell.layer?.cornerRadius = 18
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.22).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.setContentHuggingPriority(.required, for: .horizontal)
        avatarContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        avatarWidthConstraint = avatarContainer.widthAnchor.constraint(equalToConstant: 28)
        avatarWidthConstraint?.isActive = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 6
        contentStack.edgeInsets = NSEdgeInsetsZero
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(contentStack)

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10
        headerStack.edgeInsets = NSEdgeInsetsZero
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(headerStack)

        headerStack.addArrangedSubview(avatarContainer)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = theme.accentColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)

        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(textLabel)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarContainer.heightAnchor.constraint(equalToConstant: 28),

            contentStack.topAnchor.constraint(equalTo: shell.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -12)
        ])
    }

    func update(text: String, experts: [ResponderExpert] = []) {
        textLabel.stringValue = text
        titleLabel.stringValue = expertTitle(for: experts)
        populateAvatar(experts: experts)
    }

    private func populateAvatar(experts: [ResponderExpert]) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }

        let visibleExperts = Array(experts.prefix(3))
        let avatarSize: CGFloat = 28
        let overlap: CGFloat = 10
        let width = visibleExperts.isEmpty
            ? avatarSize
            : avatarSize + CGFloat(max(0, visibleExperts.count - 1)) * (avatarSize - overlap)
        avatarWidthConstraint?.constant = width

        if !visibleExperts.isEmpty {
            for (index, expert) in visibleExperts.enumerated() {
                guard let image = resolvedAvatarImage(at: expert.avatarPath) else { continue }

                let avatarShell = NSView()
                avatarShell.wantsLayer = true
                avatarShell.layer?.cornerRadius = avatarSize / 2
                avatarShell.layer?.masksToBounds = true
                avatarShell.layer?.borderWidth = 2
                avatarShell.layer?.borderColor = theme.bubbleBg.cgColor
                avatarShell.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
                avatarShell.layer?.shadowOpacity = 1
                avatarShell.layer?.shadowRadius = 3
                avatarShell.layer?.shadowOffset = CGSize(width: 0, height: -1)
                avatarShell.translatesAutoresizingMaskIntoConstraints = false
                avatarContainer.addSubview(avatarShell)

                let avatarView = NSImageView()
                avatarView.image = image
                avatarView.imageScaling = .scaleAxesIndependently
                avatarView.translatesAutoresizingMaskIntoConstraints = false
                avatarShell.addSubview(avatarView)

                let xOffset = CGFloat(index) * (avatarSize - overlap)
                NSLayoutConstraint.activate([
                    avatarShell.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
                    avatarShell.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor, constant: xOffset),
                    avatarShell.widthAnchor.constraint(equalToConstant: avatarSize),
                    avatarShell.heightAnchor.constraint(equalToConstant: avatarSize),

                    avatarView.topAnchor.constraint(equalTo: avatarShell.topAnchor),
                    avatarView.leadingAnchor.constraint(equalTo: avatarShell.leadingAnchor),
                    avatarView.trailingAnchor.constraint(equalTo: avatarShell.trailingAnchor),
                    avatarView.bottomAnchor.constraint(equalTo: avatarShell.bottomAnchor)
                ])
            }
            return
        }

        let icon = NSImageView()
        if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil) {
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

    private func expertTitle(for experts: [ResponderExpert]) -> String {
        let names = experts.map(\.name)
        switch names.count {
        case 0:
            return "Lil-Lenny"
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) and \(names[1])"
        default:
            let extraCount = names.count - 2
            return "\(names[0]), \(names[1]) +\(extraCount)"
        }
    }
}
