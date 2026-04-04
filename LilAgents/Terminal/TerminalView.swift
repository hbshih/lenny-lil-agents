import AppKit

class TerminalView: NSView {
    let scrollView = NSScrollView()
    let transcriptContainer = FlippedView()
    let transcriptStack = NSStackView()
    let inputField = NSTextField()
    let liveStatusContainer = NSView()
    let liveStatusSpinner = NSProgressIndicator()
    let liveStatusAvatarView = NSImageView()
    let liveStatusLabel = NSTextField(labelWithString: "")
    let attachmentStrip = NSView()
    let attachmentScrollView = NSScrollView()
    let attachmentPreviewDocumentView = NSView()
    let attachmentPreviewStack = NSStackView()
    let attachmentHintLabel = NSTextField(labelWithString: "")
    let expertSuggestionContainer = NSView()
    let expertSuggestionLabel = NSTextField(labelWithString: "")
    let expertSuggestionStack = NSStackView()
    let attachButton = HoverButton(title: "", target: nil, action: nil)
    let sendButton = HoverButton(title: "", target: nil, action: nil)
    let composerStatusLabel = NSTextField(labelWithString: "Generating...")
    let returnButton = NSButton(title: "Back to Lil-Lenny", target: nil, action: nil)
    var onSendMessage: ((String, [SessionAttachment]) -> Void)?
    var onStopRequested: (() -> Void)?
    var onReturnToLenny: (() -> Void)?
    var onSelectExpert: ((ResponderExpert) -> Void)?
    var onSelectExpertSuggestion: ((UUID, ResponderExpert) -> Void)?
    var onEditExpertSuggestion: ((UUID) -> Void)?
    var onTogglePinned: (() -> Void)?
    var onCloseRequested: (() -> Void)?
    var onRefreshSetupState: (() -> Void)?

    var characterColor: NSColor?
    var themeOverride: PopoverTheme?
    var currentAssistantText = ""
    var isStreaming = false
    var placeholderText = "Ask a question or drop in a file"
    var welcomeChipsView: WelcomeChipsView?
    var pendingAttachments: [SessionAttachment] = []
    var expertSuggestionTargets: [String: ResponderExpert] = [:]
    var deferredExpertSuggestions: [ResponderExpert] = []
    var currentExpertSuggestions: [ResponderExpert] = []
    var lastPickedExpert: ResponderExpert?
    var isShowingInitialWelcomeState = false
    var transcriptSuggestionView: NSView?
    var transcriptLiveStatusView: NSView?
    var renderedConversationKey: String?
    var expertSuggestionsCollapsed = false
    var liveStatusAvatarTimer: Timer?
    var liveStatusAvatarPaths: [String] = []
    var liveStatusAvatarIndex = 0
    var streamingPresentationInterrupted = false
    var currentStreamingSpeakerName: String?
    var isPinnedOpen = false
    var isShowingDropTarget = false
    var isExpertMode = false
    var isReplayingTranscript = false
    var starterPackWelcomeBannerDismissed = false
    var currentWelcomeArchiveMode: AppSettings.ArchiveAccessMode?
    var currentWelcomeSuggestions: [(String, String, String)] = []
    var lastRenderedWelcomeSignature: String?
    var lastObservedWelcomePreviewMode = AppSettings.welcomePreviewMode
    var isShowingOfficialMCPSetupPanel = false
    var requiresInitialConnectionSetup = false
    var lastObservedFirstRunConfigurationSignature: String?
    var settingsObserver: NSObjectProtocol?
    let officialMCPURL = URL(string: "https://www.lennysdata.com")!

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    deinit {
        liveStatusAvatarTimer?.invalidate()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    var theme: PopoverTheme {
        var t = themeOverride ?? PopoverTheme.current
        if let color = characterColor {
            t = t.withCharacterColor(color)
        }
        t = t.withCustomFont()
        return t
    }

    override func layout() {
        super.layout()
        relayoutPanels()
    }

    func setReturnToLennyVisible(_ visible: Bool) {
        returnButton.isHidden = !visible
    }
}
