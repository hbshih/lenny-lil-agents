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
    let returnButton = NSButton(title: "Back to Lenny", target: nil, action: nil)
    var onSendMessage: ((String, [SessionAttachment]) -> Void)?
    var onReturnToLenny: (() -> Void)?
    var onSelectExpert: ((ResponderExpert) -> Void)?
    var onSelectExpertSuggestion: ((UUID, ResponderExpert) -> Void)?
    var onEditExpertSuggestion: ((UUID) -> Void)?
    var onTogglePinned: (() -> Void)?
    var onCloseRequested: (() -> Void)?
    var onRequestWorkspaceAccess: (() -> Void)?

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
    var transcriptSuggestionView: NSView?
    var expertSuggestionsCollapsed = false
    var liveStatusAvatarTimer: Timer?
    var liveStatusAvatarPaths: [String] = []
    var liveStatusAvatarIndex = 0
    var isPinnedOpen = false
    var isShowingDropTarget = false

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
