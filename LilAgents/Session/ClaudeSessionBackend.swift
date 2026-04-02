import Foundation

extension ClaudeSession {
    func resolveOpenAIKey(completion: @escaping (String?) -> Void) {
        resolveShellEnvironment { environment in
            completion(environment["OPENAI_API_KEY"])
        }
    }

    func resolveShellEnvironment(completion: @escaping ([String: String]) -> Void) {
        if let cached = Self.shellEnvironment {
            Self.openAIKey = cached["OPENAI_API_KEY"]
            SessionDebugLogger.log("env", "using cached shell environment: \(SessionDebugLogger.summarizeEnvironment(cached))")
            completion(cached)
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()
        proc.terminationHandler = { _ in
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                var environment: [String: String] = [:]
                if let startRange = output.range(of: "---ENV_START---\n"),
                   let endRange = output.range(of: "\n---ENV_END---") {
                    let envString = String(output[startRange.upperBound..<endRange.lowerBound])
                    for line in envString.components(separatedBy: "\n") {
                        guard let eqRange = line.range(of: "=") else { continue }
                        let key = String(line[..<eqRange.lowerBound])
                        let value = String(line[eqRange.upperBound...])
                        environment[key] = value
                    }
                }

                Self.shellEnvironment = environment
                Self.openAIKey = environment["OPENAI_API_KEY"]
                SessionDebugLogger.log("env", "resolved shell environment: \(SessionDebugLogger.summarizeEnvironment(environment))")
                completion(environment)
            }
        }

        do {
            try proc.run()
        } catch {
            completion([:])
        }
    }

    func resolvePreferredBackend(completion: @escaping (Backend?, [String: String], String?) -> Void) {
        resolveShellEnvironment { [weak self] environment in
            guard let self else {
                completion(nil, environment, nil)
                return
            }

            let preferredTransport = AppSettings.preferredTransport
            let archiveMode = self.effectiveArchiveAccessMode(environment: environment)
            let preferenceKey = self.backendPreferenceKey(environment: environment)
            SessionDebugLogger.log("backend", "resolving preferred backend. archiveMode=\(archiveMode.rawValue) preferredTransport=\(preferredTransport.rawValue)")

            if let selectedBackend = self.selectedBackend,
               self.selectedBackendPreferenceKey == preferenceKey {
                SessionDebugLogger.log("backend", "reusing cached backend selection")
                completion(selectedBackend, environment, nil)
                return
            }

            if preferredTransport != .automatic {
                self.resolveForcedBackend(preferredTransport, environment: environment) { backend, environment, message in
                    if let backend {
                        self.selectedBackend = backend
                        self.selectedBackendPreferenceKey = preferenceKey
                    }
                    completion(backend, environment, message)
                }
                return
            }

            self.resolveClaudeCodeBackend(environment: environment) { claudeBackend in
                if let claudeBackend {
                    if archiveMode == .officialMCP {
                        if self.backendSupportsOfficialMCP(claudeBackend, environment: environment) {
                            SessionDebugLogger.log("backend", "selected Claude backend with official MCP support")
                            self.selectedBackend = claudeBackend
                            self.selectedBackendPreferenceKey = preferenceKey
                            completion(claudeBackend, environment, nil)
                            return
                        }
                        SessionDebugLogger.log("backend", "Claude backend available but lacks official MCP support")
                    } else {
                        SessionDebugLogger.log("backend", "selected Claude backend")
                        self.selectedBackend = claudeBackend
                        self.selectedBackendPreferenceKey = preferenceKey
                        completion(claudeBackend, environment, nil)
                        return
                    }
                }

                self.resolveCodexBackend(environment: environment) { codexBackend in
                    if let codexBackend {
                        if archiveMode == .officialMCP {
                            if self.backendSupportsOfficialMCP(codexBackend, environment: environment) {
                                SessionDebugLogger.log("backend", "selected Codex backend with official MCP support")
                                self.selectedBackend = codexBackend
                                self.selectedBackendPreferenceKey = preferenceKey
                                completion(codexBackend, environment, nil)
                                return
                            }
                            SessionDebugLogger.log("backend", "Codex backend available but lacks official MCP support")
                        } else {
                            SessionDebugLogger.log("backend", "selected Codex backend")
                            self.selectedBackend = codexBackend
                            self.selectedBackendPreferenceKey = preferenceKey
                            completion(codexBackend, environment, nil)
                            return
                        }
                    }

                    if let key = environment["OPENAI_API_KEY"], !key.isEmpty {
                        if archiveMode == .officialMCP {
                            if self.backendSupportsOfficialMCP(.openAIResponsesAPI, environment: environment) {
                                SessionDebugLogger.log("backend", "selected direct OpenAI Responses API backend with official MCP support")
                                self.selectedBackend = .openAIResponsesAPI
                                self.selectedBackendPreferenceKey = preferenceKey
                                completion(.openAIResponsesAPI, environment, nil)
                                return
                            }
                            SessionDebugLogger.log("backend", "OpenAI API available but lacks official MCP token")
                        } else {
                            SessionDebugLogger.log("backend", "selected direct OpenAI Responses API backend")
                            self.selectedBackend = .openAIResponsesAPI
                            self.selectedBackendPreferenceKey = preferenceKey
                            completion(.openAIResponsesAPI, environment, nil)
                            return
                        }
                    }

                    SessionDebugLogger.log("backend", "no backend available")
                    completion(nil, environment, self.backendSetupMessage(environment: environment))
                }
            }
        }
    }

