import AppKit
import Foundation
import PDFKit

extension ClaudeSession {
    func start() {
        resolveOpenAIKey { [weak self] key in
            guard let self else { return }
            guard key != nil else {
                let msg = "OPENAI_API_KEY is not available in your login shell, so the OpenAI Responses API cannot be used."
                self.onError?(msg)
                self.appendHistory(Message(role: .error, text: msg), to: self.key(for: self.focusedExpert))
                return
            }
            self.isRunning = true
            self.onSessionReady?()
        }
    }

    func send(message: String, attachments: [SessionAttachment] = []) {
        let activeExpert = focusedExpert
        let conversationKey = key(for: activeExpert)
        appendHistory(Message(role: .user, text: historyText(message: message, attachments: attachments)), to: conversationKey)
        isBusy = true

        resolveOpenAIKey { [weak self] key in
            guard let self else { return }
            guard let key else {
                self.failTurn("OPENAI_API_KEY is missing from your login shell.")
                return
            }
            self.callOpenAI(message: message, attachments: attachments, apiKey: key, expert: activeExpert, conversationKey: conversationKey)
        }
    }

    func terminate() {
        isRunning = false
        isBusy = false
        onProcessExit?()
    }

    func callOpenAI(message: String, attachments: [SessionAttachment], apiKey: String, expert: ResponderExpert?, conversationKey: String) {
        let prompt = buildUserPrompt(message: message, attachments: attachments, expert: expert)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": buildInputContent(prompt: prompt, attachments: attachments)
        ]]

        let instructions = buildInstructions(for: expert)
        var payload: [String: Any] = [
            "model": Constants.openAIModel,
            "instructions": instructions,
            "input": input,
            "tools": [[
                "type": "mcp",
                "server_label": "lennysdata",
                "server_description": "Lenny Rachitsky's archive of newsletter posts and podcast transcripts about startups, product, growth, pricing, leadership, career, and AI product work.",
                "server_url": Constants.lennyMCPURL,
                "headers": [
                    "Authorization": "Bearer \(Constants.lennyToken)"
                ],
                "require_approval": "never",
                "allowed_tools": ["search_content", "read_excerpt", "read_content", "list_content"]
            ]]
        ]

        if let previousResponseID = conversations[conversationKey]?.previousResponseID {
            payload["previous_response_id"] = previousResponseID
        }

        let planningSummary = expert == nil
            ? "Understanding your question and deciding which archive tools to use"
            : "Continuing \(expert!.name)'s thread with the right archive context"
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        var request = URLRequest(url: Constants.openAIEndpoint, timeoutInterval: Constants.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            failTurn("Couldn’t encode the OpenAI request.", conversationKey: conversationKey)
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.failTurn("OpenAI request failed: \(error.localizedDescription)", conversationKey: conversationKey)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.failTurn("OpenAI returned an unreadable response.", conversationKey: conversationKey)
                    return
                }
                self.handleOpenAIResponse(json, conversationKey: conversationKey)
            }
        }.resume()
    }

    func handleOpenAIResponse(_ json: [String: Any], conversationKey: String) {
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            failTurn("OpenAI error: \(message)", conversationKey: conversationKey)
            return
        }

        if let responseID = json["id"] as? String {
            var state = conversations[conversationKey] ?? ConversationState()
            state.previousResponseID = responseID
            conversations[conversationKey] = state
        }

        let outputItems = json["output"] as? [[String: Any]] ?? []
        var experts: [ResponderExpert] = []

        for item in outputItems {
            guard let type = item["type"] as? String else { continue }
            switch type {
            case "mcp_list_tools":
                let tools = item["tools"] as? [[String: Any]] ?? []
                let count = tools.count
                let summary = "Connected to Lenny archive, \(count) tools ready"
                onToolResult?(summary, false)
                appendHistory(Message(role: .toolResult, text: summary), to: conversationKey)

            case "mcp_call":
                let name = item["name"] as? String ?? "mcp_call"
                let arguments = item["arguments"] as? [String: Any] ?? [:]
                let processStep = processDisplay(for: name, arguments: arguments)
                onToolUse?(processStep.title, ["summary": processStep.summary])
                appendHistory(Message(role: .toolUse, text: "\(processStep.title): \(processStep.summary)"), to: conversationKey)

                let output = item["output"]
                let extractedExperts = expertsFromMCPPayloads(arguments: arguments, output: output)
                for expert in extractedExperts where !experts.contains(expert) {
                    experts.append(expert)
                }

                let resultSummary = processResultDisplay(for: name, arguments: arguments, output: output)
                onToolResult?(resultSummary, false)
                appendHistory(Message(role: .toolResult, text: resultSummary), to: conversationKey)

            case "message":
                continue

            default:
                continue
            }
        }

        onExpertsUpdated?(experts)

        let outputText = (json["output_text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let outputText, !outputText.isEmpty {
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: outputText), to: conversationKey)
            onText?(outputText)
            finishTurn()
            return
        }

        if let messageText = extractMessageText(from: outputItems), !messageText.isEmpty {
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: messageText), to: conversationKey)
            onText?(messageText)
            finishTurn()
            return
        }

        failTurn("The model returned no final answer.", conversationKey: conversationKey)
    }

    func buildInstructions(for expert: ResponderExpert?) -> String {
        let base = """
        You are answering as Lenny inside a macOS companion app.
        Use the remote MCP server tools when they are helpful.
        Prefer Lenny archive content for startup, product, growth, pricing, leadership, career, and AI product questions.
        Give a concise, practical answer in markdown.
        Mention the relevant expert names naturally when they appear in the archive.
        """

        if let expert {
            return base + """

            The user is currently in follow-up mode for \(expert.name).
            \(expert.responseScript)
            Prefer tools, excerpts, and synthesis related to \(expert.name) when relevant.
            Ground the answer in this retrieved context first before broadening out:
            \(expert.archiveContext)
            """
        }

        return base
    }

    func buildUserPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?) -> String {
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

        if let expert {
            return "Follow-up focus: \(expert.name)\n\nUser question: \(baseMessage)\(attachmentContext)"
        }
        return baseMessage + attachmentContext
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

    func resolveOpenAIKey(completion: @escaping (String?) -> Void) {
        if let cached = Self.openAIKey, Self.shellEnvironment != nil {
            completion(cached)
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        proc.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if let startRange = output.range(of: "---ENV_START---\n"),
                   let endRange = output.range(of: "\n---ENV_END---") {
                    let envString = String(output[startRange.upperBound..<endRange.lowerBound])
                    var env: [String: String] = [:]
                    for line in envString.components(separatedBy: "\n") {
                        if let eqRange = line.range(of: "=") {
                            let key = String(line[..<eqRange.lowerBound])
                            let value = String(line[eqRange.upperBound...])
                            env[key] = value
                        }
                    }
                    Self.shellEnvironment = env
                    Self.openAIKey = env["OPENAI_API_KEY"]
                }
                completion(Self.openAIKey)
            }
        }

        do {
            try proc.run()
        } catch {
            completion(nil)
        }
    }

    func imageDataURL(for url: URL) -> String? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let maxDimension: CGFloat = 1600
        let originalSize = image.size
        let scale = min(1, maxDimension / max(originalSize.width, originalSize.height))
        let targetSize = NSSize(width: max(1, originalSize.width * scale), height: max(1, originalSize.height * scale))

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }

        let hasAlpha = bitmap.hasAlpha
        let data: Data?
        let mimeType: String

        if hasAlpha {
            data = bitmap.representation(using: .png, properties: [:])
            mimeType = "image/png"
        } else {
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
            mimeType = "image/jpeg"
        }

        guard let encoded = data?.base64EncodedString() else { return nil }
        return "data:\(mimeType);base64,\(encoded)"
    }

    func documentText(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else { return nil }
            return trimmedDocumentText(pdf.string)
        }

        if ext == "rtf",
           let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            return trimmedDocumentText(attributed.string)
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return trimmedDocumentText(text)
    }

    func trimmedDocumentText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(12_000))
    }
}
