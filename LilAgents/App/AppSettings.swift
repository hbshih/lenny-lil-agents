import Foundation

enum AppSettings {
    enum ClaudeModel: String, CaseIterable {
        case `default`
        case sonnet
        case opus
        case haiku
        case sonnet1M = "sonnet[1m]"
        case opusPlan = "opusplan"

        var label: String {
            switch self {
            case .default: return "Claude"
            case .sonnet: return "Claude Sonnet"
            case .opus: return "Claude Opus"
            case .haiku: return "Claude Haiku"
            case .sonnet1M: return "Claude Sonnet 1M"
            case .opusPlan: return "Claude Opus Plan"
            }
        }
    }

    enum OpenAIModel: String, CaseIterable {
        case gpt5 = "gpt-5"
        case gpt5Mini = "gpt-5-mini"
        case gpt5Nano = "gpt-5-nano"
        case o3 = "o3"
        case o3Mini = "o3-mini"

        var label: String {
            switch self {
            case .gpt5: return "GPT-5"
            case .gpt5Mini: return "GPT-5 mini"
            case .gpt5Nano: return "GPT-5 nano"
            case .o3: return "o3"
            case .o3Mini: return "o3-mini"
            }
        }
    }

    enum CodexModel: String, CaseIterable {
        case `default`
        case gpt5 = "gpt-5"
        case gpt5Mini = "gpt-5-mini"
        case gpt5Nano = "gpt-5-nano"
        case o3 = "o3"
        case o3Mini = "o3-mini"

        var label: String {
            switch self {
            case .default: return "Codex"
            case .gpt5: return "GPT-5"
            case .gpt5Mini: return "GPT-5 mini"
            case .gpt5Nano: return "GPT-5 nano"
            case .o3: return "o3"
            case .o3Mini: return "o3-mini"
            }
        }
    }

    enum PreferredTransport: String {
        case automatic
        case claudeCode
        case codex
        case openAIAPI
    }

    enum ArchiveAccessMode: String {
        case starterPack
        case officialMCP
    }

    enum WelcomePreviewMode: String, CaseIterable {
        case live
        case starterPackWithBanner
        case starterPackConnected
        case officialConnected

        var label: String {
            switch self {
            case .live:
                return "Live behavior"
            case .starterPackWithBanner:
                return "Starter Pack + banner"
            case .starterPackConnected:
                return "Starter Pack, already connected"
            case .officialConnected:
                return "Official MCP connected"
            }
        }
    }

    enum OfficialMCPSource: String, CaseIterable {
        case claudeGlobalConfig
        case codexGlobalConfig
        case settingsToken
        case environmentToken

        var label: String {
            switch self {
            case .claudeGlobalConfig:
                return "Claude Code"
            case .codexGlobalConfig:
                return "Codex"
            case .settingsToken:
                return "saved token"
            case .environmentToken:
                return "shell token"
            }
        }
    }

    static let preferredTransportKey = "preferredTransport"
    static let archiveAccessModeKey = "archiveAccessMode"
    static let officialLennyMCPTokenKey = "officialLennyMCPToken"
    static let openAIAPIKeyKey = "openAIAPIKey"
    static let debugLoggingEnabledKey = "debugLoggingEnabled"
    static let preferredClaudeModelKey = "preferredClaudeModel"
    static let preferredCodexModelKey = "preferredCodexModel"
    static let preferredOpenAIModelKey = "preferredOpenAIModel"
    static let welcomePreviewModeKey = "welcomePreviewMode"
    private static let shellEnvironmentMCPTokenKey = "LENNYSDATA_MCP_AUTH_TOKEN"

    private static var cachedShellEnvironment: [String: String]?

