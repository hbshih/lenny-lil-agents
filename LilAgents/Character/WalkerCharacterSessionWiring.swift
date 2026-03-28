import AppKit

extension WalkerCharacter {
    func wireSession(_ session: ClaudeSession) {
        session.onText = { [weak self] text in
            self?.terminalView?.appendStreamingText(text)
        }

        session.onTurnComplete = { [weak self] in
            guard let self else { return }
            let stagedExperts = self.terminalView?.deferredExpertSuggestions ?? []
            SessionDebugLogger.log("ui", "onTurnComplete fired. focusedExpert=\(self.focusedExpert?.name ?? "none") stagedExperts=\(stagedExperts.map(\.name).joined(separator: ", "))")
            self.currentActivityStatus = ""
            self.terminalView?.endStreaming()
            self.terminalView?.clearLiveStatus()
            self.playCompletionSound()
            self.showCompletionBubble()
            self.updateExpertNameTag()
            if self.focusedExpert == nil, !stagedExperts.isEmpty {
                let names = stagedExperts.map(\.name).joined(separator: ", ")
                self.terminalView?.setExpertSuggestions(stagedExperts)
                SessionDebugLogger.log("ui", "appended expert suggestion prompt to transcript: \(names)")
            } else {
                self.terminalView?.setExpertSuggestions([])
            }
            self.terminalView?.deferredExpertSuggestions = []
        }

        session.onError = { [weak self] text in
            self?.currentActivityStatus = ""
            self?.terminalView?.setLiveStatus(text, isBusy: false, isError: true)
            self?.terminalView?.appendError(text)
            self?.updateExpertNameTag()
        }

        session.onToolUse = { [weak self] toolName, input in
            guard let self else { return }
            let summary = self.formatToolInput(input)
            self.currentActivityStatus = toolName
            self.terminalView?.appendToolUse(toolName: toolName, summary: summary)
            self.updateExpertNameTag()
        }

        session.onToolResult = { [weak self] summary, isError in
            self?.terminalView?.appendToolResult(summary: summary, isError: isError)
            self?.updateExpertNameTag()
        }

        session.onProcessExit = { [weak self] in
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
        if let cmd = input["command"] as? String { return cmd }
        if let path = input["file_path"] as? String { return path }
        if let pattern = input["pattern"] as? String { return pattern }
        if let query = input["query"] as? String { return query }
        return input.keys.sorted().prefix(3).joined(separator: ", ")
    }

    func updatePopoverPosition() {
        guard let popover = popoverWindow, isIdleForPopover else { return }
        guard let screen = NSScreen.main else { return }

        let charFrame = window.frame
        let popoverSize = popover.frame.size
        var x = charFrame.midX - popoverSize.width / 2
        let y = charFrame.maxY - 10

        let screenFrame = screen.frame
        x = max(screenFrame.minX + 4, min(x, screenFrame.maxX - popoverSize.width - 4))
        let clampedY = min(y, screenFrame.maxY - popoverSize.height - 4)

        popover.setFrameOrigin(NSPoint(x: x, y: clampedY))
    }
}
