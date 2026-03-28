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
        guard let jsonCandidate = extractStructuredJSONCandidate(from: outputText),
              let data = jsonCandidate.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answerMarkdown = json["answer_markdown"] as? String else {
            return nil
        }

        let suggestedExperts = (json["suggested_experts"] as? [String] ?? [])
            .compactMap { canonicalExpertName(for: $0) }
        let suggestExpertPrompt = json["suggest_expert_prompt"] as? Bool ?? !suggestedExperts.isEmpty

        SessionDebugLogger.log("assistant", "parsed structured JSON assistant payload. suggestedExperts=\(suggestedExperts.joined(separator: ", ")) prompt=\(suggestExpertPrompt)")
        return (answerMarkdown, suggestedExperts, suggestExpertPrompt)
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
        let lines = stdout.components(separatedBy: .newlines)
        for line in lines.reversed() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "result" else { continue }
            return json["result"] as? String
        }

        if let data = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["type"] as? String == "result" {
            return json["result"] as? String
        }

        return nil
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