    static var preferredTransport: PreferredTransport {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredTransportKey) ?? PreferredTransport.automatic.rawValue
            return PreferredTransport(rawValue: rawValue) ?? .automatic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredTransportKey)
        }
    }

    static var archiveAccessMode: ArchiveAccessMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: archiveAccessModeKey) ?? defaultArchiveAccessMode.rawValue
            return ArchiveAccessMode(rawValue: rawValue) ?? .starterPack
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: archiveAccessModeKey)
        }
    }

    static var hasStoredArchiveAccessModePreference: Bool {
        UserDefaults.standard.object(forKey: archiveAccessModeKey) != nil
    }

    static var officialLennyMCPToken: String? {
        get {
            let value = UserDefaults.standard.string(forKey: officialLennyMCPTokenKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: officialLennyMCPTokenKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: officialLennyMCPTokenKey)
            }
        }
    }

    static var openAIAPIKey: String? {
        get {
            let value = UserDefaults.standard.string(forKey: openAIAPIKeyKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: openAIAPIKeyKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: openAIAPIKeyKey)
            }
        }
    }

    static var effectiveArchiveAccessMode: ArchiveAccessMode {
        guard archiveAccessMode != .starterPack else { return .starterPack }
        return detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var defaultArchiveAccessMode: ArchiveAccessMode {
        detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var detectedOfficialMCPSources: [OfficialMCPSource] {
        var sources: [OfficialMCPSource] = []

        if claudeGlobalConfigURLs.contains(where: containsOfficialMCPConfiguration(at:)) {
            sources.append(.claudeGlobalConfig)
        }
        if hasDetectedCodexOfficialMCPConfiguration {
            sources.append(.codexGlobalConfig)
        }
        if officialLennyMCPToken != nil {
            sources.append(.settingsToken)
        }
        if shellEnvironmentOfficialMCPToken() != nil {
            sources.append(.environmentToken)
        }

        return sources
    }

    static var hasDetectedOfficialMCPConfiguration: Bool {
        !detectedOfficialMCPSources.isEmpty
    }

    static var hasDetectedCodexLogin: Bool {
        guard let executable = executablePathForDetection(named: "codex") else { return false }
        if hasDetectedOpenAIAPIKey {
            return true
        }
        let result = runCommand(executablePath: executable, arguments: ["login", "status"])
        guard result.status == 0 else { return false }

        let output = "\(result.stdout)\n\(result.stderr)".lowercased()
        if output.contains("not logged in") || output.contains("login required") {
            return false
        }
        if output.contains("logged in") || output.contains("chatgpt") {
            return true
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var hasDetectedClaudeLogin: Bool {
        guard let executable = executablePathForDetection(named: "claude") else { return false }
        if hasDetectedAnthropicAPIKey {
            return true
        }
        let result = runCommand(executablePath: executable, arguments: ["auth", "status"])
        if let data = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let loggedIn = json["loggedIn"] as? Bool {
            return loggedIn
        }
        let output = "\(result.stdout)\n\(result.stderr)".lowercased()
        if output.contains("not logged in") || output.contains("login required") {
            return false
        }
        return result.status == 0
    }

    static func refreshDetectionState() {
        cachedShellEnvironment = nil
    }

    static var hasDetectedOpenAIAPIKey: Bool {
        if let key = openAIAPIKey, !key.isEmpty {
            return true
        }
        let envValue = resolveShellEnvironment()["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return envValue?.isEmpty == false
    }

    static var hasDetectedAnthropicAPIKey: Bool {
        let envValue = resolveShellEnvironment()["ANTHROPIC_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return envValue?.isEmpty == false
    }

    static var hasDetectedCodexOfficialMCPConfiguration: Bool {
        if containsOfficialMCPConfiguration(at: codexGlobalConfigURL) {
            return true
        }

        guard let executable = executablePathForDetection(named: "codex") else { return false }
        let result = runCommand(executablePath: executable, arguments: ["mcp", "list", "--json"])
        guard result.status == 0 else { return false }

        let combinedOutput = "\(result.stdout)\n\(result.stderr)".lowercased()
        if combinedOutput.contains("\"name\":\"lennysdata\"") || combinedOutput.contains("\"lennysdata\"") {
            return true
        }
        return combinedOutput.contains("lennysdata") && combinedOutput.contains(ClaudeSession.Constants.lennyMCPURL.lowercased())
    }

    static var debugLoggingEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: debugLoggingEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: debugLoggingEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: debugLoggingEnabledKey)
        }
    }

    static var preferredClaudeModel: ClaudeModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredClaudeModelKey) ?? ClaudeModel.default.rawValue
            return ClaudeModel(rawValue: rawValue) ?? .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredClaudeModelKey)
        }
    }

    static var preferredCodexModel: CodexModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredCodexModelKey) ?? CodexModel.default.rawValue
            return CodexModel(rawValue: rawValue) ?? .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredCodexModelKey)
        }
    }

    static var preferredOpenAIModel: OpenAIModel {
        get {
            let rawValue = UserDefaults.standard.string(forKey: preferredOpenAIModelKey) ?? OpenAIModel.gpt5Nano.rawValue
            return OpenAIModel(rawValue: rawValue) ?? .gpt5Nano
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredOpenAIModelKey)
        }
    }

    static var welcomePreviewMode: WelcomePreviewMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: welcomePreviewModeKey) ?? WelcomePreviewMode.live.rawValue
            return WelcomePreviewMode(rawValue: rawValue) ?? .live
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: welcomePreviewModeKey)
        }
    }

    static func resetAllData() throws {
        let defaults = UserDefaults.standard
        let managedKeys = [
            preferredTransportKey,
            archiveAccessModeKey,
            officialLennyMCPTokenKey,
            openAIAPIKeyKey,
            debugLoggingEnabledKey,
            preferredClaudeModelKey,
            preferredCodexModelKey,
            preferredOpenAIModelKey,
            welcomePreviewModeKey,
            "hasCompletedOnboarding"
        ]

        for key in managedKeys {
            defaults.removeObject(forKey: key)
        }

        try removeOfficialMCPConfiguration()
        refreshDetectionState()
        NotificationCenter.default.post(name: .lilLennyDidResetData, object: nil)
    }

    private static let officialMCPMarkers = [
        "https://mcp.lennysdata.com/mcp",
        "lennysdata"
    ]

    private static var homeDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var claudeGlobalConfigURLs: [URL] {
        [
            homeDirectoryURL.appendingPathComponent(".claude.json"),
            homeDirectoryURL.appendingPathComponent(".claude/settings.json"),
            homeDirectoryURL.appendingPathComponent(".claude/settings.local.json")
        ]
    }

    static var codexGlobalConfigURL: URL {
        homeDirectoryURL.appendingPathComponent(".codex/config.toml")
    }

    static func containsOfficialMCPConfiguration(at url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }

        let lowered = contents.lowercased()
        return officialMCPMarkers.allSatisfy { lowered.contains($0.lowercased()) }
    }

    private static func shellEnvironmentOfficialMCPToken() -> String? {
        let environment = resolveShellEnvironment()
        let token = environment[shellEnvironmentMCPTokenKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (token?.isEmpty == false) ? token : nil
    }

    private static func removeOfficialMCPConfiguration() throws {
        for url in claudeGlobalConfigURLs {
            try removeClaudeOfficialMCPConfiguration(at: url)
        }
        try removeCodexOfficialMCPConfiguration(at: codexGlobalConfigURL)
    }

    private static func removeClaudeOfficialMCPConfiguration(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let existingData = try Data(contentsOf: url)
        var root = (try JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
        guard var mcpServers = root["mcpServers"] as? [String: Any] else { return }

        mcpServers.removeValue(forKey: ClaudeSession.Constants.lennyMCPServerLabel)
        if mcpServers.isEmpty {
            root.removeValue(forKey: "mcpServers")
        } else {
            root["mcpServers"] = mcpServers
        }

        try writeJSONObject(root, to: url)
    }

    private static func removeCodexOfficialMCPConfiguration(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let existing = try String(contentsOf: url, encoding: .utf8)
        let normalized = existing.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = #"(?ms)^\[mcp_servers\.lennysdata(?:\..+)?\]\n.*?(?=^\[(?!mcp_servers\.lennysdata(?:[.\]]|$)).*|\z)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let cleaned = regex.stringByReplacingMatches(in: normalized, options: [], range: range, withTemplate: "")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        try writeTextConfig(cleaned.hasSuffix("\n") ? cleaned : cleaned + "\n", to: url)
    }

    private static func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        if object.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: [.atomic])
    }

    private static func writeTextConfig(_ contents: String, to url: URL) throws {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }

        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func resolveShellEnvironment() -> [String: String] {
        if let cachedShellEnvironment {
            return cachedShellEnvironment
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let stdout = Pipe()
        proc.standardOutput = stdout
        proc.standardError = Pipe()

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            cachedShellEnvironment = [:]
            return [:]
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
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

        cachedShellEnvironment = environment
        return environment
    }

    private static func executablePathForDetection(named name: String) -> String? {
        if let rawPath = ProcessInfo.processInfo.environment["PATH"],
           let path = executablePathForDetection(named: name, rawPath: rawPath) {
            return path
        }

        let fallbackPaths: [String]
        let home = homeDirectoryURL.path
        switch name {
        case "claude":
            fallbackPaths = [
                "\(home)/.local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
        case "codex":
            fallbackPaths = [
                "\(home)/.local/bin/codex",
                "\(home)/.nvm/versions/node/current/bin/codex",
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex"
            ]
        default:
            fallbackPaths = []
        }

        if let path = fallbackPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }

        return executablePathFromLoginShellForDetection(named: name)
    }

    private static func executablePathForDetection(named name: String, rawPath: String) -> String? {
        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func executablePathFromLoginShellForDetection(named name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v \(name)"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty == false) ? output : nil
    }

    private static func runCommand(executablePath: String, arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, "", error.localizedDescription)
        }

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, out, err)
    }
}

