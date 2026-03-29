import Foundation

extension ClaudeSession {
    func finishCLIResponse(_ outputText: String, conversationKey: String) {
        let cleanedOutput = prepareAssistantOutput(outputText)
        publishPendingExperts(fallbackText: cleanedOutput)
        SessionDebugLogger.logMultiline("assistant", header: "finishCLIResponse()", body: cleanedOutput)
        let composeSummary = "Composing the final answer"
        onToolUse?("Writing", ["summary": composeSummary])
        appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
        appendHistory(Message(role: .assistant, text: cleanedOutput), to: conversationKey)
        onText?(cleanedOutput)
        finishTurn()
    }

    func prepareAssistantOutput(_ outputText: String) -> String {
        if let payload = parseStructuredAssistantPayload(from: outputText) {
            if pendingExperts.isEmpty, payload.suggestExpertPrompt {
                let structuredExperts = payload.suggestedExperts.compactMap { name -> ResponderExpert? in
                    guard let avatarPath = avatarPath(for: name) else { return nil }
                    let context = "Explicitly suggested by the assistant in the latest answer."
                    return ResponderExpert(
                        name: name,
                        avatarPath: avatarPath,
                        archiveContext: context,
                        responseScript: responseScript(for: name, context: context)
                    )
                }

                if !structuredExperts.isEmpty {
                    pendingExperts = Array(structuredExperts.prefix(3))
                    let names = pendingExperts.map(\.name).joined(separator: ", ")
                    SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) JSON expert candidate(s) from assistant output: \(names)")
                }
            }

            return payload.answerMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let structuredNames = structuredExpertSuggestionNames(from: outputText)
        if pendingExperts.isEmpty, !structuredNames.isEmpty {
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

            if !structuredExperts.isEmpty {
                pendingExperts = Array(structuredExperts.prefix(3))
                let names = pendingExperts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.log("experts", "parsed \(pendingExperts.count) structured expert candidate(s) from assistant output: \(names)")
            }
        }

        return cleanedAssistantText(outputText)
    }

    func parseStructuredAssistantPayload(from outputText: String) -> (answerMarkdown: String, suggestedExperts: [String], suggestExpertPrompt: Bool)? {
        if let json = decodeStructuredAssistantJSONObject(from: outputText),
           let answerMarkdown = json["answer_markdown"] as? String {
            let suggestedExperts = (json["suggested_experts"] as? [String] ?? [])
                .compactMap { canonicalExpertName(for: $0) }
            let suggestExpertPrompt = json["suggest_expert_prompt"] as? Bool ?? !suggestedExperts.isEmpty

            SessionDebugLogger.log("assistant", "parsed structured JSON assistant payload. suggestedExperts=\(suggestedExperts.joined(separator: ", ")) prompt=\(suggestExpertPrompt)")
            return (answerMarkdown, suggestedExperts, suggestExpertPrompt)
        }

        guard let answerMarkdown = extractStructuredJSONStringValue(forKey: "answer_markdown", from: outputText) else {
            return nil
        }

        let suggestedExperts = extractStructuredStringArray(forKey: "suggested_experts", from: outputText)
            .compactMap { canonicalExpertName(for: $0) }
        let suggestExpertPrompt = extractStructuredBoolean(forKey: "suggest_expert_prompt", from: outputText) ?? !suggestedExperts.isEmpty

        SessionDebugLogger.log("assistant", "parsed fallback structured assistant payload. suggestedExperts=\(suggestedExperts.joined(separator: ", ")) prompt=\(suggestExpertPrompt)")
        return (answerMarkdown, suggestedExperts, suggestExpertPrompt)
    }

    func decodeStructuredAssistantJSONObject(from outputText: String) -> [String: Any]? {
        let normalized = outputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let direct = decodeStructuredAssistantJSONObjectCandidate(normalized) {
            return direct
        }

        if let jsonCandidate = extractStructuredJSONCandidate(from: normalized),
           let decoded = decodeStructuredAssistantJSONObjectCandidate(jsonCandidate) {
            return decoded
        }

        return nil
    }

    private func decodeStructuredAssistantJSONObjectCandidate(_ candidate: String) -> [String: Any]? {
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let json = object as? [String: Any], json["answer_markdown"] is String {
            return json
        }

        if let wrapped = object as? String {
            let trimmed = wrapped.trimmingCharacters(in: .whitespacesAndNewlines)
            if let nested = decodeStructuredAssistantJSONObjectCandidate(trimmed) {
                return nested
            }
            if let nestedCandidate = extractStructuredJSONCandidate(from: trimmed) {
                return decodeStructuredAssistantJSONObjectCandidate(nestedCandidate)
            }
        }

        return nil
    }

