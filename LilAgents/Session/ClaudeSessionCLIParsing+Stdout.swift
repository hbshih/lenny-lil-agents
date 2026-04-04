import Foundation

extension ClaudeSession {
    func extractCodexCLIResult(from stdout: String) -> String? {
        var assistantFallback: String?
        let lines = stdout.components(separatedBy: .newlines)

        for line in lines.reversed() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let item = codexItemPayload(from: json),
               let itemType = (item["type"] as? String)?.lowercased(),
               (itemType.contains("message") || itemType.contains("assistant")),
               let extracted = extractTextPayload(from: item),
               !extracted.isEmpty {
                return extracted
            }

            if assistantFallback == nil,
               let extracted = extractTextPayload(from: json),
               !extracted.isEmpty,
               !extracted.contains("\"type\":\"turn.") {
                assistantFallback = extracted
            }
        }

        return assistantFallback
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
        return assistantFallback
    }

    func logClaudeCLIResultMetadata(from stdout: String) {
        guard let result = extractClaudeCLIResult(from: stdout) else { return }
        let characters = result.count
        SessionDebugLogger.log("cli", "parsed CLI result payload (\(characters) chars)")
    }

    func claudeCLIStreamEvent(from json: [String: Any]) -> (title: String, summary: String)? {
        if let message = json["message"] as? [String: Any],
           let result = claudeCLIStreamEvent(fromMessage: message) {
            return result
        }

        if let content = json["content"] as? [[String: Any]],
           let result = claudeCLIStreamEvent(fromContent: content, messageRole: json["role"] as? String) {
            return result
        }

        if let toolName = json["tool_name"] as? String,
           let arguments = json["arguments"] as? [String: Any] {
            return claudeCLIToolDisplay(for: toolName, arguments: arguments)
        }

        if let title = json["title"] as? String {
            let summary = json["summary"] as? String ?? title
            return (title, summary)
        }

        return nil
    }

    func codexCLIStreamEvent(from json: [String: Any]) -> (title: String, summary: String)? {
        let eventType = (json["type"] as? String ?? "").lowercased()

        switch eventType {
        case "thread.started", "turn.started":
            return ("Planning", "Starting the background work")
        case "turn.completed":
            return ("Writing", "Writing the answer")
        case "error":
            if let text = extractTextPayload(from: json), !text.isEmpty {
                return ("Tool Result", text)
            }
            return ("Tool Result", "Something went wrong.")
        default:
            break
        }

        if let item = codexItemPayload(from: json),
           let display = codexCLIStreamEvent(fromItem: item) {
            return display
        }

        if let text = extractTextPayload(from: json), !text.isEmpty {
            return ("Calling Model", summarizedModelNarration(text))
        }

        return nil
    }

    func shouldIgnoreCodexTransportLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        if lowered.hasPrefix("warning: proceeding, even though we could not update path") {
            return true
        }
        if lowered.hasPrefix("reading additional input from stdin") {
            return true
        }
        if lowered.hasPrefix("thread '") || lowered.contains("panicked at ") {
            return true
        }
        if lowered.contains("attempted to create a null object") || lowered.contains("could not create otel exporter") {
            return true
        }
        return false
    }

    private func claudeCLIStreamEvent(fromMessage message: [String: Any]) -> (title: String, summary: String)? {
        let text = extractTextPayload(from: message)
        let type = ((message["type"] as? String) ?? "").lowercased()
        let role = (message["role"] as? String)?.lowercased()

        if type == "tool_result" {
            return nil
        }

        if type == "tool_use" {
            let toolName = (message["name"] as? String)
                ?? (message["tool_name"] as? String)
                ?? "tool"
            let arguments = (message["input"] as? [String: Any])
                ?? (message["arguments"] as? [String: Any])
                ?? (message["payload"] as? [String: Any])
                ?? [:]
            return claudeCLIToolDisplay(for: toolName, arguments: arguments, fallbackText: text)
        }

        if let content = message["content"] as? [[String: Any]],
           let nested = claudeCLIStreamEvent(fromContent: content, messageRole: role) {
            return nested
        }

        if let text, !text.isEmpty {
            let title = text.count > 42 ? String(text.prefix(42)) + "…" : text
            return (title, summarizedModelNarration(text))
        }

        return nil
    }

    private func codexItemPayload(from json: [String: Any]) -> [String: Any]? {
        if let item = json["item"] as? [String: Any] {
            return item
        }
        if let data = json["data"] as? [String: Any] {
            if let item = data["item"] as? [String: Any] {
                return item
            }
            return data
        }
        if let payload = json["payload"] as? [String: Any] {
            if let item = payload["item"] as? [String: Any] {
                return item
            }
            return payload
        }
        return nil
    }

    private func claudeCLIStreamEvent(fromContent content: [[String: Any]], messageRole: String?) -> (title: String, summary: String)? {
        for block in content {
            let type = ((block["type"] as? String) ?? "").lowercased()
            if type == "tool_use",
               let display = claudeCLIToolUseDisplay(from: block) {
                return display
            }
            if type == "tool_result",
               let display = claudeCLIToolResultDisplay(from: block) {
                return display
            }
        }

        let pieces = content.compactMap { extractTextPayload(from: $0) }.filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return nil }

        let summary = pieces.joined(separator: " ")
        let title = pieces.first ?? summary
        return (title.count > 42 ? String(title.prefix(42)) + "…" : title, summarizedModelNarration(summary))
    }
    func summarizedModelNarration(_ text: String) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 120 { return compact }
        return String(compact.prefix(117)) + "…"
    }

    func extractTextPayload(from value: Any?) -> String? {
        guard let value else { return nil }

        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let array = value as? [Any] {
            let parts = array.compactMap(extractTextPayload(from:))
            let joined = parts.joined(separator: "\n")
            return joined.isEmpty ? nil : joined
        }

        if let dict = value as? [String: Any] {
            if let text = dict["text"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let thinking = dict["thinking"] as? String {
                let trimmed = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let output = dict["output"] {
                return extractTextPayload(from: output)
            }
            if let content = dict["content"] {
                return extractTextPayload(from: content)
            }
            if let result = dict["result"] {
                return extractTextPayload(from: result)
            }
            if let message = dict["message"] {
                return extractTextPayload(from: message)
            }
            if let messages = dict["messages"] {
                return extractTextPayload(from: messages)
            }
        }

        return nil
    }

    func normalizedTransportToolName(_ rawToolName: String) -> String {
        let mcpPrefix = "mcp__\(Constants.lennyMCPServerLabel)__"
        if rawToolName.hasPrefix(mcpPrefix) {
            return String(rawToolName.dropFirst(mcpPrefix.count))
        }
        return rawToolName
    }

    func readablePath(_ rawPath: String?) -> String {
        guard let rawPath, !rawPath.isEmpty else { return "the file" }
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^toolu_[A-Za-z0-9]+$"#, options: .regularExpression) != nil {
            return "the file"
        }
        return URL(fileURLWithPath: rawPath).lastPathComponent
    }

    private func toolFailureStatus(for toolName: String, errorMessage: String) -> String {
        let lowered = errorMessage.lowercased()

        if lowered.contains("user cancelled mcp tool call") {
            if Constants.lennyAllowedTools.contains(toolName) {
                return "The archive lookup was cancelled before it finished"
            }
            return "That tool call was cancelled before it finished"
        }

        if lowered.contains("environment variable") && lowered.contains(Constants.lennyMCPAuthEnvVar.lowercased()) {
            return "The archive token was not available to the MCP server"
        }

        if lowered.contains("startup failed") {
            return "The archive connection failed to start"
        }

        return errorMessage
    }
}
