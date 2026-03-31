import Foundation

extension ClaudeSession {
    func callClaudeCodeCLI(executablePath: String, message: String, attachments: [SessionAttachment], environment: [String: String], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, officialMCPToken: String?) {
        let useOfficialMCP = officialMCPToken != nil
        let modelLabel = selectedClaudeModelLabel()
        let planningSummary = useOfficialMCP
            ? "Calling \(modelLabel) in Claude Code with Lenny MCP"
            : "Calling \(modelLabel) in Claude Code"
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useOfficialMCP)
        var configURL: URL?

        if useOfficialMCP, let token = officialMCPToken {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lenny-claude-mcp-\(UUID().uuidString).json")
            let config: [String: Any] = [
                "mcpServers": [
                    Constants.lennyMCPServerLabel: [
                        "type": "http",
                        "url": Constants.lennyMCPURL,
                        "headers": [
                            "Authorization": "Bearer \(token)"
                        ]
                    ]
                ]
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
                try data.write(to: url, options: [.atomic])
                configURL = url
            } catch {
                failTurn("Couldn’t prepare the Claude Code MCP config.", conversationKey: conversationKey)
                return
            }
        }

        var args = [
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--verbose",
            "--permission-mode",
            "dontAsk"
        ]

        if let model = selectedClaudeModel() {
            args.append(contentsOf: ["--model", model])
        }

        if useOfficialMCP {
            args.append(contentsOf: ["--allowedTools", "mcp__\(Constants.lennyMCPServerLabel)__*"])
            if let configURL {
                args.append(contentsOf: ["--mcp-config", configURL.path, "--strict-mcp-config"])
            }
        }

        if environment["ANTHROPIC_API_KEY"] != nil {
            args.append("--bare")
        }

        SessionDebugLogger.logMultiline(
            "claude-cli",
            header: "dispatching Claude Code CLI. executable=\(executablePath) useOfficialMCP=\(useOfficialMCP) configURL=\(configURL?.path ?? "none") args=\(args)",
            body: prompt
        )

        runProcess(
            executablePath: executablePath,
            arguments: args,
            environment: environment,
            workingDirectory: preferredWorkingDirectoryURL(),
            onLineReceived: { [weak self] line in
                guard let self else { return }
                SessionDebugLogger.traceMultiline(
                    "claude-transport",
                    header: "raw Claude transport line",
                    body: line
                )
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let event = self.claudeCLIStreamEvent(from: json) {
                    let experts = self.expertsFromTransport(
                        payload: json,
                        textCandidates: [event.summary, line]
                    )
                    self.onToolUse?(event.title, ["summary": event.summary, "experts": experts])
                } else if !line.hasPrefix("{") && !line.hasPrefix("}") {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let summary = String(trimmed.prefix(80))
                    let experts = self.expertsFromTransport(
                        payload: ["message": trimmed],
                        textCandidates: [trimmed, summary]
                    )
                    self.onToolUse?("Calling Model", ["summary": summary, "experts": experts])
                }
            }
        ) { [weak self] status, stdout, stderr in
            guard let self else { return }
            if let configURL {
                try? FileManager.default.removeItem(at: configURL)
            }

            if self.isCancellingTurn {
                self.isCancellingTurn = false
                self.pendingExperts.removeAll()
                return
            }

            SessionDebugLogger.logMultiline(
                "claude-cli",
                header: "Claude Code CLI finished. exitCode=\(status)",
                body: "stdout:\n\(stdout)\n\nstderr:\n\(stderr)"
            )
            self.logClaudeCLIResultMetadata(from: stdout)

            let outputText = self.extractClaudeCLIResult(from: stdout)
            if status == 0, let outputText, !outputText.isEmpty {
                self.finishCLIResponse(outputText, conversationKey: conversationKey)
                return
            }

            let errorText = self.normalizeCLIError(stdout: stdout, stderr: stderr, fallback: "Claude Code CLI could not complete the request.")
            self.failTurn(errorText, conversationKey: conversationKey)
        }
    }

    func callCodexCLI(executablePath: String, message: String, attachments: [SessionAttachment], environment: [String: String], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, useBundledMCP: Bool) {
        let modelLabel = selectedCodexModelLabel()
        let planningSummary = useBundledMCP
            ? "Calling \(modelLabel) in Codex with Lenny MCP"
            : "Calling \(modelLabel) in Codex"
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useBundledMCP)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("lenny-codex-last-message-\(UUID().uuidString).md")
        var runtimeEnvironment = environment
        if let token = officialMCPToken(from: environment) {
            runtimeEnvironment[Constants.lennyMCPAuthEnvVar] = token
        }

        var args = [
            "exec",
            "--skip-git-repo-check",
            "-s",
            "read-only",
            "-o",
            outputURL.path
        ]

        if let model = selectedCodexModel() {
            args.append(contentsOf: ["-m", model])
        }

        if useBundledMCP, officialMCPToken(from: environment) != nil {
            args.append(contentsOf: [
                "-c",
                "mcp_servers.\(Constants.lennyMCPServerLabel).url=\"\(Constants.lennyMCPURL)\"",
                "-c",
                "mcp_servers.\(Constants.lennyMCPServerLabel).bearer_token_env_var=\"\(Constants.lennyMCPAuthEnvVar)\""
            ])
        }

        args.append(prompt)

        for attachment in attachments where attachment.kind == .image {
            args.insert(contentsOf: ["-i", attachment.url.path], at: args.count - 1)
        }

        SessionDebugLogger.logMultiline(
            "codex-cli",
            header: "dispatching Codex CLI. executable=\(executablePath) useOfficialMCP=\(useBundledMCP) args=\(args)",
            body: prompt
        )

        runProcess(
            executablePath: executablePath,
            arguments: args,
            environment: runtimeEnvironment,
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ) { [weak self] status, stdout, stderr in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: outputURL) }

            if self.isCancellingTurn {
                self.isCancellingTurn = false
                self.pendingExperts.removeAll()
                return
            }

            SessionDebugLogger.logMultiline(
                "codex-cli",
                header: "Codex CLI finished. exitCode=\(status) outputFile=\(outputURL.path)",
                body: "stdout:\n\(stdout)\n\nstderr:\n\(stderr)"
            )

            let outputText = (try? String(contentsOf: outputURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let outputText {
                SessionDebugLogger.logMultiline("codex-cli", header: "Codex CLI output file contents", body: outputText)
            }

            if status == 0, let outputText, !outputText.isEmpty {
                self.finishCLIResponse(outputText, conversationKey: conversationKey)
                return
            }

            let errorText = self.normalizeCLIError(stdout: stdout, stderr: stderr, fallback: "Codex CLI could not complete the request.")
            self.failTurn(errorText, conversationKey: conversationKey)
        }
    }
}
