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

    private func codexCLIStreamEvent(fromItem item: [String: Any]) -> (title: String, summary: String)? {
        let itemType = ((item["type"] as? String)
            ?? (item["kind"] as? String)
            ?? (item["item_type"] as? String)
            ?? "").lowercased()

        if itemType.contains("mcp") || itemType.contains("tool") {
            let toolName = (item["tool_name"] as? String)
                ?? (item["name"] as? String)
                ?? (item["tool"] as? String)
                ?? ((item["tool"] as? [String: Any])?["name"] as? String)
                ?? "tool"
            let arguments = (item["arguments"] as? [String: Any])
                ?? (item["input"] as? [String: Any])
                ?? ((item["tool"] as? [String: Any])?["arguments"] as? [String: Any])
                ?? [:]
            let status = (item["status"] as? String)?.lowercased()
            let errorMessage = ((item["error"] as? [String: Any])?["message"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let normalizedTool = normalizedTransportToolName(toolName)
            if status == "failed", let errorMessage, !errorMessage.isEmpty {
                return ("Tool Result", toolFailureStatus(for: normalizedTool, errorMessage: errorMessage))
            }

            if Constants.lennyAllowedTools.contains(normalizedTool) {
                return processDisplay(for: normalizedTool, arguments: arguments)
            }

            return claudeCLIToolDisplay(for: toolName, arguments: arguments, fallbackText: extractTextPayload(from: item))
        }

        if itemType.contains("web") && itemType.contains("search") {
            return ("Web Search", "Searching the web")
        }

        if itemType.contains("reasoning") || itemType.contains("thought") {
            if let text = extractTextPayload(from: item), !text.isEmpty {
                return ("Reasoning", summarizedModelNarration(text))
            }
            return ("Reasoning", "Thinking through the answer")
        }

        if itemType.contains("plan") {
            if let text = extractTextPayload(from: item), !text.isEmpty {
                return ("Planning", summarizedModelNarration(text))
            }
            return ("Planning", "Planning the next step")
        }

        if itemType.contains("command") || itemType.contains("shell") || itemType.contains("exec") {
            if let command = (item["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty {
                return ("Bash", "Trying \(String(command.prefix(80)))")
            }
            return ("Bash", "Trying a local command")
        }

        if itemType.contains("message") || itemType.contains("assistant") || itemType.contains("output") {
            if let text = extractTextPayload(from: item), !text.isEmpty {
                return ("Calling Model", summarizedModelNarration(text))
            }
        }

        if let text = extractTextPayload(from: item), !text.isEmpty {
            return ("Calling Model", summarizedModelNarration(text))
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

    private func claudeCLIToolUseDisplay(from block: [String: Any]) -> (title: String, summary: String)? {
        let toolName = (block["name"] as? String)
            ?? (block["tool_name"] as? String)
            ?? "tool"
        let arguments = (block["input"] as? [String: Any])
            ?? (block["arguments"] as? [String: Any])
            ?? [:]
        if let id = block["id"] as? String, !id.isEmpty {
            liveToolCallsByID[id] = (toolName, arguments)
        }
        return claudeCLIToolDisplay(for: toolName, arguments: arguments)
    }

    private func claudeCLIToolResultDisplay(from block: [String: Any]) -> (title: String, summary: String)? {
        guard let toolUseID = block["tool_use_id"] as? String,
              let toolCall = liveToolCallsByID[toolUseID] else {
            return nil
        }

        let toolName = toolCall.name
        let arguments = toolCall.arguments
        let content = block["content"]
        let contentText = extractTextPayload(from: content) ?? ""

        if let permissionStatus = permissionDeniedStatus(from: contentText) {
            return ("Tool Result", permissionStatus)
        }

        let normalizedToolName = normalizedTransportToolName(toolName)
        if Constants.lennyAllowedTools.contains(normalizedToolName) {
            let output = decodedToolResultPayload(from: content)
            return ("Tool Result", processResultStatus(for: normalizedToolName, arguments: arguments, output: output))
        }

        switch normalizedToolName.lowercased() {
        case "grep":
            let pattern = (arguments["pattern"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pattern, !pattern.isEmpty {
                return ("Tool Result", "Found a matching section for \(pattern)")
            }
            return ("Tool Result", "Found a matching section")
        case "read":
            let path = readablePath(arguments["file_path"] as? String ?? arguments["path"] as? String)
            return ("Tool Result", "Loaded \(path)")
        default:
            return nil
        }
    }

    private func claudeCLIToolDisplay(for rawToolName: String, arguments: [String: Any], fallbackText: String? = nil) -> (title: String, summary: String) {
        let tool = rawToolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTool = normalizedTransportToolName(tool)

        if Constants.lennyAllowedTools.contains(normalizedTool) {
            return processDisplay(for: normalizedTool, arguments: arguments)
        }

        switch normalizedTool.lowercased() {
        case "grep":
            if let pattern = arguments["pattern"] as? String, !pattern.isEmpty {
                return ("Grep", "Looking for \(pattern)")
            }
        case "read":
            let path = readablePath(arguments["file_path"] as? String ?? arguments["path"] as? String)
            return ("Read", "Reading \(path)")
        case "glob":
            if let pattern = arguments["pattern"] as? String, !pattern.isEmpty {
                return ("Glob", "Looking through files matching \(pattern)")
            }
        case "bash":
            if let description = arguments["description"] as? String, !description.isEmpty {
                return ("Bash", description)
            }
            return ("Bash", "Trying a local command")
        default:
            break
        }

        let title = tool.isEmpty ? "tool" : tool
        let keys = arguments.keys.sorted()
        if let summary = arguments["summary"] as? String, !summary.isEmpty {
            return (title, summary)
        }
        if let path = arguments["path"] as? String, !path.isEmpty {
            return (title, path)
        }
        if let query = arguments["query"] as? String, !query.isEmpty {
            return (title, query)
        }
        if let text = fallbackText, !text.isEmpty {
            return (title, summarizedModelNarration(text))
        }
        return (title, keys.prefix(3).joined(separator: ", "))
    }

    private func summarizedModelNarration(_ text: String) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 120 { return compact }
        return String(compact.prefix(117)) + "…"
    }

    private func extractTextPayload(from value: Any?) -> String? {
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

    private func normalizedTransportToolName(_ rawToolName: String) -> String {
        let mcpPrefix = "mcp__\(Constants.lennyMCPServerLabel)__"
        if rawToolName.hasPrefix(mcpPrefix) {
            return String(rawToolName.dropFirst(mcpPrefix.count))
        }
        return rawToolName
    }

    private func readablePath(_ rawPath: String?) -> String {
        guard let rawPath, !rawPath.isEmpty else { return "the file" }
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^toolu_[A-Za-z0-9]+$"#, options: .regularExpression) != nil {
            return "the file"
        }
        return URL(fileURLWithPath: rawPath).lastPathComponent
    }

    private func permissionDeniedStatus(from contentText: String) -> String? {
        let prefix = "Error: Permission to use "
        guard contentText.hasPrefix(prefix) else { return nil }
        let toolName = contentText
            .replacingOccurrences(of: prefix, with: "")
            .components(separatedBy: " has been denied")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let toolName, !toolName.isEmpty {
            return "\(toolName) access isn't available here, trying another route"
        }
        return "That route isn't available here, trying another approach"
    }

    private func decodedToolResultPayload(from content: Any?) -> Any? {
        guard let contentText = extractTextPayload(from: content), !contentText.isEmpty else {
            return content
        }

        if let data = contentText.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let resultText = json["result"] as? String,
               let resultData = resultText.data(using: .utf8),
               let nested = try? JSONSerialization.jsonObject(with: resultData) {
                return nested
            }
            return json
        }

        return contentText
    }

    private func processResultStatus(for toolName: String, arguments: [String: Any], output: Any?) -> String {
        if toolName == "search_content",
           let envelope = output as? [String: Any] {
            let total = (envelope["total_results"] as? NSNumber)?.intValue ?? 0
            let query = (envelope["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "the topic"
            if total == 0 {
                return "No direct matches for \(query), trying a broader search"
            }
            if total == 1 {
                return "Found 1 relevant match for \(query)"
            }
            return "Found \(total) relevant matches for \(query)"
        }

        if toolName == "read_excerpt" || toolName == "read_content",
           let status = excerptStatus(from: output) {
            return status
        }

        return processResultDisplay(for: toolName, arguments: arguments, output: output)
    }

    private func excerptStatus(from output: Any?) -> String? {
        let experts = expertsFromMCPPayloads(arguments: [:], output: output).map(\.name)
        if let first = experts.first {
            return "Reviewing \(first)'s advice"
        }

        guard let payload = output as? [String: Any] else { return nil }
        if let title = payload["title"] as? String, !title.isEmpty {
            return "Reviewing \(title)"
        }
        if let filename = payload["filename"] as? String, !filename.isEmpty {
            return "Reviewing \(readableSourceName(from: filename))"
        }
        return nil
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