    func backendPreferenceKey(environment: [String: String]) -> String {
        [
            effectiveArchiveAccessMode(environment: environment).rawValue,
            AppSettings.preferredTransport.rawValue,
            AppSettings.preferredClaudeModel.rawValue,
            AppSettings.preferredCodexModel.rawValue,
            AppSettings.preferredOpenAIModel.rawValue,
            (environment["ANTHROPIC_API_KEY"]?.isEmpty == false) ? "anthropic:1" : "anthropic:0",
            (environment["OPENAI_API_KEY"]?.isEmpty == false) ? "openai:1" : "openai:0",
            (AppSettings.officialLennyMCPToken?.isEmpty == false) ? "mcp-settings:1" : "mcp-settings:0",
            (environment[Constants.lennyMCPAuthEnvVar]?.isEmpty == false) ? "mcp-env:1" : "mcp-env:0"
        ].joined(separator: "|")
    }

    func resolveForcedBackend(_ preferredTransport: AppSettings.PreferredTransport, environment: [String: String], completion: @escaping (Backend?, [String: String], String?) -> Void) {
        let archiveMode = effectiveArchiveAccessMode(environment: environment)

        switch preferredTransport {
        case .automatic:
            completion(nil, environment, nil)
        case .claudeCode:
            resolveClaudeCodeBackend(environment: environment) { backend in
                if let backend {
                    if archiveMode == .officialMCP, !self.backendSupportsOfficialMCP(backend, environment: environment) {
                        completion(nil, environment, "Claude Code is selected in Settings, but the official Lenny MCP is not configured there. Configure it in Claude Code, save a bearer token in Settings, or switch to Starter Pack.")
                        return
                    }
                    SessionDebugLogger.log("backend", "selected forced Claude backend")
                    completion(backend, environment, nil)
                } else {
                    completion(nil, environment, "Claude Code is selected in Settings, but Claude is not configured. Log into Claude Code or set ANTHROPIC_API_KEY.")
                }
            }
        case .codex:
            resolveCodexBackend(environment: environment) { backend in
                if let backend {
                    if archiveMode == .officialMCP, !self.backendSupportsOfficialMCP(backend, environment: environment) {
                        completion(nil, environment, "Codex is selected in Settings, but the official Lenny MCP is not configured there. Configure it in Codex, save a bearer token in Settings, or switch to Starter Pack.")
                        return
                    }
                    SessionDebugLogger.log("backend", "selected forced Codex backend")
                    completion(backend, environment, nil)
                } else {
                    completion(nil, environment, "Codex is selected in Settings, but Codex is not configured. Log into Codex or set OPENAI_API_KEY.")
                }
            }
        case .openAIAPI:
            if let key = environment["OPENAI_API_KEY"], !key.isEmpty {
                if archiveMode == .officialMCP, !self.backendSupportsOfficialMCP(.openAIResponsesAPI, environment: environment) {
                    completion(nil, environment, "Direct OpenAI API is selected in Settings, but official archive mode requires a bearer token. Save one in Settings or switch to Starter Pack.")
                    return
                }
                SessionDebugLogger.log("backend", "selected forced direct OpenAI Responses API backend")
                completion(.openAIResponsesAPI, environment, nil)
            } else {
                completion(nil, environment, "Direct OpenAI API is selected in Settings, but OPENAI_API_KEY is missing.")
            }
        }
    }

    func resolveClaudeCodeBackend(environment: [String: String], completion: @escaping (Backend?) -> Void) {
        guard let executable = executablePath(named: "claude", environment: environment) else {
            SessionDebugLogger.log("backend", "claude executable not found")
            completion(nil)
            return
        }

        if let apiKey = environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty {
            SessionDebugLogger.log("backend", "claude available via ANTHROPIC_API_KEY")
            completion(.claudeCodeCLI(path: executable))
            return
        }

        runProcess(
            executablePath: executable,
            arguments: ["auth", "status"],
            environment: environment,
            workingDirectory: nil
        ) { status, stdout, _ in
            let isLoggedIn = self.isClaudeAuthenticated(exitCode: status, stdout: stdout)
            SessionDebugLogger.log("backend", "claude auth status exitCode=\(status) authenticated=\(isLoggedIn)")
            completion(isLoggedIn ? .claudeCodeCLI(path: executable) : nil)
        }
    }

