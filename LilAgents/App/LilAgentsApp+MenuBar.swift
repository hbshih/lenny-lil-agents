import AppKit

import Sparkle

extension AppDelegate {
    func updateExpertStatusItems(_ experts: [ResponderExpert]) {
        expertStatusItems.forEach { NSStatusBar.system.removeStatusItem($0) }
        expertStatusItems.removeAll()
        visibleExperts = Array(experts.prefix(3))

        for (index, expert) in visibleExperts.enumerated() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = statusImage(for: expert.avatarPath)
                button.imagePosition = .imageLeading
                button.title = initials(for: expert.name)
                button.imageScaling = .scaleProportionallyUpOrDown
                button.toolTip = "Switch to \(expert.name)"
                button.tag = index
                button.target = self
                button.action = #selector(selectExpert(_:))
            }
            expertStatusItems.append(item)
        }
    }

    func statusImage(for path: String) -> NSImage? {
        let resolvedPath = pngAvatarPath(for: path) ?? path
        guard let image = NSImage(contentsOfFile: resolvedPath) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined()
    }

    @objc func selectExpert(_ sender: NSStatusBarButton) {
        guard sender.tag >= 0, sender.tag < visibleExperts.count else { return }
        controller?.focus(on: visibleExperts[sender.tag])
    }

    func updateFocusedExpert(_ expert: ResponderExpert?) {
        focusedExpert = expert
        char1Item?.title = expert?.name ?? "Show Lil-Lenny"
        backToLennyItem?.isEnabled = expert != nil
        if let button = statusItem?.button {
            button.toolTip = expert == nil ? "Open Lil-Lenny" : "Current guide: \(expert!.name)"
        }
    }

    func refreshPendingUpdateMenuItem() {
        installUpdateItem?.isHidden = !pendingScheduledUpdate
    }

    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        pendingScheduledUpdate = true
        refreshPendingUpdateMenuItem()
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingScheduledUpdate = false
        refreshPendingUpdateMenuItem()
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingScheduledUpdate = false
        refreshPendingUpdateMenuItem()
    }
}

extension AppDelegate: NSMenuDelegate {}
