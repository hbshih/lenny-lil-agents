import Foundation

extension ClaudeSession {
    func extractStructuredJSONStringValue(forKey key: String, from outputText: String) -> String? {
        guard let candidate = extractStructuredJSONCandidate(from: outputText) else { return nil }

        let patterns = [
            "\"\(key)\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"",
            "\"\(key)\"\\s*:\\s*(\\{.*?\\}|\\[.*?\\])"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            guard let match = regex.firstMatch(in: candidate, range: range) else { continue }

            if match.numberOfRanges >= 2,
               let valueRange = Range(match.range(at: 1), in: candidate) {
                let raw = String(candidate[valueRange])
                if pattern.contains("\\\\.") {
                    return raw
                        .replacingOccurrences(of: #"\\\\"#, with: "\\")
                        .replacingOccurrences(of: #"\""#, with: "\"")
                }
                return raw
            }
        }

        return nil
    }

    func extractLooselyEncodedJSONStringValue(forKey key: String, from outputText: String) -> String? {
        guard let candidate = extractStructuredJSONCandidate(from: outputText) else { return nil }
        let patterns = [
            #""\#(key)"\s*:\s*"([^"]*)""#,
            #""\#(key)"\s*:\s*(\{.*\}|\[.*\])"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            guard let match = regex.firstMatch(in: candidate, range: range),
                  let valueRange = Range(match.range(at: 1), in: candidate) else { continue }
            return String(candidate[valueRange])
        }

        return nil
    }

    func extractStructuredStringArray(forKey key: String, from outputText: String) -> [String] {
        guard let candidate = extractStructuredJSONCandidate(from: outputText) else { return [] }
        let pattern = #""\#(key)"\s*:\s*\[(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: candidate, range: NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)),
              let range = Range(match.range(at: 1), in: candidate) else {
            return []
        }

        let body = String(candidate[range])
        return body.split(separator: ",").map {
            $0.trimmingCharacters(in: CharacterSet(charactersIn: " \n\r\t\"'"))
        }.filter { !$0.isEmpty }
    }

    func extractStructuredBoolean(forKey key: String, from outputText: String) -> Bool? {
        guard let candidate = extractStructuredJSONCandidate(from: outputText) else { return nil }
        let pattern = #""\#(key)"\s*:\s*(true|false)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: candidate, range: NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)),
              let range = Range(match.range(at: 1), in: candidate) else {
            return nil
        }
        return String(candidate[range]).lowercased() == "true"
    }

    func normalizeCLIError(stdout: String, stderr: String, fallback: String) -> String {
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

        let maxLength = 500
        let cleaned = cleanedAssistantText(candidate)
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength)) + "…"
        }
        return cleaned
    }
}
