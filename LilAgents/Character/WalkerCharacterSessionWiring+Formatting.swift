import AppKit

extension WalkerCharacter {
    func formatToolInput(_ input: [String: Any]) -> String {
        let preferredKeys = [
            "summary", "command", "query", "path", "file_path",
            "filename", "title", "name", "message", "text", "content", "prompt"
        ]

        for key in preferredKeys {
            if let value = readableStatusValue(input[key]) {
                return value
            }
        }

        return ""
    }

    func formatLiveStatus(toolName: String, summary: String) -> String {
        let lowered = toolName.lowercased()
        let detail = statusDetail(from: summary)
        if let joinStatus = liveExpertJoinStatus(from: summary) {
            return joinStatus
        }
        if lowered == "tool result" {
            if let detail, let rewritten = userFacingResearchStatus(from: detail) {
                return rewritten
            }
            return "Reviewing the relevant context"
        }

        if lowered.contains("planning") || lowered.contains("calling model") {
            if let planningStatus = userFacingPlanningStatus(from: detail ?? summary) {
                return planningStatus
            }
            return detail ?? "Getting things ready"
        }
        if lowered.contains("calling mcp tool") {
            if let detail, let rewritten = userFacingResearchStatus(from: detail) {
                return rewritten
            }
            return "Checking the archive"
        }
        if lowered.contains("search") || lowered.contains("reading") || lowered.contains("browse") {
            if let detail, let rewritten = userFacingResearchStatus(from: detail) {
                return rewritten
            }
            return lowered.contains("reading") ? "Reading source material" : "Searching the archive"
        }
        if lowered.contains("writing") || lowered.contains("generating") {
            if let detail, let rewritten = userFacingWritingStatus(from: detail) {
                return rewritten
            }
            return "Writing the answer"
        }
        if let rewritten = userFacingNarration(from: detail ?? summary) {
            return rewritten
        }
        if lowered.contains("tool") {
            return detail.map { "Using \($0)" } ?? "Using a research tool"
        }
        if lowered.contains("running") || lowered.contains("progress") || lowered.contains("thinking") {
            return detail ?? "Working through the request"
        }
        return detail ?? "Working through the request"
    }

    func compactLiveStatus(_ status: String) -> String {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        func compactPreview(_ text: String, limit: Int = 3) -> String {
            let normalized = text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return "" }

            let words = normalized.split(separator: " ").map(String.init)
            guard words.count > limit else { return normalized }
            return words.prefix(limit).joined(separator: " ") + "…"
        }

        if trimmed.hasPrefix("Calling MCP Tool:") {
            let toolPortion = trimmed.replacingOccurrences(of: "Calling MCP Tool: ", with: "")
            let toolName = toolPortion.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "MCP"
            return compactPreview("MCP \(toolName)")
        }

        if trimmed.hasPrefix("Calling Model:") {
            let modelPortion = trimmed.replacingOccurrences(of: "Calling Model: ", with: "")
            return compactPreview(String(modelPortion.prefix(32)))
        }

        if trimmed.hasPrefix("Calling "), let range = trimmed.range(of: " in ") {
            return compactPreview(String(trimmed[..<range.lowerBound]))
        }

        if trimmed.lowercased().hasPrefix("writing") {
            return "Writing"
        }

        if trimmed.lowercased().hasPrefix("loaded ") {
            return "Loaded"
        }

