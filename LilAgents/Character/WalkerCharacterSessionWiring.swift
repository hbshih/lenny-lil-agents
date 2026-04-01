import AppKit

extension WalkerCharacter {
    func wireSession(_ session: ClaudeSession) {
        session.onText = { [weak self] text in
            guard let self, let tv = self.terminalView else { return }
            tv.currentAssistantText = text
        }

        session.onTurnComplete = { [weak self] in
            guard let self else { return }
            let stagedExperts = self.terminalView?.deferredExpertSuggestions ?? []
            SessionDebugLogger.log("ui", "onTurnComplete fired. focusedExpert=\(self.focusedExpert?.name ?? "none") stagedExperts=\(stagedExperts.map(\.name).joined(separator: ", "))")
            self.stopLiveStatusFallback()
            self.setCurrentActivityStatus("")
            self.terminalView?.endStreaming()
            self.terminalView?.clearLiveStatus()
            self.playCompletionSound()
            self.showCompletionBubble()
            self.updateExpertNameTag()
            if self.focusedExpert != nil {
                self.terminalView?.hideExpertSuggestions(clearState: false)
            } else if !stagedExperts.isEmpty,
                      let session = self.claudeSession {
                let alreadyRenderedExperts = session.history(for: nil).contains { $0.role == .assistant && $0.followUpExpert != nil }
                if !alreadyRenderedExperts {
                    let names = stagedExperts.map(\.name).joined(separator: ", ")
                    session.appendExpertSuggestionEntry(stagedExperts, for: nil)
                    SessionDebugLogger.log("ui", "appended expert suggestion prompt to transcript: \(names)")
                }
            }
            if let session = self.claudeSession {
                self.terminalView?.replayConversation(
                    session.history(for: self.focusedExpert),
                    expertSuggestions: session.expertSuggestionEntries(for: self.focusedExpert)
                )
                session.livePresenceExperts = []
            }
            self.terminalView?.deferredExpertSuggestions = []
        }

        session.onError = { [weak self] text in
            self?.stopLiveStatusFallback()
            self?.setCurrentActivityStatus("")
            self?.terminalView?.setLiveStatus(text, isBusy: false, isError: true)
            self?.terminalView?.appendError(text)
            self?.updateExpertNameTag()
        }

        session.onToolUse = { [weak self] toolName, input in
            guard let self else { return }
            let summary = self.formatToolInput(input)
            let explicitExperts = input["experts"] as? [ResponderExpert] ?? []
            let experts = self.mergedLiveExperts(explicitExperts, from: summary)
            let liveStatus = self.formatLiveStatus(toolName: toolName, summary: summary)
            self.noteLiveStatusEvent()
            self.setCurrentActivityStatus(liveStatus)
            self.terminalView?.setLiveStatus(liveStatus, isBusy: true, isError: false, experts: experts)
            self.updateExpertNameTag()

            if toolName.lowercased().contains("planning") {
                self.startLiveStatusFallback()
            }
        }

        session.onToolResult = { [weak self] summary, isError in
            if let self {
                self.noteLiveStatusEvent()
                let liveSummary = self.formatLiveResultStatus(summary, isError: isError)
                if !liveSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.setCurrentActivityStatus(liveSummary)
                } else {
                    SessionDebugLogger.log("avatar-status", "ignored empty tool result summary while busy")
                }
                if isError {
                    self.stopLiveStatusFallback()
                }
                let experts = self.mergedLiveExperts([], from: summary)
                self.terminalView?.appendToolResult(summary: summary, displaySummary: liveSummary, isError: isError, experts: experts)
                self.updateExpertNameTag()
                return
            }
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

    func setCurrentActivityStatus(_ status: String) {
        currentActivityStatus = status

        let compact = compactLiveStatus(status)
        if compact.isEmpty {
            SessionDebugLogger.trace("avatar-status", "cleared")
        } else {
            SessionDebugLogger.trace("avatar-status", "showing \(compact)")
        }
    }

    func noteLiveStatusEvent() {
        lastLiveStatusEventAt = Date()
    }

    func extractLiveExperts(from text: String) -> [ResponderExpert] {
        guard let session = claudeSession else { return [] }
        let fromText = detectedLiveExperts(from: text)
        if !fromText.isEmpty { return fromText }
        return session.livePresenceExperts
    }

    func detectedLiveExperts(from text: String) -> [ResponderExpert] {
        guard let session = claudeSession else { return [] }
        return session.expertsFromAssistantText(text)
    }

    func mergedLiveExperts(_ explicitExperts: [ResponderExpert], from text: String) -> [ResponderExpert] {
        let fromText = detectedLiveExperts(from: text)
        let existing = claudeSession?.livePresenceExperts ?? []

        var merged: [ResponderExpert] = []
        for expert in existing + explicitExperts + fromText where !merged.contains(where: { $0.name == expert.name }) {
            merged.append(expert)
        }

        if !merged.isEmpty {
            claudeSession?.livePresenceExperts = Array(merged.prefix(3))
        }

        return Array(merged.prefix(3))
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

        let genericStatuses = Set([
            "on it…",
            "searching archive",
            "reading",
            "writing answer"
        ])
        let normalizedCurrent = currentActivityStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalizedCurrent.isEmpty, !genericStatuses.contains(normalizedCurrent) {
            terminalView?.setLiveStatus(currentActivityStatus, isBusy: true, isError: false, experts: claudeSession?.livePresenceExperts ?? [])
            updateExpertNameTag()
            lastLiveStatusEventAt = Date()
            return
        }

        let fallbackStatuses = [
            "On it…",
            "Searching archive",
            "Reading",
            "Writing answer"
        ]

        let index = min(liveStatusFallbackIndex, fallbackStatuses.count - 1)
        let nextStatus = fallbackStatuses[index]
        setCurrentActivityStatus(nextStatus)
        terminalView?.setLiveStatus(nextStatus, isBusy: true, isError: false, experts: claudeSession?.livePresenceExperts ?? [])
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
