import AppKit
import Foundation

extension ClaudeSession {
    func callOpenAI(message: String, attachments: [SessionAttachment], apiKey: String, expert: ResponderExpert?, conversationKey: String, mcpToken: String?, archiveContext: String?) {
        let prompt = buildUserPrompt(message: message, attachments: attachments, expert: expert, archiveContext: archiveContext)
        let input: [[String: Any]] = [[
            "role": "user",
            "content": buildInputContent(prompt: prompt, attachments: attachments)
        ]]

        let instructions = buildInstructions(for: expert)
        var payload: [String: Any] = [
            "model": Constants.openAIModel,
            "instructions": instructions,
            "input": input
        ]

        if let mcpToken {
            payload["tools"] = [[
                "type": "mcp",
                "server_label": Constants.lennyMCPServerLabel,
                "server_description": "Lenny Rachitsky's archive of newsletter posts and podcast transcripts about startups, product, growth, pricing, leadership, career, and AI product work.",
                "server_url": Constants.lennyMCPURL,
                "headers": [
                    "Authorization": "Bearer \(mcpToken)"
                ],
                "require_approval": "never",
                "allowed_tools": Constants.lennyAllowedTools
            ]]
        }

        if let previousResponseID = conversations[conversationKey]?.previousResponseID {
            payload["previous_response_id"] = previousResponseID
        }

        if let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let payloadText = String(data: payloadData, encoding: .utf8) {
            SessionDebugLogger.logMultiline(
                "openai",
                header: "dispatching OpenAI Responses API request. conversationKey=\(conversationKey) expert=\(expert?.name ?? "none") mcpInjected=\(mcpToken != nil)",
                body: payloadText
            )
        }

        let planningSummary = mcpToken == nil
            ? (expert == nil ? "Answering using the bundled starter archive context" : "Continuing \(expert!.name)'s thread using the bundled starter archive context")
            : (expert == nil ? "Understanding your question and deciding which archive tools to use" : "Continuing \(expert!.name)'s thread with the right archive context")
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
                    SessionDebugLogger.log("openai", "request failed: \(error.localizedDescription)")
                    self.failTurn("OpenAI request failed: \(error.localizedDescription)", conversationKey: conversationKey)
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    SessionDebugLogger.log("openai", "response unreadable")
                    self.failTurn("OpenAI returned an unreadable response.", conversationKey: conversationKey)
                    return
                }
                if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let jsonText = String(data: jsonData, encoding: .utf8) {
                    SessionDebugLogger.logMultiline("openai", header: "received OpenAI response", body: jsonText)
                }
                self.handleOpenAIResponse(json, conversationKey: conversationKey)
            }
        }.resume()
    }

    func handleOpenAIResponse(_ json: [String: Any], conversationKey: String) {
        SessionDebugLogger.log("openai", "handleOpenAIResponse() outputItems=\((json["output"] as? [[String: Any]] ?? []).count)")
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            SessionDebugLogger.log("openai", "model returned error: \(message)")
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
                SessionDebugLogger.log("mcp", "mcp_list_tools returned \(count) tool(s)")
                let summary = "Connected to Lenny archive, \(count) tools ready"
                onToolResult?(summary, false)
                appendHistory(Message(role: .toolResult, text: summary), to: conversationKey)

            case "mcp_call":
                let name = item["name"] as? String ?? "mcp_call"
                let arguments = item["arguments"] as? [String: Any] ?? [:]
                SessionDebugLogger.logMultiline("mcp", header: "mcp_call \(name)", body: "arguments=\(arguments)\noutput=\(String(describing: item["output"]))")
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

        pendingExperts = experts
        SessionDebugLogger.log("experts", "staged \(experts.count) MCP-derived expert candidate(s) until response completion")

        let outputText = (json["output_text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let outputText, !outputText.isEmpty {
            let cleanedOutput = prepareAssistantOutput(outputText)
            publishPendingExperts(fallbackText: cleanedOutput)
            SessionDebugLogger.logMultiline("assistant", header: "final assistant response", body: cleanedOutput)
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: cleanedOutput), to: conversationKey)
            onText?(cleanedOutput)
            finishTurn()
            return
        }

        if let messageText = extractMessageText(from: outputItems), !messageText.isEmpty {
            let cleanedMessage = prepareAssistantOutput(messageText)
            publishPendingExperts(fallbackText: cleanedMessage)
            SessionDebugLogger.logMultiline("assistant", header: "final assistant message response", body: cleanedMessage)
            let composeSummary = "Composing the final answer"
            onToolUse?("Writing", ["summary": composeSummary])
            appendHistory(Message(role: .toolUse, text: "Writing: \(composeSummary)"), to: conversationKey)
            appendHistory(Message(role: .assistant, text: cleanedMessage), to: conversationKey)
            onText?(cleanedMessage)
            finishTurn()
            return
        }

        failTurn("The model returned no final answer.", conversationKey: conversationKey)
    }
}
