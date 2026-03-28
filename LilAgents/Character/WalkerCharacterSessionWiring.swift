import AppKit

extension WalkerCharacter {
    func wireSession(_ session: ClaudeSession) {
        session.onText = { [weak self] text in
            guard let self, let tv = self.terminalView else { return }
            // Emit the speaker label before the very first chunk of a response
            if !tv.isStreaming {
                tv.isStreaming = true
                tv.currentAssistantText = ""
                let speakerName = self.focusedExpert?.name ?? tv.theme.titleString
                tv.beginAssistantTurn(name: speakerName)
            }
            tv.appendStreamingText(text)
        }

        session.onTurnComplete = { [weak self] in
            guard let self else { return }
            let stagedExperts = self.terminalView?.deferredExpertSuggestions ?? []
            SessionDebugLogger.log("ui", "onTurnComplete fired. focusedExpert=\(self.focusedExpert?.name ?? "none") stagedExperts=\(stagedExperts.map(\.name).joined(separator: ", "))")
            self.stopLiveStatusFallback()
            self.currentActivityStatus = ""
            self.terminalView?.endStreaming()
            self.terminalView?.clearLiveStatus()
            self.playCompletionSound()
            self.showCompletionBubble()
            self.updateExpertNameTag()
            if self.focusedExpert != nil {
                self.terminalView?.hideExpertSuggestions(clearState: false)
            } else if !stagedExperts.isEmpty {
                let names = stagedExperts.map(\.name).joined(separator: ", ")
                self.terminalView?.setExpertSuggestions(stagedExperts)
                SessionDebugLogger.log("ui", "appended expert suggestion prompt to transcript: \(names)")
            } else {
                self.terminalView?.setExpertSuggestions([])
            }
            self.terminalView?.deferredExpertSuggestions = []
        }

        session.onError = { [weak self] text in
            self?.stopLiveStatusFallback()
            self?.currentActivityStatus = ""
            self?.terminalView?.setLiveStatus(text, isBusy: false, isError: true)
            self?.terminalView?.appendError(text)
            self?.updateExpertNameTag()
        }

        session.onToolUse = { [weak self] toolName, input in
            guard let self else { return }
            let summary = self.formatToolInput(input)
            self.noteLiveStatusEvent()
            self.currentActivityStatus = self.formatLiveStatus(toolName: toolName, summary: summary)
            self.terminalView?.appendToolUse(toolName: toolName, summary: summary)
            self.updateExpertNameTag()

            if toolName.lowercased().contains("planning") {
                self.startLiveStatusFallback()
            }
        }

        session.onToolResult = { [weak self] summary, isError in
            if let self {
                self.noteLiveStatusEvent()
                self.currentActivityStatus = summary
                if isError {
                    self.stopLiveStatusFallback()
                }
            }
            self?.terminalView?.appendToolResult(summary: summary, isError: isError)
            self?.updateExpertNameTag()
        }

        session.onProcessExit = { [weak self] in
            self?.stopLiveStatusFallback()
            self?.terminalView?.endStreaming()
            self?.terminalView?.appendError("Archive session ended.")
        }

        session.onExpertsUpdated = { [weak self] experts in
            guard let self else { return }
            self.terminalView?.deferredExpertSuggestions = experts
            let names = experts.map(\.name).joined(separator: ", ")
            SessionDebugLogger.log("ui", "onExpertsUpdated received \(experts.count) expert(s): \(names)")
        }
    }

    func formatToolInput(_ input: [String: Any]) -> String {
        if let summary = input["summary"] as? String { return summary }
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        if let query = input["query"] as? String { return query }
        return input.keys.sorted().prefix(3).joined(separator: ", ")
    }

    func formatLiveStatus(toolName: String, summary: String) -> String {
        let lowered = toolName.lowercased()
        if lowered.contains("planning") {
            return "On it…"
        }
        if lowered.contains("search") || lowered.contains("reading") || lowered.contains("browse") {
            return "Searching archive"
        }
        if lowered.contains("writing") || lowered.contains("generating") {
            return "Writing answer"
        }
        if lowered.contains("running") || lowered.contains("progress") {
            return "Running"
        }
        return toolName
    }

    func noteLiveStatusEvent() {
        lastLiveStatusEventAt = Date()
    }

    func startLiveStatusFallback() {
        noteLiveStatusEvent()
        liveStatusFallbackIndex = 0

        guard liveStatusFallbackTimer == nil else { return }

        liveStatusFallbackTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.advanceLiveStatusFallbackIfNeeded()
        }

        if let timer = liveStatusFallbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopLiveStatusFallback() {
        liveStatusFallbackTimer?.invalidate()
        liveStatusFallbackTimer = nil
        lastLiveStatusEventAt = nil
        liveStatusFallbackIndex = 0
    }

    func advanceLiveStatusFallbackIfNeeded() {
        guard isClaudeBusy else {
            stopLiveStatusFallback()
            return
        }

        let lastEventAt = lastLiveStatusEventAt ?? Date()
        guard Date().timeIntervalSince(lastEventAt) >= 4.5 else { return }

        let fallbackStatuses = [
            "On it…",
            "Searching archive",
            "Reading",
            "Writing answer"
        ]

        let index = min(liveStatusFallbackIndex, fallbackStatuses.count - 1)
        let nextStatus = fallbackStatuses[index]
        currentActivityStatus = nextStatus
        terminalView?.setLiveStatus(nextStatus, isBusy: true, isError: false)
        updateExpertNameTag()

        if liveStatusFallbackIndex < fallbackStatuses.count - 1 {
            liveStatusFallbackIndex += 1
        }
        lastLiveStatusEventAt = Date()
    }
    func updatePopoverPosition() {
        guard let popover = popoverWindow, isIdleForPopover else { return }
        guard let screen = NSScreen.main else { return }

        let charFrame = window.frame
        let popoverSize = popover.frame.size
        var x = charFrame.midX - popoverSize.width / 2
        let y = charFrame.maxY - 10

        let visibleFrame = screen.visibleFrame
        x = max(visibleFrame.minX + 4, min(x, visibleFrame.maxX - popoverSize.width - 4))
        let clampedY = min(y, visibleFrame.maxY - popoverSize.height - 4)

        popover.setFrameOrigin(NSPoint(x: x, y: clampedY))
    }
}
