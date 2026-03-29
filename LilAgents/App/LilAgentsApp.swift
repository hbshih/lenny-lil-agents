import SwiftUI
import AppKit
import Sparkle

@main
struct LilAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate {
    var controller: LilAgentsController?
    var statusItem: NSStatusItem?
    var expertStatusItems: [NSStatusItem] = []
    var visibleExperts: [ResponderExpert] = []
    var focusedExpert: ResponderExpert?
    var settingsWindow: NSWindow?
    var char1Item: NSMenuItem?
    var backToLennyItem: NSMenuItem?
    var installUpdateItem: NSMenuItem?
    var pendingScheduledUpdate = false
    var updaterController: SPUStandardUpdaterController!

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = LilAgentsController()
        controller?.onExpertsChanged = { [weak self] experts in
            self?.updateExpertStatusItems(experts)
        }
        controller?.onFocusedExpertChanged = { [weak self] expert in
            self?.updateFocusedExpert(expert)
        }
        controller?.start()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.characters.forEach { $0.claudeSession?.terminate() }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Lenny")
            button.toolTip = "Open Lenny"
        }

        let menu = NSMenu()

        let char1Item = NSMenuItem(title: "Show Lenny", action: #selector(toggleChar1), keyEquivalent: "1")
        char1Item.state = .on
        menu.addItem(char1Item)
        self.char1Item = char1Item

        let backToLennyItem = NSMenuItem(title: "Back to Lenny", action: #selector(backToLenny), keyEquivalent: "")
        backToLennyItem.isEnabled = false
        menu.addItem(backToLennyItem)
        self.backToLennyItem = backToLennyItem

        menu.addItem(NSMenuItem.separator())

        let soundItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.state = .on
        menu.addItem(soundItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for (i, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = i
            item.state = i == 0 ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Display submenu
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let autoItem = NSMenuItem(title: "Auto (Main Display)", action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.tag = -1
        autoItem.state = .on
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.tag = i
            item.state = .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        let debugShowExpertsItem = NSMenuItem(title: "Debug Expert Suggestions", action: #selector(showDebugExpertSuggestions), keyEquivalent: "")
        menu.addItem(debugShowExpertsItem)

        let debugClearExpertsItem = NSMenuItem(title: "Clear Debug Suggestions", action: #selector(clearDebugExpertSuggestions), keyEquivalent: "")
        menu.addItem(debugClearExpertsItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let installUpdateItem = NSMenuItem(title: "Install Available Update…", action: #selector(installPendingUpdate), keyEquivalent: "")
        installUpdateItem.isHidden = true
        installUpdateItem.target = self
        menu.addItem(installUpdateItem)
        self.installUpdateItem = installUpdateItem

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.claudeSession, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
        }
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 0 else { return }
        let char = chars[0]
        if char.window.isVisible {
            char.window.orderOut(nil)
            sender.state = .off
        } else {
            char.window.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func backToLenny() {
        controller?.returnToGenie()
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func showDebugExpertSuggestions() {
        guard let controller, let char = controller.characters.first else { return }

        if controller.focusedExpert != nil {
            controller.focus(on: nil)
        }
        if !char.isIdleForPopover {
            char.openPopover()
        }

        let experts = controller.debugExpertSuggestions()
        char.terminalView?.setExpertSuggestions(experts)
        char.updatePopoverPosition()
        char.popoverWindow?.orderFrontRegardless()
        char.popoverWindow?.makeKey()
        if let terminal = char.terminalView {
            char.popoverWindow?.makeFirstResponder(terminal.inputField)
        }
    }

    @objc func clearDebugExpertSuggestions() {
        guard let controller, let char = controller.characters.first else { return }
        controller.clearDebugExpertSuggestions()
        char.terminalView?.hideExpertSuggestions()
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lenny Settings"
            let hostingController = NSHostingController(rootView: SettingsView())
            window.contentViewController = hostingController
            window.setContentSize(NSSize(width: 600, height: 460))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func installPendingUpdate() {
        pendingScheduledUpdate = false
        refreshPendingUpdateMenuItem()
        updaterController.checkForUpdates(nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func updateExpertStatusItems(_ experts: [ResponderExpert]) {
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

    private func statusImage(for path: String) -> NSImage? {
        let resolvedPath = pngAvatarPath(for: path) ?? path
        guard let image = NSImage(contentsOfFile: resolvedPath) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
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

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined()
    }

    @objc func selectExpert(_ sender: NSStatusBarButton) {
        guard sender.tag >= 0, sender.tag < visibleExperts.count else { return }
        controller?.focus(on: visibleExperts[sender.tag])
    }

    private func updateFocusedExpert(_ expert: ResponderExpert?) {
        focusedExpert = expert
        char1Item?.title = expert?.name ?? "Show Lenny"
        backToLennyItem?.isEnabled = expert != nil
        if let button = statusItem?.button {
            button.toolTip = expert == nil ? "Open Lenny" : "Current guide: \(expert!.name)"
        }
    }

    private func refreshPendingUpdateMenuItem() {
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
