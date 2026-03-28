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
            button.wantsLayer = true
            button.layer?.backgroundColor = t.bubbleBg.cgColor
            button.layer?.cornerRadius = 14
            button.layer?.borderWidth = 1
            button.layer?.borderColor = t.accentColor.withAlphaComponent(0.2).cgColor
            
            let pstyle = NSMutableParagraphStyle()
            pstyle.alignment = .center
            
            button.attributedTitle = NSAttributedString(
                string: expert.name,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: t.accentColor,
                    .paragraphStyle: pstyle
                ]
            )
            button.setButtonType(.momentaryPushIn)
            button.identifier = NSUserInterfaceItemIdentifier(identifier)
            button.translatesAutoresizingMaskIntoConstraints = false
            expertSuggestionStack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
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

        // Hide input area controls
        inputField.isHidden = true
        sendButton.isHidden = true
        attachButton.isHidden = true

        liveStatusLabel.textColor = isError ? t.errorColor : (isBusy ? t.accentColor : t.successColor)
        liveStatusLabel.stringValue = text
        
        liveStatusLabel.isHidden = false
        liveStatusSpinner.isHidden = !isBusy

        if isBusy {
            liveStatusSpinner.startAnimation(nil)
        } else {
            liveStatusSpinner.stopAnimation(nil)
        }
    }

    func clearLiveStatus() {
        liveStatusLabel.stringValue = ""
        liveStatusSpinner.stopAnimation(nil)
        
        liveStatusSpinner.isHidden = true
        liveStatusLabel.isHidden = true
        
        // Show input area controls
        inputField.isHidden = false
        sendButton.isHidden = false
        attachButton.isHidden = false
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