    func extractStructuredJSONCandidate(from outputText: String) -> String? {
        let trimmed = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.hasPrefix("{"), normalized.hasSuffix("}") {
            return normalized
        }

        let characters = Array(normalized)
        for startIndex in characters.indices where characters[startIndex] == "{" {
            var depth = 0
            var inString = false
            var escaping = false

            for index in startIndex..<characters.count {
                let character = characters[index]

                if inString {
                    if escaping {
                        escaping = false
                    } else if character == "\\" {
                        escaping = true
                    } else if character == "\"" {
                        inString = false
                    }
                    continue
                }

                if character == "\"" {
                    inString = true
                    continue
                }

                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let candidate = String(characters[startIndex...index])
                        if candidate.contains("\"answer_markdown\"") {
                            return candidate
                        }
                        break
                    }
                }
            }
        }

        return nil
    }

    func extractClaudeCLIResult(from stdout: String) -> String? {
        var assistantFallback: String?
        let lines = stdout.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if json["type"] as? String == "result" {
                if let direct = json["result"] as? String, !direct.isEmpty {
                    return direct
                }
                if let nested = json["result"],
                   let extracted = extractTextPayload(from: nested),
                   !extracted.isEmpty {
                    return extracted
                }
            }

            if assistantFallback == nil,
               let extracted = extractTextPayload(from: json),
               !extracted.isEmpty,
               !extracted.contains("\"type\":\"result\"") {
                assistantFallback = extracted
            }
        }

        if let data = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["type"] as? String == "result" {
            if let direct = json["result"] as? String, !direct.isEmpty {
                return direct
            }
            if let nested = json["result"] {
                return extractTextPayload(from: nested)
            }
        }

        return assistantFallback
    }

    func logClaudeCLIResultMetadata(from stdout: String) {
        let lines = stdout.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "result" else { continue }
            let numTurns = json["num_turns"] as? Int ?? 0
            let duration = json["duration_ms"] as? Int ?? 0
            SessionDebugLogger.log("claude-cli", "Claude Code metadata num_turns=\(numTurns) duration_ms=\(duration)")
            return
        }
    }

    func claudeCLIStreamEvent(from json: [String: Any]) -> (title: String, summary: String)? {
        if let type = json["type"] as? String {
            switch type {
            case "tool_use":
                let toolName = json["tool"] as? String ?? json["name"] as? String ?? "Tool"
                let arguments = json["input"] as? [String: Any] ?? json["arguments"] as? [String: Any] ?? [:]
                return claudeCLIToolDisplay(for: toolName, arguments: arguments)
            case "progress":
                let message = extractTextPayload(from: json["message"]) ?? "Processing"
                return ("Progress", message)
            case "result", "init", "system", "user":
                return nil
            default:
                break
            }
        }

        if let message = json["message"] as? [String: Any] {
            if let event = claudeCLIStreamEvent(fromMessage: message) {
                return event
            }
        }

        if let content = json["content"] as? [[String: Any]] {
            if let event = claudeCLIStreamEvent(fromContent: content) {
                return event
            }
        }

        if let summary = extractTextPayload(from: json["message"]),
           !summary.isEmpty,
           !summary.contains("\"answer_markdown\"") {
            return ("Calling Model", summary)
        }

        return nil
    }

    private func claudeCLIStreamEvent(fromMessage message: [String: Any]) -> (title: String, summary: String)? {
        if let content = message["content"] as? [[String: Any]],
           let event = claudeCLIStreamEvent(fromContent: content) {
            return event
        }

        if let text = extractTextPayload(from: message),
           !text.isEmpty,
           !text.contains("\"answer_markdown\"") {
            return ("Calling Model", text)
        }

        return nil
    }

    private func claudeCLIStreamEvent(fromContent content: [[String: Any]]) -> (title: String, summary: String)? {
        for block in content {
            let blockType = (block["type"] as? String ?? "").lowercased()
            switch blockType {
            case "tool_use":
                let toolName = block["name"] as? String ?? block["tool"] as? String ?? "Tool"
                let arguments = block["input"] as? [String: Any] ?? block["arguments"] as? [String: Any] ?? [:]
                return claudeCLIToolDisplay(for: toolName, arguments: arguments)
            case "thinking":
                if let text = extractTextPayload(from: block["thinking"]) ?? extractTextPayload(from: block["text"]),
                   !text.isEmpty {
                    return ("Thinking", text)
                }
            case "text", "output_text":
                if let text = extractTextPayload(from: block["text"]),
                   !text.isEmpty,
                   !text.contains("\"answer_markdown\"") {
                    return ("Calling Model", text)
                }
            default:
                continue
            }
        }

        return nil
    }

    private func claudeCLIToolDisplay(for rawToolName: String, arguments: [String: Any]) -> (title: String, summary: String) {
        let trimmedToolName = rawToolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverPrefix = "mcp__\(Constants.lennyMCPServerLabel)__"
        if trimmedToolName.hasPrefix(serverPrefix) {
            let name = String(trimmedToolName.dropFirst(serverPrefix.count))
            return processDisplay(for: name, arguments: arguments)
        }

        if trimmedToolName.hasPrefix("mcp__"),
           let fallbackName = trimmedToolName.components(separatedBy: "__").last,
           !fallbackName.isEmpty {
            return ("Calling MCP Tool", "\(fallbackName): \(summarizeArguments(arguments))")
        }

        return ("Calling Tool", arguments.isEmpty ? trimmedToolName : "\(trimmedToolName): \(summarizeArguments(arguments))")
    }

    private func extractTextPayload(from value: Any?) -> String? {
        switch value {
        case let text as String:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed

        case let dictionary as [String: Any]:
            if let text = dictionary["text"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }

            if let message = dictionary["message"] {
                return extractTextPayload(from: message)
            }

            if let result = dictionary["result"] {
                return extractTextPayload(from: result)
            }

            if let content = dictionary["content"] as? [[String: Any]] {
                let parts = content.compactMap { block -> String? in
                    let blockType = (block["type"] as? String ?? "").lowercased()
                    switch blockType {
                    case "text", "output_text":
                        return extractTextPayload(from: block["text"])
                    default:
                        return nil
                    }
                }
                let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return joined.isEmpty ? nil : joined
            }

            return nil

        case let array as [[String: Any]]:
            let joined = array.compactMap { extractTextPayload(from: $0) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined

        case let array as [Any]:
            let joined = array.compactMap { extractTextPayload(from: $0) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined

        default:
            return nil
        }
    }

    private func extractStructuredJSONStringValue(forKey key: String, from outputText: String) -> String? {
        let pattern = #""\#(key)"\s*:\s*"((?:\\.|[^"\\])*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: outputText, range: NSRange(outputText.startIndex..., in: outputText)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: outputText) else {
            return nil
        }

        let raw = String(outputText[range])
        let wrapped = "\"\(raw)\""
        guard let data = wrapped.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? String else {
            return nil
        }
        return decoded
    }

    private func extractStructuredStringArray(forKey key: String, from outputText: String) -> [String] {
        let pattern = #""\#(key)"\s*:\s*(\[[\s\S]*?\])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: outputText, range: NSRange(outputText.startIndex..., in: outputText)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: outputText) else {
            return []
        }

        let raw = String(outputText[range])
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return decoded
    }

    private func extractStructuredBoolean(forKey key: String, from outputText: String) -> Bool? {
        let pattern = #""\#(key)"\s*:\s*(true|false)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: outputText, range: NSRange(outputText.startIndex..., in: outputText)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: outputText) else {
            return nil
        }

        return String(outputText[range]) == "true"
    }

    func normalizeCLIError(stdout: String, stderr: String, fallback: String) -> String {
        // Prefer stderr for error messages; stdout often contains raw session dumps
        let stderrTrimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdoutTrimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        let candidate: String
        if !stderrTrimmed.isEmpty {
            candidate = stderrTrimmed
        } else if !stdoutTrimmed.isEmpty {
            candidate = stdoutTrimmed
        } else {
            return fallback
        }

        // If the output looks like leaked prompt/session scaffolding, discard it
        let promptMarkers = [
            "System instructions:",
            "You are answering inside a macOS companion app",
            "Return only valid JSON",
            "answer_markdown",
            "suggested_experts",
            "Conversation so far:",
            "Latest user message:"
        ]
        let looksLikePromptDump = promptMarkers.contains { candidate.contains($0) }
        if looksLikePromptDump {
            SessionDebugLogger.log("cli-error", "suppressed raw prompt/session dump from error output (\(candidate.count) chars)")
            return fallback
        }

        // Cap the length so the transcript stays readable
        let maxLength = 500
        let cleaned = cleanedAssistantText(candidate)
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength)) + "…"
        }
        return cleaned
    }
}