    func resolveCodexBackend(environment: [String: String], completion: @escaping (Backend?) -> Void) {
        guard let executable = executablePath(named: "codex", environment: environment) else {
            SessionDebugLogger.log("backend", "codex executable not found")
            completion(nil)
            return
        }

        if let apiKey = environment["OPENAI_API_KEY"], !apiKey.isEmpty {
            SessionDebugLogger.log("backend", "codex available via OPENAI_API_KEY")
            completion(.codexCLI(path: executable))
            return
        }

        runProcess(
            executablePath: executable,
            arguments: ["login", "status"],
            environment: environment,
            workingDirectory: nil
        ) { status, stdout, _ in
            let normalized = stdout.lowercased()
            let isLoggedIn = status == 0 && (normalized.contains("logged in") || normalized.contains("chatgpt"))
            SessionDebugLogger.log("backend", "codex login status exitCode=\(status) authenticated=\(isLoggedIn)")
            completion(isLoggedIn ? .codexCLI(path: executable) : nil)
        }
    }

    func executablePath(named name: String, environment: [String: String]) -> String? {
        let rawPath = environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    func isClaudeAuthenticated(exitCode: Int32, stdout: String) -> Bool {
        if let data = stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loggedIn = json["loggedIn"] as? Bool {
            return loggedIn
        }
        return exitCode == 0
    }

    func officialMCPToken(from environment: [String: String]) -> String? {
        if let override = AppSettings.officialLennyMCPToken {
            SessionDebugLogger.log("mcp", "using official MCP token from Settings")
            return override
        }
        if let custom = environment[Constants.lennyMCPAuthEnvVar]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            SessionDebugLogger.log("mcp", "using official MCP token from environment variable \(Constants.lennyMCPAuthEnvVar)")
            return custom
        }
        SessionDebugLogger.log("mcp", "no official MCP token available")
        return nil
    }

    func effectiveArchiveAccessMode(environment: [String: String]) -> AppSettings.ArchiveAccessMode {
        guard AppSettings.archiveAccessMode != .starterPack else {
            return .starterPack
        }

        return hasAnyOfficialMCPConfiguration(environment: environment) ? .officialMCP : .starterPack
    }

    func hasAnyOfficialMCPConfiguration(environment: [String: String]) -> Bool {
        officialMCPToken(from: environment) != nil || AppSettings.hasDetectedOfficialMCPConfiguration
    }

    func backendSupportsOfficialMCP(_ backend: Backend, environment: [String: String]) -> Bool {
        if officialMCPToken(from: environment) != nil {
            return true
        }

        switch backend {
        case .claudeCodeCLI:
            return AppSettings.detectedOfficialMCPSources.contains(.claudeGlobalConfig)
        case .codexCLI:
            return AppSettings.detectedOfficialMCPSources.contains(.codexGlobalConfig)
        case .openAIResponsesAPI:
            return false
        }
    }

    func backendStatusMessage(for backend: Backend, environment: [String: String]? = nil) -> String {
        let archiveMode = environment.map { effectiveArchiveAccessMode(environment: $0) } ?? AppSettings.effectiveArchiveAccessMode
        let archiveLabel = archiveMode == .starterPack
            ? "bundled starter archive"
            : "official Lenny MCP"
        switch backend {
        case .claudeCodeCLI:
            let modelSuffix = selectedClaudeModel().map { " • model: \($0)" } ?? ""
            return "Using Claude Code CLI with \(archiveLabel)\(modelSuffix)"
        case .codexCLI:
            let modelSuffix = selectedCodexModel().map { " • model: \($0)" } ?? ""
            return "Using Codex CLI with \(archiveLabel)\(modelSuffix)"
        case .openAIResponsesAPI:
            return "Using direct OpenAI Responses API with \(archiveLabel) • model: \(selectedOpenAIModel())"
        }
    }

    func backendSetupMessage(environment: [String: String]) -> String {
        let hasOpenAIKey = !(environment["OPENAI_API_KEY"] ?? "").isEmpty
        let hasAnthropicKey = !(environment["ANTHROPIC_API_KEY"] ?? "").isEmpty
        let hasCustomMCPKey = !(environment[Constants.lennyMCPAuthEnvVar] ?? "").isEmpty

        var lines = [
            "No default AI transport is configured yet.",
            "",
            "Current transport preference: `\(AppSettings.preferredTransport.rawValue)`",
            "",
            "Supported transports:",
            "1. Claude Code CLI with `ANTHROPIC_API_KEY` or Claude login",
            "2. Codex CLI with ChatGPT login or `OPENAI_API_KEY`",
            "3. Direct OpenAI API with `OPENAI_API_KEY`",
            "",
            "Free mode uses the bundled starter archive locally.",
            "Official MCP mode requires a global Lenny MCP install in Claude Code or Codex, or your own token via `\(Constants.lennyMCPAuthEnvVar)`."
        ]

        if hasAnthropicKey || hasOpenAIKey || hasCustomMCPKey {
            lines.append("")
            lines.append("Detected in your shell:")
            if hasAnthropicKey { lines.append("- `ANTHROPIC_API_KEY`") }
            if hasOpenAIKey { lines.append("- `OPENAI_API_KEY`") }
            if hasCustomMCPKey { lines.append("- `\(Constants.lennyMCPAuthEnvVar)`") }
        }

        return lines.joined(separator: "\n")
    }
}