enum OfficialMCPInstaller {
    struct InstallResult {
        let updatedTargets: [InstallTarget]
        let preservedTargets: [InstallTarget]
        let storedTokenOnly: Bool
    }

    enum InstallTarget: String, CaseIterable {
        case claude
        case codex

        var label: String {
            switch self {
            case .claude: return "Claude Code"
            case .codex: return "Codex"
            }
        }
    }

    enum InstallError: LocalizedError {
        case emptyToken
        case unableToCreateConfigDirectory(String)
        case unableToWriteConfig(String)

        var errorDescription: String? {
            switch self {
            case .emptyToken:
                return "Paste the auth key from lennysdata.com first."
            case let .unableToCreateConfigDirectory(label):
                return "Couldn’t create the local \(label) config folder."
            case let .unableToWriteConfig(label):
                return "Couldn’t update the local \(label) MCP config."
            }
        }
    }

    static let serverLabel = ClaudeSession.Constants.lennyMCPServerLabel
    static let mcpURL = ClaudeSession.Constants.lennyMCPURL
    static let tokenEnvVar = ClaudeSession.Constants.lennyMCPAuthEnvVar

    static func install(token: String) throws -> InstallResult {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstallError.emptyToken }

        logInstallTargetDiagnostics(context: "before install")

        AppSettings.officialLennyMCPToken = trimmed
        AppSettings.archiveAccessMode = .officialMCP

