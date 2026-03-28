import AppKit

extension WalkerCharacter {
    func updateExpertNameTag() {
        let baseName = representedExpert?.name ?? focusedExpert?.name
        let tagText: String
        if isClaudeBusy, !currentActivityStatus.isEmpty {
            tagText = currentActivityStatus
        } else if let baseName, !baseName.isEmpty {
            tagText = baseName
        } else {
            hideExpertNameTag()
            return
        }

        if expertNameWindow == nil {
            createExpertNameTag()
        }

        let t = resolvedTheme
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let horizontalPadding: CGFloat = 12
        let textWidth = ceil((tagText as NSString).size(withAttributes: [.font: font]).width)
        let tagWidth = min(max(textWidth + horizontalPadding * 2, 82), 180)
        let tagHeight = Self.expertNameTagH

        let charFrame = window.frame
        let x = charFrame.midX - tagWidth / 2
        let y = charFrame.maxY - 4
        expertNameWindow?.setFrame(CGRect(x: x, y: y, width: tagWidth, height: tagHeight), display: false)

        if let container = expertNameWindow?.contentView {
            container.frame = NSRect(x: 0, y: 0, width: tagWidth, height: tagHeight)
            container.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.96).cgColor
            container.layer?.borderColor = t.popoverBorder.withAlphaComponent(0.55).cgColor
            container.layer?.cornerRadius = tagHeight / 2

            if let label = container.viewWithTag(410) as? NSTextField {
                label.frame = NSRect(x: horizontalPadding, y: 4, width: tagWidth - horizontalPadding * 2, height: 16)
                label.font = font
                label.textColor = t.titleText
                label.stringValue = tagText
            }
        }

        if !(expertNameWindow?.isVisible ?? false) {
            expertNameWindow?.alphaValue = 1.0
            expertNameWindow?.orderFrontRegardless()
        }
    }

    func hideExpertNameTag() {
        if expertNameWindow?.isVisible ?? false {
            expertNameWindow?.orderOut(nil)
        }
    }

    func createExpertNameTag() {
        let t = resolvedTheme
        let w: CGFloat = 120
        let h = Self.expertNameTagH
        let win = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        win.isOpaque = false
        win.backgroundColor = NSColor.clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
        win.ignoresMouseEvents = true
        win.collectionBehavior = NSWindow.CollectionBehavior([.canJoinAllSpaces, .stationary])

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = t.titleBarBg.withAlphaComponent(0.96).cgColor
        container.layer?.cornerRadius = h / 2
        container.layer?.borderWidth = 1
        container.layer?.borderColor = t.popoverBorder.withAlphaComponent(0.55).cgColor
        container.layer?.shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor
        container.layer?.shadowOpacity = 1
        container.layer?.shadowRadius = 8
        container.layer?.shadowOffset = CGSize(width: 0, height: -1)

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        label.textColor = t.titleText
        label.alignment = .center
        label.drawsBackground = false
        label.isBordered = false
        label.isEditable = false
        label.frame = NSRect(x: 12, y: 4, width: w - 24, height: 16)
        label.tag = 410
        container.addSubview(label)

        win.contentView = container
        expertNameWindow = win
    }
}
