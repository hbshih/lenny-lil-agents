import AppKit

class TranscriptStatusView: NSView {
    private let theme: PopoverTheme
    private let headerStack = NSStackView()
    private let avatarContainer = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let activityBadge = NSView()
    private let activityStack = NSStackView()
    private let spinnerView = NSProgressIndicator()
    private let textLabel = NSTextField(labelWithString: "")
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
        let preferredWidth = widthAnchor.constraint(lessThanOrEqualToConstant: 468)
        preferredWidth.priority = .defaultHigh

        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10
        headerStack.edgeInsets = NSEdgeInsetsZero
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerStack)

        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.setContentHuggingPriority(.required, for: .horizontal)
        avatarContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        avatarWidthConstraint = avatarContainer.widthAnchor.constraint(equalToConstant: 28)
        avatarWidthConstraint?.isActive = true
        headerStack.addArrangedSubview(avatarContainer)

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = theme.accentColor
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 2
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)

        activityBadge.wantsLayer = true
        activityBadge.translatesAutoresizingMaskIntoConstraints = false
        activityBadge.layer?.backgroundColor = theme.inputBg.withAlphaComponent(0.72).cgColor
        activityBadge.layer?.borderWidth = 0.75
        activityBadge.layer?.borderColor = theme.separatorColor.withAlphaComponent(0.18).cgColor
        activityBadge.layer?.cornerRadius = 18
        addSubview(activityBadge)

        activityStack.orientation = .horizontal
        activityStack.alignment = .centerY
        activityStack.spacing = 10
        activityStack.edgeInsets = NSEdgeInsetsZero
        activityStack.translatesAutoresizingMaskIntoConstraints = false
        activityBadge.addSubview(activityStack)

        spinnerView.style = .spinning
        spinnerView.controlSize = .small
        spinnerView.isIndeterminate = true
        spinnerView.isDisplayedWhenStopped = false
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        activityStack.addArrangedSubview(spinnerView)

        textLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        textLabel.textColor = theme.textPrimary
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 2
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        activityStack.addArrangedSubview(textLabel)

        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 28),

            activityStack.topAnchor.constraint(equalTo: activityBadge.topAnchor, constant: 10),
            activityStack.leadingAnchor.constraint(equalTo: activityBadge.leadingAnchor, constant: 14),
            activityStack.trailingAnchor.constraint(equalTo: activityBadge.trailingAnchor, constant: -16),
            activityStack.bottomAnchor.constraint(equalTo: activityBadge.bottomAnchor, constant: -10),

            spinnerView.widthAnchor.constraint(equalToConstant: 16),
            spinnerView.heightAnchor.constraint(equalToConstant: 16),

            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),

            activityBadge.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            activityBadge.leadingAnchor.constraint(equalTo: leadingAnchor),
            activityBadge.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -56),
            activityBadge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            preferredWidth
        ])
    }

    func update(text: String, experts: [ResponderExpert] = []) {
        textLabel.stringValue = text
        titleLabel.stringValue = expertTitle(for: experts)
        populateAvatar(experts: experts)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            spinnerView.stopAnimation(nil)
        } else {
            spinnerView.startAnimation(nil)
        }
    }

    private func populateAvatar(experts: [ResponderExpert]) {
        avatarContainer.subviews.forEach { $0.removeFromSuperview() }

        let visibleExperts = Array(experts.prefix(3))
        let avatarSize: CGFloat = 28
        let overlap: CGFloat = 9
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
                avatarShell.layer?.borderColor = theme.inputBg.cgColor
                avatarShell.translatesAutoresizingMaskIntoConstraints = false
                avatarContainer.addSubview(avatarShell)

                let avatarView = NSImageView()
                avatarView.image = image
                avatarView.imageScaling = .scaleProportionallyUpOrDown
                avatarView.imageAlignment = .alignCenter
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

        guard let image = resolvedLennyAvatarImage() else { return }

        let avatarShell = NSView()
        avatarShell.wantsLayer = true
        avatarShell.layer?.cornerRadius = avatarSize / 2
        avatarShell.layer?.masksToBounds = true
        avatarShell.layer?.borderWidth = 1.5
        avatarShell.layer?.borderColor = theme.inputBg.cgColor
        avatarShell.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarShell)

        let avatarView = NSImageView()
        avatarView.image = image
        avatarView.imageScaling = .scaleProportionallyUpOrDown
        avatarView.imageAlignment = .alignCenter
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarShell.addSubview(avatarView)

        NSLayoutConstraint.activate([
            avatarShell.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarShell.leadingAnchor.constraint(equalTo: avatarContainer.leadingAnchor),
            avatarShell.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarShell.heightAnchor.constraint(equalToConstant: avatarSize),

            avatarView.topAnchor.constraint(equalTo: avatarShell.topAnchor),
            avatarView.leadingAnchor.constraint(equalTo: avatarShell.leadingAnchor),
            avatarView.trailingAnchor.constraint(equalTo: avatarShell.trailingAnchor),
            avatarView.bottomAnchor.constraint(equalTo: avatarShell.bottomAnchor)
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
        case 3:
            return "\(names[0]), \(names[1]), and \(names[2])"
        default:
            let hiddenCount = names.count - 3
            return "\(names[0]), \(names[1]), and \(names[2]) +\(hiddenCount)"
        }
    }
}