        let availableTargets = detectedInstallTargets()
        var updatedTargets: [InstallTarget] = []
        var preservedTargets: [InstallTarget] = []

        if availableTargets.contains(.claude) {
            if AppSettings.claudeGlobalConfigURLs.contains(where: AppSettings.containsOfficialMCPConfiguration(at:)) {
                preservedTargets.append(.claude)
            } else {
                try installClaudeConfig(token: trimmed)
                updatedTargets.append(.claude)
            }
        }

        if availableTargets.contains(.codex) {
            try installCodexConfig(token: trimmed)
            updatedTargets.append(.codex)
        }

        let result = InstallResult(
            updatedTargets: updatedTargets,
            preservedTargets: preservedTargets,
            storedTokenOnly: availableTargets.isEmpty
        )
        SessionDebugLogger.log(
            "mcp-install",
            "install result updated=\(availableTargetsDescription(updatedTargets)) preserved=\(availableTargetsDescription(preservedTargets)) storedTokenOnly=\(result.storedTokenOnly)"
        )
        logInstallTargetDiagnostics(context: "after install")
        return result
    }

    static func detectedInstallTargets() -> [InstallTarget] {
        var targets: [InstallTarget] = []
        for target in InstallTarget.allCases {
            if isTargetInstalledOrConfigured(target) {
                targets.append(target)
            }
        }
        return targets
    }

    static func installTargetStatusSummary() -> String {
        let detectedTargets = detectedInstallTargets()
        let configuredTargets = connectedTargets()

        let summary: String
        switch (detectedTargets.count, configuredTargets.count) {
        case (0, _):
            summary = "No Claude Code or Codex install was detected yet. Lil-Lenny will still save the key locally for later."
        case (_, 2):
            summary = "Claude Code and Codex are already detected. Lil-Lenny will keep any existing LennyData MCP setup and prefer Claude Code first when both are available."
        case (_, 1):
            let detectedLabels = naturalList(detectedTargets.map(\.label))
            let configuredLabels = naturalList(configuredTargets.map(\.label))
            summary = "\(detectedLabels) \(detectedTargets.count == 1 ? "is" : "are") detected. Lil-Lenny will keep the existing LennyData MCP in \(configuredLabels) and configure the other detected client locally if needed."
        default:
            summary = "Lil-Lenny will detect Claude Code and Codex on this Mac, keep any existing LennyData MCP setup, and configure whichever detected clients still need it."
        }
        logInstallTargetDiagnostics(context: "status summary", summary: summary)
        return summary
    }

    static func compactInstallTargetHint() -> String {
        let detectedTargets = detectedInstallTargets()
        let configuredTargets = connectedTargets()

        let hint: String
        switch (detectedTargets.count, configuredTargets.count) {
        case (0, _):
            hint = "No Claude Code or Codex found yet."
        case (_, 2):
            hint = "Claude Code and Codex are ready. Existing setup stays in place."
        case (_, 1):
            hint = "\(naturalList(detectedTargets.map(\.label))) detected. Existing setup stays in place."
        default:
            hint = "\(naturalList(detectedTargets.map(\.label))) detected. Lil-Lenny will configure what is missing."
        }

        SessionDebugLogger.log("mcp-install", "context=compact hint | hint=\(hint)")
        return hint
    }

    private static func installCodexConfig(token: String) throws {
        let configURL = AppSettings.codexGlobalConfigURL
        let configDirectory = configURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            throw InstallError.unableToCreateConfigDirectory(InstallTarget.codex.label)
        }

        let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = mergedCodexConfig(existing, token: token)
        do {
            try updated.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            throw InstallError.unableToWriteConfig(InstallTarget.codex.label)
        }
    }

    private static func installClaudeConfig(token: String) throws {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.local.json")
        let configDirectory = configURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            throw InstallError.unableToCreateConfigDirectory(InstallTarget.claude.label)
        }

        let existingData = (try? Data(contentsOf: configURL)) ?? Data("{}".utf8)
        var root = (try? JSONSerialization.jsonObject(with: existingData) as? [String: Any]) ?? [:]
        var mcpServers = root["mcpServers"] as? [String: Any] ?? [:]
        mcpServers[serverLabel] = [
            "type": "http",
            "url": mcpURL,
            "headers": [
                "Authorization": "Bearer \(token)"
            ]
        ]
        root["mcpServers"] = mcpServers

        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configURL, options: [.atomic])
        } catch {
            throw InstallError.unableToWriteConfig(InstallTarget.claude.label)
        }
    }

    private static func mergedCodexConfig(_ existing: String, token: String) -> String {
        let desiredBlock = """
        [mcp_servers.\(serverLabel)]
        url = "\(mcpURL)"
        [mcp_servers.\(serverLabel).http_headers]
        Authorization = "Bearer \(token)"
        """

        let normalized = existing.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = #"(?ms)^\[mcp_servers\.lennysdata(?:\..+)?\]\n.*?(?=^\[(?!mcp_servers\.lennysdata(?:[.\]]|$)).*|\z)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            if regex.firstMatch(in: normalized, options: [], range: range) != nil {
                let replaced = regex.stringByReplacingMatches(
                    in: normalized,
                    options: [],
                    range: range,
                    withTemplate: desiredBlock + "\n\n"
                )
                return tidyConfig(replaced)
            }
        }

        let separator = normalized.isEmpty ? "" : (normalized.hasSuffix("\n\n") ? "" : (normalized.hasSuffix("\n") ? "\n" : "\n\n"))
        return tidyConfig(normalized + separator + desiredBlock + "\n")
    }

    private static func tidyConfig(_ contents: String) -> String {
        let squashed = contents.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return squashed.hasSuffix("\n") ? squashed : squashed + "\n"
    }

    private static func connectedTargets() -> [InstallTarget] {
        var targets: [InstallTarget] = []
        if AppSettings.claudeGlobalConfigURLs.contains(where: AppSettings.containsOfficialMCPConfiguration(at:)) {
            targets.append(.claude)
        }
        if AppSettings.containsOfficialMCPConfiguration(at: AppSettings.codexGlobalConfigURL) {
            targets.append(.codex)
        }
        return targets
    }

    private static func isTargetInstalledOrConfigured(_ target: InstallTarget) -> Bool {
        if isTargetConfigured(target) {
            return true
        }
        if executablePath(for: target) != nil {
            return true
        }

        let fileManager = FileManager.default
        switch target {
        case .claude:
            return fileManager.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path) ||
                fileManager.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json").path)
        case .codex:
            return fileManager.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path) ||
                fileManager.fileExists(atPath: AppSettings.codexGlobalConfigURL.path)
        }
    }

    private static func isTargetConfigured(_ target: InstallTarget) -> Bool {
        switch target {
        case .claude:
            return AppSettings.claudeGlobalConfigURLs.contains(where: AppSettings.containsOfficialMCPConfiguration(at:))
        case .codex:
            return AppSettings.containsOfficialMCPConfiguration(at: AppSettings.codexGlobalConfigURL)
        }
    }

    private static func executablePath(for target: InstallTarget) -> String? {
        if let fromProcess = executablePath(named: target.executableName, rawPath: ProcessInfo.processInfo.environment["PATH"] ?? "") {
            return fromProcess
        }

        for candidate in target.fallbackExecutablePaths {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return executablePathFromLoginShell(named: target.executableName)
    }

    private static func executablePath(named name: String, rawPath: String) -> String? {
        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func executablePathFromLoginShell(named name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "command -v \(name)"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (output?.isEmpty == false) ? output : nil
    }

    private static func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return "\(items.dropLast().joined(separator: ", ")), and \(items.last ?? "")"
        }
    }

    private static func availableTargetsDescription(_ targets: [InstallTarget]) -> String {
        let labels = targets.map(\.label)
        return labels.isEmpty ? "none" : naturalList(labels)
    }

    private static func logInstallTargetDiagnostics(context: String, summary: String? = nil) {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let claudeExecutable = executablePath(for: .claude) ?? "missing"
        let codexExecutable = executablePath(for: .codex) ?? "missing"
        let claudeRootExists = fileManager.fileExists(atPath: home.appendingPathComponent(".claude").path)
        let claudeJSONExists = fileManager.fileExists(atPath: home.appendingPathComponent(".claude.json").path)
        let codexRootExists = fileManager.fileExists(atPath: home.appendingPathComponent(".codex").path)
        let codexConfigExists = fileManager.fileExists(atPath: AppSettings.codexGlobalConfigURL.path)
        let detectedTargets = detectedInstallTargets()
        let configuredTargets = connectedTargets()

        var details: [String] = [
            "context=\(context)",
            "claudeExecutable=\(claudeExecutable)",
            "codexExecutable=\(codexExecutable)",
            "claudeRootExists=\(claudeRootExists)",
            "claudeJSONExists=\(claudeJSONExists)",
            "codexRootExists=\(codexRootExists)",
            "codexConfigExists=\(codexConfigExists)",
            "detectedTargets=\(availableTargetsDescription(detectedTargets))",
            "configuredTargets=\(availableTargetsDescription(configuredTargets))"
        ]

        if let summary {
            details.append("summary=\(summary)")
        }

        SessionDebugLogger.log("mcp-install", details.joined(separator: " | "))
    }
}

private extension OfficialMCPInstaller.InstallTarget {
    var executableName: String {
        switch self {
        case .claude:
            return "claude"
        case .codex:
            return "codex"
        }
    }

    var fallbackExecutablePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .claude:
            return [
                "\(home)/.local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
        case .codex:
            return [
                "\(home)/.local/bin/codex",
                "\(home)/.nvm/versions/node/current/bin/codex",
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex"
            ]
        }
    }
}

extension Notification.Name {
    static let lilLennyDidResetData = Notification.Name("LilLennyDidResetData")
}
