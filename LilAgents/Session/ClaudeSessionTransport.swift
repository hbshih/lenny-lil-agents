import Darwin
import Foundation

extension ClaudeSession {
    func preferredWorkingDirectoryURL() -> URL {
        if AppSettings.effectiveArchiveAccessMode == .starterPack {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LilLennyStarterPackCLI", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    func start() {
        SessionDebugLogger.log("session", "start() called")
        resolvePreferredBackend { [weak self] backend, environment, message in
            guard let self else { return }
            SessionDebugLogger.log("session", "start() backend resolution completed. backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                let msg = message ?? self.backendSetupMessage(environment: environment)
                SessionDebugLogger.log("session", "start() failed: \(msg)")
                self.onSetupRequired?(msg)
                return
            }

            self.selectedBackend = backend
            self.isRunning = true
            SessionDebugLogger.log("session", "session ready. selectedBackend=\(self.backendStatusMessage(for: backend, environment: environment))")
            self.onSessionReady?()
        }
    }

    func send(message: String, attachments: [SessionAttachment] = []) {
        let activeExpert = focusedExpert
        let conversationKey = key(for: activeExpert)
        isCancellingTurn = false
        pendingExperts.removeAll()
        liveToolCallsByID.removeAll()
        assistantExplicitlyRequestedExperts = false
        appendHistory(Message(role: .user, text: historyText(message: message, attachments: attachments)), to: conversationKey)
        isBusy = true
        SessionDebugLogger.logMultiline(
            "turn",
            header: "send() called. conversationKey=\(conversationKey) expert=\(activeExpert?.name ?? "none") archiveMode=\(AppSettings.effectiveArchiveAccessMode.rawValue) attachments=\(SessionDebugLogger.summarizeAttachments(attachments))",
            body: "User message:\n\(message)"
        )

        resolvePreferredBackend { [weak self] backend, environment, messageText in
            guard let self else { return }
            SessionDebugLogger.log("turn", "resolved backend=\(String(describing: backend)) environment=\(SessionDebugLogger.summarizeEnvironment(environment))")
            guard let backend else {
                SessionDebugLogger.log("turn", "backend resolution failed: \(messageText ?? "unknown error")")
                self.onSetupRequired?(messageText ?? self.backendSetupMessage(environment: environment))
                return
            }

            self.selectedBackend = backend
            let archiveMode = self.effectiveArchiveAccessMode(environment: environment)
            let status = self.backendStatusMessage(for: backend, environment: environment)
            self.onToolResult?(status, false)
            self.appendHistory(Message(role: .toolResult, text: status), to: conversationKey)

            let sourceSummary = archiveMode == .starterPack
                ? "Source: Starter pack"
                : "Source: Official Lenny archive"
            self.onToolResult?(sourceSummary, false)
            self.appendHistory(Message(role: .toolResult, text: sourceSummary), to: conversationKey)

            if archiveMode == .starterPack {
                let localResult = self.searchStarterArchive(message: message, expert: activeExpert)
                let expertNames = localResult.experts.map(\.name).joined(separator: ", ")
                SessionDebugLogger.logMultiline(
                    "starter-pack",
                    header: "starter pack search complete. summary=\(localResult.summary) result=\(localResult.resultSummary) experts=\(expertNames)",
                    body: localResult.promptContext
                )
                self.onToolUse?("Searching Starter Pack", ["summary": localResult.summary, "experts": localResult.experts])
                self.appendHistory(Message(role: .toolUse, text: "Searching Starter Pack: \(localResult.summary)"), to: conversationKey)
                self.onToolResult?(localResult.resultSummary, false)
                self.appendHistory(Message(role: .toolResult, text: localResult.resultSummary), to: conversationKey)
                self.pendingExperts = localResult.experts
                SessionDebugLogger.log("experts", "staged \(localResult.experts.count) starter-pack expert candidate(s) until response completion")

                switch backend {
                case let .claudeCodeCLI(path):
                    self.callClaudeCodeCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: localResult.promptContext,
                        officialMCPToken: nil,
                        useOfficialMCP: false
                    )

                case let .codexCLI(path):
                    self.callCodexCLI(
                        executablePath: path,
                        message: message,
                        attachments: attachments,
                        environment: environment,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        archiveContext: localResult.promptContext,
                        useOfficialMCP: false
                    )

                case .openAIResponsesAPI:
                    guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                        SessionDebugLogger.log("turn", "starter pack mode selected openai fallback but OPENAI_API_KEY missing")
                        self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                        return
                    }
                    self.callOpenAI(
                        message: message,
                        attachments: attachments,
                        apiKey: key,
                        expert: activeExpert,
                        conversationKey: conversationKey,
                        mcpToken: nil,
                        archiveContext: localResult.promptContext
                    )
                }
                return
            }

            if let token = self.officialMCPToken(from: environment) {
                self.fetchOfficialArchiveContext(
                    message: message,
                    expert: activeExpert,
                    token: token,
                    conversationKey: conversationKey
                ) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .failure(let error):
                        let normalizedError = self.normalizedLennyMCPAuthError(from: error.localizedDescription) ?? error.localizedDescription
                        self.failTurn(normalizedError, conversationKey: conversationKey)

                    case let .success(officialResult):
                        self.pendingExperts = officialResult.experts
                        SessionDebugLogger.log(
                            "experts",
                            "staged \(officialResult.experts.count) official-archive expert candidate(s) until response completion"
                        )
                        self.dispatchResolvedBackend(
                            backend,
                            message: message,
                            attachments: attachments,
                            environment: environment,
                            expert: activeExpert,
                            conversationKey: conversationKey,
                            archiveContext: officialResult.promptContext,
                            officialMCPToken: nil,
                            useOfficialMCP: false
                        )
                    }
                }
                return
            }

            self.dispatchResolvedBackend(
                backend,
                message: message,
                attachments: attachments,
                environment: environment,
                expert: activeExpert,
                conversationKey: conversationKey,
                archiveContext: nil,
                officialMCPToken: self.officialMCPToken(from: environment),
                useOfficialMCP: self.backendSupportsOfficialMCP(backend, environment: environment)
            )
        }
    }

    func terminate() {
        currentProcess?.terminate()
        currentProcess = nil
        currentDataTask?.cancel()
        currentDataTask = nil
        isRunning = false
        isBusy = false
        livePresenceExperts.removeAll()
        liveToolCallsByID.removeAll()
        onProcessExit?()
    }

    func cancelActiveTurn() {
        isCancellingTurn = true
        if let process = currentProcess {
            let processID = process.processIdentifier
            if process.isRunning {
                process.interrupt()
                process.terminate()

                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self, self.isCancellingTurn else { return }
                    guard process.isRunning else { return }
                    kill(processID, SIGKILL)
                }
            }
        }
        currentProcess = nil
        currentDataTask?.cancel()
        currentDataTask = nil
        isBusy = false
        pendingExperts.removeAll()
        assistantExplicitlyRequestedExperts = false
        livePresenceExperts.removeAll()
        liveToolCallsByID.removeAll()
    }

    func searchStarterArchive(message: String, expert: ResponderExpert?) -> (promptContext: String, experts: [ResponderExpert], summary: String, resultSummary: String) {
        let query = [expert?.name, message]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        SessionDebugLogger.log("starter-pack", "search query=\(query)")
        let matches = LocalArchive.shared.search(query: query, limit: 4)

        if matches.isEmpty {
            let promptContext = """
            The bundled starter archive did not contain a strong match for this query.
            Be transparent that the starter pack only includes 10 newsletters and 50 podcast transcripts.
            Suggest switching Settings to Official Lenny MCP for the full archive if needed.
            """
            return (
                promptContext,
                [],
                "Searching the bundled starter pack",
                "No strong matches found in the bundled starter pack"
            )
        }

        let contextLines = matches.enumerated().map { index, match in
            let subtitle = match.entry.subtitle ?? match.entry.description ?? ""
            let subtitleSuffix = subtitle.isEmpty ? "" : "\nSubtitle: \(subtitle)"
            return """
            \(index + 1). [\(match.entry.typeLabel.capitalized)] \(match.entry.title) (\(match.entry.date))
            File: \(match.entry.filename)\(subtitleSuffix)
            Excerpt: \(match.excerpt)
            """
        }
        let promptContext = contextLines.joined(separator: "\n\n")

        let experts = matches.compactMap { match -> ResponderExpert? in
            let name = match.entry.guest ?? speakerName(fromTitle: match.entry.title)
            guard let name, let avatarPath = avatarPath(for: name) else { return nil }
            return makeResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: "- \(match.entry.title) (\(match.entry.date)): \(match.excerpt)"
            )
        }

        let uniqueExperts = experts.reduce(into: [ResponderExpert]()) { partial, expert in
            if !partial.contains(where: { $0.name == expert.name }) {
                partial.append(expert)
            }
        }

        return (
            promptContext,
            Array(uniqueExperts.prefix(3)),
            "Searching the bundled starter pack",
            "Loaded \(matches.count) starter-pack match\(matches.count == 1 ? "" : "es")"
        )
    }

    func publishPendingExperts(fallbackText: String? = nil) {
        let experts = pendingExperts
        pendingExperts.removeAll()
        let assistantRequestedExperts = assistantExplicitlyRequestedExperts
        assistantExplicitlyRequestedExperts = false

        guard assistantRequestedExperts else {
            if let fallbackText, fallbackText.contains("\"answer_markdown\"") {
                SessionDebugLogger.log("experts", "skipping staged experts because assistant output was not parsed cleanly")
            } else {
                SessionDebugLogger.log("experts", "skipping staged experts because assistant did not explicitly request them")
            }
            return
        }

        guard !experts.isEmpty else {
            SessionDebugLogger.log("experts", "no staged experts to publish")
            return
        }

        let names = experts.map(\.name).joined(separator: ", ")
        SessionDebugLogger.log("experts", "publishing \(experts.count) expert candidate(s) after response completion: \(names)")
        onExpertsUpdated?(experts)
    }

    private func dispatchResolvedBackend(
        _ backend: Backend,
        message: String,
        attachments: [SessionAttachment],
        environment: [String: String],
        expert: ResponderExpert?,
        conversationKey: String,
        archiveContext: String?,
        officialMCPToken: String?,
        useOfficialMCP: Bool
    ) {
        switch backend {
        case let .claudeCodeCLI(path):
            self.callClaudeCodeCLI(
                executablePath: path,
                message: message,
                attachments: attachments,
                environment: environment,
                expert: expert,
                conversationKey: conversationKey,
                archiveContext: archiveContext,
                officialMCPToken: officialMCPToken,
                useOfficialMCP: useOfficialMCP
            )

        case let .codexCLI(path):
            self.callCodexCLI(
                executablePath: path,
                message: message,
                attachments: attachments,
                environment: environment,
                expert: expert,
                conversationKey: conversationKey,
                archiveContext: archiveContext,
                useOfficialMCP: useOfficialMCP
            )

        case .openAIResponsesAPI:
            guard let key = environment["OPENAI_API_KEY"], !key.isEmpty else {
                SessionDebugLogger.log("turn", "selected openai backend but OPENAI_API_KEY missing")
                self.failTurn(self.backendSetupMessage(environment: environment), conversationKey: conversationKey)
                return
            }
            self.callOpenAI(
                message: message,
                attachments: attachments,
                apiKey: key,
                expert: expert,
                conversationKey: conversationKey,
                mcpToken: useOfficialMCP ? officialMCPToken : nil,
                archiveContext: archiveContext
            )
        }
    }
}
