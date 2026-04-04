import Foundation

// Tool display and result status helpers for Claude and Codex CLI events.
// These methods have access to the shared text utilities defined in ClaudeSessionCLIParsing+Stdout.swift.

extension ClaudeSession {

    // MARK: - Codex item stream events

    func codexCLIStreamEvent(fromItem item: [String: Any]) -> (title: String, summary: String)? {
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

    // MARK: - Tool use / result display

    func claudeCLIToolUseDisplay(from block: [String: Any]) -> (title: String, summary: String)? {
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

    func claudeCLIToolResultDisplay(from block: [String: Any]) -> (title: String, summary: String)? {
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

    func claudeCLIToolDisplay(for rawToolName: String, arguments: [String: Any], fallbackText: String? = nil) -> (title: String, summary: String) {
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

    // MARK: - Process result helpers

    func processResultStatus(for toolName: String, arguments: [String: Any], output: Any?) -> String {
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

    // MARK: - Tool result parsing helpers

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
