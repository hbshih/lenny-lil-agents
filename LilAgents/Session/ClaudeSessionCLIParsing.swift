import Foundation

extension ClaudeSession {
    func finishCLIResponse(_ outputText: String, conversationKey: String) {
        let response = prepareAssistantResponse(outputText)
        publishPendingExperts(fallbackText: response.displayText)
        SessionDebugLogger.logMultiline("assistant", header: "finishCLIResponse()", body: response.displayText)
        let composeSummary = "Composing the final answer"
        onToolUse?("Writing", ["summary": composeSummary])
        appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
        response.messages.forEach { appendHistory($0, to: conversationKey) }
        onText?(response.displayText)
        finishTurn()
    }

    func prepareAssistantResponse(_ outputText: String) -> (messages: [Message], displayText: String) {
        if let payload = parseStructuredAssistantResponse(from: outputText) {
            assistantExplicitlyRequestedExperts = payload.suggestExpertPrompt
            pendingExperts = payload.suggestedExperts

            if payload.suggestExpertPrompt {
                let names = pendingExperts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) JSON expert candidate(s) from assistant output: \(names)")
            } else {
                SessionDebugLogger.log("experts", "assistant explicitly declined expert suggestions")
            }

            return (assistantMessages(from: payload.segments), payload.segments.map(\.markdown).joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let structuredNames = structuredExpertSuggestionNames(from: outputText)
        if !structuredNames.isEmpty {
            let structuredExperts = structuredNames.compactMap { name -> ResponderExpert? in
                guard let avatarPath = avatarPath(for: name) else { return nil }
                let context = "Explicitly suggested by the assistant in the latest answer."
                return ResponderExpert(
                    name: name,
                    avatarPath: avatarPath,
                    archiveContext: context,
                    responseScript: responseScript(for: name, context: context)
                )
            }

            assistantExplicitlyRequestedExperts = !structuredExperts.isEmpty
            pendingExperts = Array(structuredExperts.prefix(3))
            let names = pendingExperts.map(\.name).joined(separator: ", ")
            SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) structured expert candidate(s) from assistant output: \(names)")
        }

        let cleaned = cleanedAssistantText(outputText)
        let fallbackMessage = Message(role: .assistant, text: cleaned, speaker: lennySpeaker(), followUpExpert: nil)
        return ([fallbackMessage], cleaned)
    }

    func parseStructuredAssistantResponse(from outputText: String) -> (segments: [AssistantSegment], suggestedExperts: [ResponderExpert], suggestExpertPrompt: Bool)? {
        if let json = decodeStructuredAssistantJSONObject(from: outputText) {
            if let payload = structuredResponse(from: json) {
                let names = payload.suggestedExperts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.log("assistant", "parsed structured JSON assistant payload. suggestedExperts=\(names) prompt=\(payload.suggestExpertPrompt)")
                return payload
            }
        }

        guard let answerMarkdown = extractStructuredJSONStringValue(forKey: "answer_markdown", from: outputText) else { return nil }
        let suggestedExperts = extractStructuredStringArray(forKey: "suggested_experts", from: outputText)
            .compactMap { expertSuggestion(named: $0) }
        let suggestExpertPrompt = extractStructuredBoolean(forKey: "suggest_expert_prompt", from: outputText) ?? !suggestedExperts.isEmpty
        let segments = [AssistantSegment(speaker: lennySpeaker(), markdown: answerMarkdown, followUpExpert: nil)]
        return (segments, Array(suggestedExperts.prefix(3)), suggestExpertPrompt)
    }
}
