import Foundation

extension ClaudeSession {
    func fetchOfficialArchiveContext(
        message: String,
        expert: ResponderExpert?,
        token: String,
        conversationKey: String,
        completion: @escaping (Result<(promptContext: String, experts: [ResponderExpert], resultSummary: String), Error>) -> Void
    ) {
        let query = [expert?.name, message]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        Task {
            do {
                let client = try LennyArchiveClient(token: token)

                let searchArguments: [String: Any] = [
                    "query": query,
                    "limit": 6
                ]
                let searchStep = processDisplay(for: "search_content", arguments: searchArguments)
                await MainActor.run {
                    onToolUse?(searchStep.title, ["summary": searchStep.summary])
                    appendHistory(Message(role: .toolUse, text: "\(searchStep.title): \(searchStep.summary)"), to: conversationKey)
                }

                let searchOutput = try await client.searchContent(query: query, limit: 6)
                let resultSummary = processResultDisplay(for: "search_content", arguments: searchArguments, output: searchOutput)
                await MainActor.run {
                    onToolResult?(resultSummary, false)
                    appendHistory(Message(role: .toolResult, text: resultSummary), to: conversationKey)
                }

                guard let searchEnvelope = decodeSearchEnvelope(from: searchOutput),
                      !searchEnvelope.results.isEmpty else {
                    await MainActor.run {
                        completion(.success((
                            promptContext: """
                            The official Lenny archive search did not return a strong direct match for this query.
                            Be explicit about uncertainty and avoid inventing specific archive citations.
                            """,
                            experts: [],
                            resultSummary: "No strong matches found in the official archive"
                        )))
                    }
                    return
                }

                let topMatch = searchEnvelope.results[0]
                let excerptArguments: [String: Any] = [
                    "filename": topMatch.filename,
                    "query": query,
                    "radius": 700
                ]
                let excerptStep = processDisplay(for: "read_excerpt", arguments: excerptArguments)
                await MainActor.run {
                    onToolUse?(excerptStep.title, ["summary": excerptStep.summary])
                    appendHistory(Message(role: .toolUse, text: "\(excerptStep.title): \(excerptStep.summary)"), to: conversationKey)
                }

                let excerptOutput: [String: Any]
                do {
                    excerptOutput = try await client.readExcerpt(filename: topMatch.filename, query: query, radius: 700)
                    let excerptSummary = processResultDisplay(for: "read_excerpt", arguments: excerptArguments, output: excerptOutput)
                    await MainActor.run {
                        onToolResult?(excerptSummary, false)
                        appendHistory(Message(role: .toolResult, text: excerptSummary), to: conversationKey)
                    }
                } catch {
                    excerptOutput = [:]
                }

                let promptContext = officialArchivePromptContext(from: searchEnvelope, excerptOutput: excerptOutput)
                let experts = expertsFromMCPPayloads(arguments: searchArguments, output: searchOutput)
                await MainActor.run {
                    completion(.success((
                        promptContext: promptContext,
                        experts: experts,
                        resultSummary: resultSummary
                    )))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private func decodeSearchEnvelope(from output: Any?) -> SearchEnvelope? {
        if let dict = output as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data) {
            return envelope
        }

        if let text = output as? String,
           let data = text.data(using: .utf8),
           let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data) {
            return envelope
        }

        return nil
    }

    private func officialArchivePromptContext(from envelope: SearchEnvelope, excerptOutput: Any?) -> String {
        let matches = envelope.results.prefix(4).enumerated().map { index, result in
            let rawSnippet = result.snippet ?? result.snippets?.first?.text ?? ""
            let compactSnippet = rawSnippet
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = compactSnippet.isEmpty ? "No snippet available." : String(compactSnippet.prefix(260))
            return """
            \(index + 1). [\(result.type.capitalized)] \(result.title) (\(result.date))
            File: \(result.filename)
            Excerpt: \(snippet)
            """
        }.joined(separator: "\n\n")

        let excerptSection: String
        if let excerptText = flattenedArchiveText(from: excerptOutput), !excerptText.isEmpty {
            excerptSection = "\n\nFocused excerpt:\n\(excerptText)"
        } else {
            excerptSection = ""
        }

        return """
        Use the official Lenny archive context below as the primary evidence for this answer.
        Prefer this evidence over generic knowledge and be explicit about uncertainty if the archive context is incomplete.

        Relevant archive matches:
        \(matches)\(excerptSection)
        """
    }

    private func flattenedArchiveText(from output: Any?) -> String? {
        if let dict = output as? [String: Any] {
            if let excerpt = dict["excerpt"] as? String {
                let trimmed = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(1500))
                }
            }
            if let content = dict["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(1500))
                }
            }
            if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
               let json = String(data: data, encoding: .utf8) {
                let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(1500))
                }
            }
        }

        if let text = output as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(1500))
            }
        }

        return nil
    }
}
