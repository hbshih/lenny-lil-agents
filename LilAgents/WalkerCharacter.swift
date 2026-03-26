import AppKit

final class WalkerCharacter {
    let videoName: String
    var window: NSWindow!
    var imageView: NSImageView!

    let displayHeight: CGFloat = 154
    let displayWidth: CGFloat = 154

    var accelStart: CFTimeInterval = 3.0
    var fullSpeedStart: CFTimeInterval = 3.75
    var decelStart: CFTimeInterval = 7.5
    var walkStop: CFTimeInterval = 8.25
    var walkAmountRange: ClosedRange<CGFloat> = 0.25...0.5
    var yOffset: CGFloat = 0
    var flipXOffset: CGFloat = 0
    var characterColor: NSColor = .gray

    var walkStartTime: CFTimeInterval = 0
    var positionProgress: CGFloat = 0.0
    var isWalking = false
    var isPaused = true
    var pauseEndTime: CFTimeInterval = 0
    var goingRight = true
    var walkStartPos: CGFloat = 0.0
    var walkEndPos: CGFloat = 0.0
    var currentTravelDistance: CGFloat = 500.0
    var walkStartPixel: CGFloat = 0.0
    var walkEndPixel: CGFloat = 0.0

    var isOnboarding = false
    var isIdleForPopover = false
    var popoverWindow: NSWindow?
    var terminalView: TerminalView?
    var claudeSession: ClaudeSession?
    var clickOutsideMonitor: Any?
    var escapeKeyMonitor: Any?
    weak var controller: LilAgentsController?
    var themeOverride: PopoverTheme?
    var thinkingBubbleWindow: NSWindow?
    var focusedExpert: ResponderExpert?
    var representedExpert: ResponderExpert?
    var isCompanionAvatar = false
    var handoffEffectWindow: NSWindow?

    var isClaudeBusy: Bool { claudeSession?.isBusy ?? false }

    var directionalImages: [WalkerFacing: NSImage] = [:]
    var persona: WalkerPersona = .lenny

    var lastPhraseUpdate: CFTimeInterval = 0
    var currentPhrase = ""
    var completionBubbleExpiry: CFTimeInterval = 0
    var showingCompletion = false
    var phraseAnimating = false

    init(videoName: String) {
        self.videoName = videoName
    }
}
