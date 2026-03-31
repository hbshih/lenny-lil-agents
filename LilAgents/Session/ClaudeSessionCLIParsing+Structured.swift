import Foundation

extension ClaudeSession {
    func structuredResponse(from json: [String: Any]) -> (segments: [AssistantSegment], suggestedExperts: [ResponderExpert], suggestExpertPrompt: Bool)? {
        var segments: [AssistantSegment] = []

        if let rawMessages = json["messages"] as? [[String: Any]] {
            for raw in rawMessages {
                guard let markdown = raw["markdown"] as? String,
                      let speakerName = (raw["speaker"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !speakerName.isEmpty else { continue }
                let kind = ((raw["kind"] as? String) ?? "").lowercased()
                if kind == "expert", let expert = expertSuggestion(named: speakerName) {
                    segments.append(AssistantSegment(speaker: speaker(for: expert), markdown: markdown, followUpExpert: expert))
                } else {
                    let speakerValue = normalize(speakerName) == normalize("Lil-Lenny")
                        ? lennySpeaker()
                        : TranscriptSpeaker(name: speakerName, avatarPath: nil, kind: .system)
                    segments.append(AssistantSegment(speaker: speakerValue, markdown: markdown, followUpExpert: nil))
                }
            }
        }

        if segments.isEmpty, let answerMarkdown = json["answer_markdown"] as? String {
            segments = [AssistantSegment(speaker: lennySpeaker(), markdown: answerMarkdown, followUpExpert: nil)]
        }

        guard !segments.isEmpty else { return nil }

        let explicitExperts = (json["suggested_experts"] as? [String] ?? []).compactMap { expertSuggestion(named: $0) }
        let impliedExperts = segments.compactMap(\.followUpExpert)
        let uniqueExperts = (explicitExperts + impliedExperts).reduce(into: [ResponderExpert]()) { partial, expert in
            if !partial.contains(where: { $0.name == expert.name }) {
                partial.append(expert)
            }
        }
        let suggestExpertPrompt = json["suggest_expert_prompt"] as? Bool ?? !uniqueExperts.isEmpty
        return (segments, Array(uniqueExperts.prefix(3)), suggestExpertPrompt)
    }

    func expertSuggestion(named rawName: String) -> ResponderExpert? {
        guard let canonical = canonicalExpertName(for: rawName),
              let avatarPath = avatarPath(for: canonical) else { return nil }
        let context = "Explicitly suggested by the assistant in the latest answer."
        return ResponderExpert(
            name: canonical,
            avatarPath: avatarPath,
            archiveContext: context,
            responseScript: responseScript(for: canonical, context: context)
        )
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

        if let json = object as? [String: Any],
           json["answer_markdown"] is String || json["messages"] is [[String: Any]] {
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
                        if candidate.contains("\"answer_markdown\"") || candidate.contains("\"messages\"") {
                            return candidate
                        }
                        break
                    }
                }
            }
        }

        return nil
    }
}
