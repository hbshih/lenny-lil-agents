import AppKit

extension TerminalView {
    func setExpertSuggestions(_ experts: [ResponderExpert]) {
        expertSuggestionTargets.removeAll()
        expertSuggestionStack.arrangedSubviews.forEach { view in
            expertSuggestionStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !experts.isEmpty else {
            setPanelVisibility(expertSuggestionContainer, hidden: true)
            relayoutPanels()
            return
        }

        let t = theme
        for expert in experts {
            let identifier = normalizeExpertSuggestionID(expert.name)
            expertSuggestionTargets[identifier] = expert

            let button = NSButton(title: "", target: self, action: #selector(expertSuggestionButtonTapped(_:)))
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.wantsLayer = true
            button.layer?.backgroundColor = t.bubbleBg.cgColor
            button.layer?.cornerRadius = 12
            button.layer?.borderWidth = 0.75
            button.layer?.borderColor = t.separatorColor.withAlphaComponent(0.50).cgColor
            button.attributedTitle = NSAttributedString(
                string: expert.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                    .foregroundColor: t.titleText
                ]
            )
            button.setButtonType(.momentaryPushIn)
            button.imagePosition = .noImage
            button.identifier = NSUserInterfaceItemIdentifier(identifier)
            button.contentTintColor = t.titleText
            button.alignment = .left
            button.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            button.translatesAutoresizingMaskIntoConstraints = false
            expertSuggestionStack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }

        setPanelVisibility(expertSuggestionContainer, hidden: false)
        relayoutPanels()
    }

    func setLiveStatus(_ text: String, isBusy: Bool, isError: Bool = false) {
        let t = theme
        guard !text.isEmpty else {
            clearLiveStatus()
            return
        }

        liveStatusContainer.layer?.borderColor = (isError ? t.errorColor : t.separatorColor.withAlphaComponent(0.42)).cgColor
        liveStatusContainer.layer?.backgroundColor = (isError ? t.errorColor.withAlphaComponent(0.08) : t.inputBg.withAlphaComponent(0.96)).cgColor
        liveStatusLabel.textColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        liveStatusLabel.stringValue = text
        setPanelVisibility(liveStatusContainer, hidden: false)

        if isBusy {
            liveStatusSpinner.startAnimation(nil)
        } else {
            liveStatusSpinner.stopAnimation(nil)
        }
        relayoutPanels()
    }

    func clearLiveStatus() {
        liveStatusLabel.stringValue = ""
        liveStatusSpinner.stopAnimation(nil)
        setPanelVisibility(liveStatusContainer, hidden: true)
        relayoutPanels()
    }

    @objc func expertSuggestionButtonTapped(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let expert = expertSuggestionTargets[identifier] else {
            return
        }

        onSelectExpert?(expert)
    }

    func normalizeExpertSuggestionID(_ name: String) -> String {
        let lowered = name.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

}

extension TerminalView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL,
              url.scheme == "lilagents-expert",
              let host = url.host,
              let expert = expertSuggestionTargets[host] else {
            return false
        }

        onSelectExpert?(expert)
        return true
    }
}
