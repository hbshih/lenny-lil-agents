import AppKit

class TranscriptStatusView: NSView {
    private let theme: PopoverTheme
    private let avatarContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let textLabel = NSTextField(labelWithString: "")
    private let shell = NSView()

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
        shell.layer?.cornerRadius = 14
        shell.layer?.borderWidth = 1
        shell.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.28).cgColor
        shell.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shell)
        let preferredWidth = shell.widthAnchor.constraint(equalTo: widthAnchor, constant: -56)
        preferredWidth.priority = .defaultHigh

        avatarContainer.wantsLayer = true
        avatarContainer.layer?.cornerRadius = 14
        avatarContainer.layer?.masksToBounds = true
        avatarContainer.layer?.borderWidth = 1
        avatarContainer.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.30).cgColor
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(avatarContainer)

        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = theme.accentColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(titleLabel)

        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(textLabel)

        NSLayoutConstraint.activate([
            shell.topAnchor.constraint(equalTo: topAnchor),
            shell.leadingAnchor.constraint(equalTo: leadingAnchor),
            shell.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            shell.widthAnchor.constraint(lessThanOrEqualToConstant: 396),
            preferredWidth,
            shell.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatarContainer.topAnchor.constraint(equalTo: shell.topAnchor, constant: 10),
            avatarContainer.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            avatarContainer.widthAnchor.constraint(equalToConstant: 28),
            avatarContainer.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: shell.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: avatarContainer.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14),

            textLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: shell.leadingAnchor, constant: 14),
            textLabel.trailingAnchor.constraint(equalTo: shell.trailingAnchor, constant: -14),
            textLabel.bottomAnchor.constraint(equalTo: shell.bottomAnchor, constant: -12)
        ])
    }

    func update(text: String, experts: [ResponderExpert] = []) {
        textLabel.stringValue = text
        titleLabel.stringValue = experts.first?.name ?? "Lil-Lenny"
        populateAvatar(experts: experts)
    }

    private func populateAvatar(experts: [ResponderExpert]) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }

        if let avatarPath = experts.first?.avatarPath,
           let image = resolvedAvatarImage(at: avatarPath) {
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
}
