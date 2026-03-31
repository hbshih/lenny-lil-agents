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

        if lowered.contains("planning") || lowered.contains("calling model") {
            if let detail, detail.lowercased() == "composing the final answer" {
                return "Composing the final answer"
            }
            return detail ?? "Reviewing notes"
        }
        if lowered.contains("calling mcp tool") {
            if let detail {
                if detail.lowercased().contains("official lenny mcp") {
                    return "Using Official Lenny MCP"
                }
                return "Using \(detail)"
            }
            return "Using a research tool"
        }
        if lowered.contains("search") || lowered.contains("reading") || lowered.contains("browse") {
            if let detail {
                let verb = lowered.contains("reading") ? "Reading" : "Searching"
                return "\(verb): \(detail)"
            }
            return lowered.contains("reading") ? "Reading source material" : "Searching the archive"
        }
        if lowered.contains("writing") || lowered.contains("generating") {
            if let detail {
                return "Writing: \(detail)"
            }
            return "Drafting the answer"
        }
        if lowered.contains("running") || lowered.contains("progress") || lowered.contains("thinking") {
            return detail ?? "Working through the request"
        }
        if lowered.contains("tool") {
            return detail.map { "Using \($0)" } ?? "Using a research tool"
        }
        return detail ?? "Working through the request"
    }

    func compactLiveStatus(_ status: String) -> String {
        let trimmed = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.hasPrefix("Calling MCP Tool:") {
            let toolPortion = trimmed.replacingOccurrences(of: "Calling MCP Tool: ", with: "")
            let toolName = toolPortion.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "MCP"
            return "MCP: \(toolName)"
        }

        if trimmed.hasPrefix("Calling Model:") {
            let modelPortion = trimmed.replacingOccurrences(of: "Calling Model: ", with: "")
            return String(modelPortion.prefix(32))
        }

        if trimmed.hasPrefix("Calling "), let range = trimmed.range(of: " in ") {
            return String(trimmed[..<range.lowerBound])
        }

        if trimmed.lowercased().hasPrefix("writing") {
            return "Writing"
        }

        if trimmed.lowercased().hasPrefix("loaded ") {
            return "Loaded"
        }

        return String(trimmed.prefix(32))
    }

    func formatLiveResultStatus(_ summary: String, isError: Bool) -> String {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return isError ? "Something went wrong." : "" }

        if isError {
            return "Something went wrong."
        }

        return "Done."
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
