import AppKit

class LilAgentsController {
    var characters: [WalkerCharacter] = []
    private var displayLink: CVDisplayLink?
    var debugWindow: NSWindow?
    var pinnedScreenIndex: Int = -1
    private static let onboardingKey = "hasCompletedOnboarding"
    private let maxVisibleGuestAvatars = 3
    private var currentExperts: [ResponderExpert] = []
    var suggestedExperts: [ResponderExpert] { Array(currentExperts.prefix(maxVisibleGuestAvatars)) }
    var onExpertsChanged: (([ResponderExpert]) -> Void)?
    var onFocusedExpertChanged: ((ResponderExpert?) -> Void)?
    private(set) var focusedExpert: ResponderExpert?

    func start() {
        let lenny = WalkerCharacter(videoName: "lenny")
        lenny.accelStart = 2.5
        lenny.fullSpeedStart = 3.2
        lenny.decelStart = 7.8
        lenny.walkStop = 8.4
        lenny.walkAmountRange = 0.35...0.6
        lenny.yOffset = -4
        lenny.characterColor = NSColor(red: 0.96, green: 0.63, blue: 0.23, alpha: 1.0)
        lenny.positionProgress = 0.9
        lenny.pauseEndTime = CACurrentMediaTime() + Double.random(in: 0.5...2.0)
        lenny.setup()

        characters = [lenny]
        characters.forEach { $0.controller = self }

        setupDebugLine()
        startDisplayLink()

        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            triggerOnboarding()
        }
    }

    private func triggerOnboarding() {
        guard let bruce = characters.first else { return }
        bruce.isOnboarding = true
        // Show "hi!" bubble after a short delay so the character is visible first
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            bruce.currentPhrase = "hi!"
            bruce.showingCompletion = true
            bruce.completionBubbleExpiry = CACurrentMediaTime() + 600 // stays until clicked
            bruce.showBubble(text: "hi!", isCompletion: true)
            bruce.playCompletionSound()
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        characters.forEach { $0.isOnboarding = false }
    }

    func updateExperts(_ experts: [ResponderExpert]) {
        currentExperts = experts
        onExpertsChanged?(experts)
        syncGuestCharacters()
    }

    func returnToGenie() {
        currentExperts.removeAll()
        onExpertsChanged?([])
        focus(on: nil)
    }

    func focus(on expert: ResponderExpert?) {
        focusedExpert = expert
        onFocusedExpertChanged?(expert)
        guard let character = characters.first else { return }
        character.focus(on: expert)
        syncGuestCharacters()
    }

    func openDialog(for expert: ResponderExpert?) {
        guard let expert else {
            focus(on: nil)
            return
        }

        if let character = characters.first(where: { candidate in
            if candidate === characters.first {
                return candidate.focusedExpert == expert
            }
            return candidate.isCompanionAvatar && candidate.representedExpert == expert
        }) {
            character.focusedExpert = expert
            character.claudeSession?.focusedExpert = expert
            character.openPopover()
            return
        }

        focus(on: expert)
    }

    private func syncGuestCharacters() {
        guard let mainCharacter = characters.first else { return }

        let visibleGuestNames = Set(currentExperts.prefix(maxVisibleGuestAvatars).map(\.name))
        let companionExperts = currentExperts
            .filter { visibleGuestNames.contains($0.name) }
            .filter { expert in
                guard let focusedExpert else { return true }
                return expert != focusedExpert
            }
            .prefix(max(0, maxVisibleGuestAvatars - (focusedExpert == nil ? 0 : 1)))

        while characters.count - 1 < companionExperts.count {
            let companion = WalkerCharacter(videoName: "guest-\(characters.count)")
            companion.yOffset = -4
            companion.characterColor = .white
            companion.controller = self
            companion.setup()
            companion.hideCompanionAvatar()
            characters.append(companion)
        }

        let layoutPositions = companionPositions(count: companionExperts.count, mainPosition: mainCharacter.positionProgress)

        for (index, expert) in companionExperts.enumerated() {
            let companion = characters[index + 1]
            companion.controller = self
            companion.configureCompanionAvatar(expert: expert, position: layoutPositions[index])
        }

        if characters.count > companionExperts.count + 1 {
            for companion in characters[(companionExperts.count + 1)...] {
                companion.hideCompanionAvatar()
            }
        }
    }

    private func companionPositions(count: Int, mainPosition: CGFloat) -> [CGFloat] {
        switch count {
        case 0:
            return []
        case 1:
            return [mainPosition < 0.55 ? 0.78 : 0.22]
        case 2:
            return [0.2, 0.8]
        default:
            let candidates: [CGFloat] = [0.12, 0.3, 0.5, 0.7, 0.88]
            let filtered = candidates.filter { abs($0 - mainPosition) > 0.08 }
            let chosen = (filtered.isEmpty ? candidates : filtered)
                .sorted { abs($0 - mainPosition) > abs($1 - mainPosition) }
            return Array(chosen.prefix(count)).sorted()
        }
    }

    func currentDockMetrics() -> (screen: NSScreen, dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat)? {
        guard let screen = activeScreen else { return nil }

        let screenWidth = screen.frame.width
        let dockX: CGFloat
        let dockWidth: CGFloat
        let dockTopY: CGFloat

        if screenHasDock(screen) {
            (dockX, dockWidth) = getDockIconArea(screenWidth: screenWidth)
            dockTopY = screen.visibleFrame.origin.y
        } else {
            let margin: CGFloat = 40.0
            dockX = screen.frame.origin.x + margin
            dockWidth = screenWidth - margin * 2
            dockTopY = screen.frame.origin.y
        }

        return (screen, dockX, dockWidth, dockTopY)
    }

    // MARK: - Debug

    private func setupDebugLine() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 2),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = NSColor.red
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.orderOut(nil)
        debugWindow = win
    }

    private func updateDebugLine(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        guard let win = debugWindow, win.isVisible else { return }
        win.setFrame(CGRect(x: dockX, y: dockTopY, width: dockWidth, height: 2), display: true)
    }

    // MARK: - Dock Geometry

    private func getDockIconArea(screenWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        // Each dock slot is the icon + padding. The padding scales with tile size.
        // At default 48pt: slot ≈ 58pt. At 37pt: slot ≈ 47pt. Roughly tileSize * 1.25.
        let slotWidth = tileSize * 1.25

        let persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0

        // Only count recent apps if show-recents is enabled
        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) { dividers += 1 }
        if persistentOthers > 0 && recentApps > 0 { dividers += 1 }
        // show-recents adds its own divider
        if showRecents && recentApps > 0 { dividers += 1 }

        let dividerWidth: CGFloat = 12.0
        var dockWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth

        let magnificationEnabled = dockDefaults?.bool(forKey: "magnification") ?? false
        if magnificationEnabled,
           let largeSize = dockDefaults?.object(forKey: "largesize") as? CGFloat {
            // Magnification only affects the hovered area; at rest the dock is normal size.
            // Don't inflate the width — characters should stay within the at-rest bounds.
            _ = largeSize
        }

        // Small fudge factor for dock edge padding
        dockWidth *= 1.1
        let dockX = (screenWidth - dockWidth) / 2.0
        return (dockX, dockWidth)
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let controller = Unmanaged<LilAgentsController>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.tick()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(displayLink, callback,
                                       Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink)
    }

    var activeScreen: NSScreen? {
        if pinnedScreenIndex >= 0, pinnedScreenIndex < NSScreen.screens.count {
            return NSScreen.screens[pinnedScreenIndex]
        }
        return NSScreen.main
    }

    /// The dock lives on the screen where visibleFrame.origin.y > frame.origin.y (bottom dock)
    /// On screens without the dock, visibleFrame.origin.y == frame.origin.y
    private func screenHasDock(_ screen: NSScreen) -> Bool {
        return screen.visibleFrame.origin.y > screen.frame.origin.y
    }

    func tick() {
        guard let metrics = currentDockMetrics() else { return }
        let screen = metrics.screen
        let dockX = metrics.dockX
        let dockWidth = metrics.dockWidth
        let dockTopY = metrics.dockTopY

        updateDebugLine(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)

        let activeChars = characters.filter { $0.window.isVisible }

        let now = CACurrentMediaTime()
        let anyWalking = activeChars.contains { $0.isWalking }
        for char in activeChars {
            if char.isIdleForPopover { continue }
            if char.isPaused && now >= char.pauseEndTime && anyWalking {
                char.pauseEndTime = now + Double.random(in: 5.0...10.0)
            }
        }
        for char in activeChars {
            char.update(screen: screen, dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)
        }

        let sorted = activeChars.sorted { $0.positionProgress < $1.positionProgress }
        for (i, char) in sorted.enumerated() {
            char.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + i)
        }
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}
