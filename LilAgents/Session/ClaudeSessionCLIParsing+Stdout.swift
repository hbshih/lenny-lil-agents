import Foundation

extension ClaudeSession {
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
           let result = claudeCLIStreamEvent(fromContent: content) {
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

    private func claudeCLIStreamEvent(fromMessage message: [String: Any]) -> (title: String, summary: String)? {
        let text = extractTextPayload(from: message)
        let type = ((message["type"] as? String) ?? "").lowercased()

        if type == "tool_use" || type == "tool_result" {
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
           let nested = claudeCLIStreamEvent(fromContent: content) {
            return nested
        }

        if let text, !text.isEmpty {
            let title = text.count > 42 ? String(text.prefix(42)) + "…" : text
            return (title, summarizedModelNarration(text))
        }

        return nil
    }

    private func claudeCLIStreamEvent(fromContent content: [[String: Any]]) -> (title: String, summary: String)? {
        let pieces = content.compactMap { extractTextPayload(from: $0) }.filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return nil }

        let summary = pieces.joined(separator: " ")
        let title = pieces.first ?? summary
        return (title.count > 42 ? String(title.prefix(42)) + "…" : title, summarizedModelNarration(summary))
    }

    private func claudeCLIToolDisplay(for rawToolName: String, arguments: [String: Any], fallbackText: String? = nil) -> (title: String, summary: String) {
        let tool = rawToolName.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
