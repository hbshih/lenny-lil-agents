import Foundation

extension ClaudeSession {
    func callClaudeCodeCLI(executablePath: String, message: String, attachments: [SessionAttachment], environment: [String: String], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, officialMCPToken: String?) {
        let useOfficialMCP = officialMCPToken != nil
        let planningSummary = useOfficialMCP
            ? (expert == nil ? "Using Claude Code CLI and the official Lenny MCP server" : "Continuing \(expert!.name)'s thread through Claude Code CLI and the official Lenny MCP server")
            : (expert == nil ? "Using Claude Code CLI with bundled starter archive context" : "Continuing \(expert!.name)'s thread through Claude Code CLI and bundled starter archive context")
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useOfficialMCP)
        var configURL: URL?

        if useOfficialMCP, let token = officialMCPToken {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("lil-agents-claude-mcp-\(UUID().uuidString).json")
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
            "json",
            "--permission-mode",
            "dontAsk"
        ]

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
                // Claude Code JSON stream parsing
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let type = json["type"] as? String {
                        if type == "message", let msg = json["message"] as? String {
                            self?.onToolUse?("Generating", ["summary": msg])
                        } else if type == "tool_use" {
                            let tool = json["tool"] as? String ?? "Tool"
                            self?.onToolUse?("Running", ["summary": "Using \(tool)..."])
                        } else if type == "progress" {
                            let msg = json["message"] as? String ?? "Processing..."
                            self?.onToolUse?("Progress", ["summary": msg])
                        }
                    }
                } else if !line.hasPrefix("{") && !line.hasPrefix("}") {
                    // Fallback for non-JSON lines printed by CLI, show them instantly
                    self?.onToolUse?("Thinking", ["summary": String(line.prefix(60))])
                }
            }
        ) { [weak self] status, stdout, stderr in
            guard let self else { return }
            if let configURL {
                try? FileManager.default.removeItem(at: configURL)
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
        let planningSummary = useBundledMCP
            ? (expert == nil ? "Using Codex CLI and the official Lenny MCP server" : "Continuing \(expert!.name)'s thread through Codex CLI and the official Lenny MCP server")
            : (expert == nil ? "Using Codex CLI with bundled starter archive context" : "Continuing \(expert!.name)'s thread through Codex CLI and bundled starter archive context")
        onToolUse?("Planning", ["summary": planningSummary])
        appendHistory(Message(role: .toolUse, text: "Planning: \(planningSummary)"), to: conversationKey)

        let prompt = buildConversationPrompt(message: message, attachments: attachments, expert: expert, conversationKey: conversationKey, archiveContext: archiveContext, expectMCP: useBundledMCP)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("lil-agents-codex-last-message-\(UUID().uuidString).md")
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
