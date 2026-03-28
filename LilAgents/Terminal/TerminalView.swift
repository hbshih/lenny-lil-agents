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
    let attachmentLabel = NSTextField(labelWithString: "")
    let expertSuggestionContainer = NSView()
    let expertSuggestionLabel = NSTextField(labelWithString: "")
    let expertSuggestionStack = NSStackView()
    let attachButton = NSButton(title: "", target: nil, action: nil)
    let sendButton = NSButton(title: "", target: nil, action: nil)
    let returnButton = NSButton(title: "Return to Genie", target: nil, action: nil)
    var onSendMessage: ((String, [SessionAttachment]) -> Void)?
    var onReturnToLenny: (() -> Void)?
    var onSelectExpert: ((ResponderExpert) -> Void)?

    var characterColor: NSColor?
    var themeOverride: PopoverTheme?
    var currentAssistantText = ""
    var isStreaming = false
    var placeholderText = "Ask LennyTheGenie..."
    var pendingAttachments: [SessionAttachment] = []
    var expertSuggestionTargets: [String: ResponderExpert] = [:]
    var deferredExpertSuggestions: [ResponderExpert] = []
    var currentExpertSuggestions: [ResponderExpert] = []
    var expertSuggestionsCollapsed = false
    var liveStatusAvatarTimer: Timer?
    var liveStatusAvatarPaths: [String] = []
    var liveStatusAvatarIndex = 0

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
