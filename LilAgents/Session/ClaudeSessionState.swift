extension ClaudeSession {
    var history: [Message] { history(for: focusedExpert) }

    func history(for expert: ResponderExpert?) -> [Message] {
        conversations[key(for: expert)]?.history ?? []
    }

    func key(for expert: ResponderExpert?) -> String {
        if let expert {
            return "expert:\(normalize(expert.name))"
        }
        return "lenny"
    }

    func appendHistory(_ message: Message, to key: String) {
        var state = conversations[key] ?? ConversationState()
        state.history.append(message)
        conversations[key] = state
    }

    func finishTurn() {
        isBusy = false
        onTurnComplete?()
    }

    func failTurn(_ text: String) {
        failTurn(text, conversationKey: key(for: focusedExpert))
    }

    func failTurn(_ text: String, conversationKey: String) {
        isBusy = false
        pendingExperts.removeAll()
        appendHistory(Message(role: .error, text: text), to: conversationKey)
        onError?(text)
        onTurnComplete?()
    }

    func buildInstructions(for expert: ResponderExpert?) -> String {
        let base = """
        You are answering inside a macOS companion app using Lenny's archive.
        Prefer retrieved archive evidence over generic knowledge.
        Keep the answer concise and practical.
        Return only valid JSON, with no prose before or after it and no code fences.
        Use this exact shape:
        {
          "answer_markdown": "markdown answer here",
          "suggested_experts": ["Name One", "Name Two"],
          "suggest_expert_prompt": true
        }
        `suggested_experts` should include up to 3 relevant archive experts you explicitly relied on or cited.
        If there are no useful expert suggestions, return an empty array and set `suggest_expert_prompt` to false.
        """

        if let expert {
            return base + """

            The user explicitly switched into \(expert.name)'s avatar.
            Answer in first person as \(expert.name).
            If MCP tools are available, search for \(expert.name) first and stay in that context unless the user asks to pivot.
            \(expert.responseScript)
            \(expertContextPrompt(expert.archiveContext))
            """
        }

        return base
    }

    func buildUserPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, archiveContext: String? = nil) -> String {
        let baseMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Please analyze the attached file(s) and answer based on them."
            : message

        let attachmentContext: String
        if attachments.isEmpty {
            attachmentContext = ""
        } else {
            let names = attachments.map(\.displayName).joined(separator: ", ")
            attachmentContext = "\n\nAttached files: \(names)"
        }

        let archiveSection = archiveContext.map { "\n\nArchive context:\n\($0)" } ?? ""

        if let expert {
            return "Follow-up focus: \(expert.name)\nAnswer from \(expert.name)'s perspective.\nQuestion: \(baseMessage)\(attachmentContext)\(archiveSection)"
        }
        return baseMessage + attachmentContext + archiveSection
    }

    func expertContextPrompt(_ context: String) -> String {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("Explicitly suggested by the assistant") else {
            return ""
        }
        return "Ground the answer in this expert context first:\n\(trimmed)"
    }

    func buildInputContent(prompt: String, attachments: [SessionAttachment]) -> [[String: Any]] {
        var content: [[String: Any]] = [[
            "type": "input_text",
            "text": prompt
        ]]

        for attachment in attachments {
            switch attachment.kind {
            case .image:
                guard let imageURL = imageDataURL(for: attachment.url) else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached image: \(attachment.displayName)"
                ])
                content.append([
                    "type": "input_image",
                    "image_url": imageURL,
                    "detail": "auto"
                ])

            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached document: \(attachment.displayName)\n\n\(extractedText)"
                ])
            }
        }

        return content
    }

    func historyText(message: String, attachments: [SessionAttachment]) -> String {
        guard !attachments.isEmpty else { return message }
        let attachmentLine = attachments.map(\.displayName).joined(separator: ", ")
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "[attachments] \(attachmentLine)"
        }
        return "\(message)\n[attachments] \(attachmentLine)"
    }

    func buildConversationPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, expectMCP: Bool) -> String {
        let instructions = buildInstructions(for: expert)
        let priorMessages = promptHistory(for: conversationKey, expert: expert)
        let transcript = priorMessages.compactMap { message -> String? in
            switch message.role {
            case .user:
                return "User: \(message.text)"
            case .assistant:
                return "Assistant: \(message.text)"
            case .error:
                return "System error: \(message.text)"
            case .toolUse, .toolResult:
                return nil
            }
        }.joined(separator: "\n\n")

        var sections = [
            "System instructions:\n\(instructions)"
        ]

        if !transcript.isEmpty {
            sections.append("Conversation so far:\n\(transcript)")
        }

        sections.append("Latest user message:\n\(buildUserPrompt(message: message, attachments: attachments, expert: expert, archiveContext: archiveContext))")

        let attachmentContext = attachmentPromptSections(for: attachments)
        if !attachmentContext.isEmpty {
            sections.append("Attachment context:\n\(attachmentContext)")
        }

        sections.append(expectMCP ? "Use the Lenny archive MCP tools whenever they help. In expert mode, search that person first. Return only the JSON object described above." : "Answer using the bundled starter archive context above. Be explicit when the starter pack does not include enough evidence. Return only the JSON object described above.")
        return sections.joined(separator: "\n\n")
    }

    func promptHistory(for conversationKey: String, expert: ResponderExpert?) -> ArraySlice<Message> {
        let history = conversations[conversationKey]?.history ?? []
        let trimmed = Array(history.dropLast())
        let maxMessages = expert == nil ? 6 : 4
        return trimmed.suffix(maxMessages)
    }

    func attachmentPromptSections(for attachments: [SessionAttachment]) -> String {
        attachments.compactMap { attachment in
            switch attachment.kind {
            case .image:
                return "Image attachment: \(attachment.displayName) at \(attachment.url.path)"
            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else {
                    return "Document attachment: \(attachment.displayName)"
                }
                return "Document attachment: \(attachment.displayName)\n\(extractedText)"
            }
        }.joined(separator: "\n\n")
    }
}