        return compactPreview(String(trimmed.prefix(32)))
    }

    func formatLiveResultStatus(_ summary: String, isError: Bool) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return isError ? "Something went wrong." : "" }

        if isError {
            return "Something went wrong."
        }

        return ""
    }

    private func readableStatusValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return sanitizedStatusString(string)
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            let items = array.compactMap { readableStatusValue($0) }
            return items.isEmpty ? nil : items.joined(separator: ", ")
        case let dict as [String: Any]:
            for key in ["summary", "name", "title", "text", "content", "prompt", "query", "command", "path", "file_path"] {
                if let nested = readableStatusValue(dict[key]), !nested.isEmpty {
                    return nested
                }
            }
            return nil
        default:
            return nil
        }
    }

    private func sanitizedStatusString(_ string: String) -> String? {
        let trimmed = string
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("{"), !trimmed.contains("}"), !trimmed.contains("["), !trimmed.contains("]") else { return nil }
        guard !trimmed.hasPrefix("```") else { return nil }
        guard !trimmed.contains("\\\""), !trimmed.contains("\\n") else { return nil }
        guard trimmed.range(of: #"toolu_[A-Za-z0-9]+"#, options: .regularExpression) == nil else { return nil }
        guard !looksLikeTranscriptExcerpt(trimmed) else { return nil }
        return trimmed.count > 120 ? String(trimmed.prefix(120)) : trimmed
    }

    private func statusDetail(from summary: String) -> String? {
        let cleaned = summary
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }
        guard let sanitized = sanitizedStatusString(cleaned) else {
            return extractStructuredStatusDetail(from: cleaned)
        }
        return polishedStatusDetail(sanitized)
    }

    private func extractStructuredStatusDetail(from summary: String) -> String? {
        if let filename = match(in: summary, pattern: #""filename"\s*:\s*"([^"]+)""#) {
            return polishedStatusDetail(filename)
        }
        if let title = match(in: summary, pattern: #""title"\s*:\s*"([^"]+)""#) {
            return polishedStatusDetail(title)
        }
        if let query = match(in: summary, pattern: #""query"\s*:\s*"([^"]+)""#) {
            return polishedStatusDetail(query)
        }
        if let source = match(in: summary, pattern: #"Source:\s*([^"]+)$"#) {
            return polishedStatusDetail(source)
        }
        if summary.contains("official Lenny MCP") {
            return "Official Lenny MCP"
        }
        if summary.range(of: #"toolu_[A-Za-z0-9]+"#, options: .regularExpression) != nil {
            return nil
        }
        if summary.localizedCaseInsensitiveContains("maximum allowed tokens") {
            return "a large source file"
        }
        return nil
    }

    private func polishedStatusDetail(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.contains("/") {
            let path = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
            return String(path.prefix(48))
        }

        return String(trimmed.prefix(64))
    }

    private func liveExpertJoinStatus(from summary: String) -> String? {
        guard let session = claudeSession,
              !summary.isEmpty else {
            return nil
        }

        let names = Array(session.expertNames(fromFreeformText: summary).prefix(2))
        guard let firstExpert = names.first else { return nil }

        let lowered = summary.lowercased()
        let cues = [
            "@",
            "join the conversation",
            "joining the conversation",
            "has joined",
            "is joining",
            "bring in",
            "loop in",
            "call on",
            "thoughts on this",
            "i've got",
            "i have enough from the archive",
            "based on what i've gathered from",
            "who've shared"
        ]

        guard cues.contains(where: { lowered.contains($0) }) else { return nil }
        if names.count >= 2 {
            return "\(names[0]) and \(names[1]) are joining the conversation"
        }
        return "\(firstExpert) is joining the conversation"
    }

    private func userFacingPlanningStatus(from summary: String) -> String? {
        let lowered = summary.lowercased()
        if lowered.contains("composing the final answer") {
            return "Writing the answer"
        }
        if lowered.contains("lenny mcp") || lowered.contains("official lenny mcp") {
            return "Connecting to the archive"
        }
        if lowered.contains("claude code") || lowered.contains("openai responses") || lowered.contains("codex") {
            return "Starting the background work"
        }
        return userFacingNarration(from: summary)
    }

    private func userFacingResearchStatus(from detail: String) -> String? {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if lowered.hasPrefix("searching ") || lowered.hasPrefix("reading ") || lowered.hasPrefix("checking ") {
            return trimmed
        }
        if lowered.contains("official lenny mcp") {
            return "Connecting to the archive"
        }
        if lowered.contains("archive lookup was cancelled") {
            return "The archive lookup was cancelled"
        }
        if lowered.contains("archive connection failed to start") {
            return "The archive connection failed to start"
        }
        if lowered.contains("archive token was not available") {
            return "The archive token was not available"
        }
        return userFacingNarration(from: trimmed)
    }

    private func userFacingWritingStatus(from detail: String) -> String? {
        let lowered = detail.lowercased()
        if lowered.contains("composing the final answer") || lowered.contains("construct the json response") {
            return "Writing the answer"
        }
        if let rewritten = userFacingNarration(from: detail) {
            return rewritten
        }
        return "Writing the answer"
    }

    private func userFacingNarration(from summary: String) -> String? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()

        if lowered.contains("construct the json response")
            || lowered.contains("compose the final answer")
            || lowered.contains("draft the answer") {
            return "Writing the answer"
        }

        if lowered.contains("i have enough from the archive now")
            || lowered.contains("based on what i've gathered from") {
            return "Pulling together the final answer"
        }

        if lowered.contains("permission to use bash has been denied") {
            return "That route isn't available here, trying another approach"
        }

        if lowered.contains("file is just one long line") {
            return "That file is hard to scan, trying a more targeted read"
        }

        if lowered.contains("read specific parts")
            || lowered.contains("search for specific content")
            || lowered.contains("capped at returning only") {
            return "Switching to a more targeted search"
        }

        if lowered.contains("have rich content")
            || lowered.contains("have enough context")
            || lowered.contains("key framework") {
            if let topic = trailingTopic(in: trimmed) {
                return "Pulling together the key points on \(topic)"
            }
            return "Pulling together the key points"
        }

        if lowered.contains("search") {
            if let topic = trailingTopic(in: trimmed) {
                return "Searching the archive for \(topic)"
            }
            return "Searching the archive"
        }

        if lowered.contains("read") || lowered.contains("review") {
            if let topic = trailingTopic(in: trimmed) {
                return "Reviewing the relevant context on \(topic)"
            }
            return "Reviewing the relevant context"
        }

        if lowered.contains("check") || lowered.contains("look for") || lowered.contains("find") {
            if let topic = trailingTopic(in: trimmed) {
                return "Looking into \(topic)"
            }
            return "Looking into the right source"
        }

        return nil
    }

    private func trailingTopic(in text: String) -> String? {
        let patterns = [
            #"\bfor\s+(.+?)[\.\!\?]?$"#,
            #"\babout\s+(.+?)[\.\!\?]?$"#,
            #"\bon\s+(.+?)[\.\!\?]?$"#
        ]

        for pattern in patterns {
            if let match = match(in: text, pattern: pattern) {
                let cleaned = match
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^(the|this)\s+"#, with: "", options: .regularExpression)
                if !cleaned.isEmpty {
                    return String(cleaned.prefix(56))
                }
            }
        }

        return nil
    }

    private func looksLikeTranscriptExcerpt(_ string: String) -> Bool {
        let lowered = string.lowercased()
        if lowered.hasPrefix("calling model:") {
            return true
        }
        if string.contains("):") && string.contains("**") {
            return true
        }
        let wordCount = string.split(separator: " ").count
        return wordCount > 14 && !string.contains(": ")
    }

    private func match(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, options: [], range: range),
              let captureRange = Range(result.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }
}
