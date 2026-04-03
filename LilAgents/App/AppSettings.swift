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

        var label: String {
            switch self {
            case .claudeGlobalConfig:
                return "Claude Code"
            case .codexGlobalConfig:
                return "Codex"
            case .settingsToken:
                return "saved token"
            }
        }
    }

    static let preferredTransportKey = "preferredTransport"
    static let archiveAccessModeKey = "archiveAccessMode"
    static let officialLennyMCPTokenKey = "officialLennyMCPToken"
    static let debugLoggingEnabledKey = "debugLoggingEnabled"
    static let preferredClaudeModelKey = "preferredClaudeModel"
    static let preferredCodexModelKey = "preferredCodexModel"
    static let preferredOpenAIModelKey = "preferredOpenAIModel"
    static let welcomePreviewModeKey = "welcomePreviewMode"

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
            let rawValue = UserDefaults.standard.string(forKey: archiveAccessModeKey) ?? ArchiveAccessMode.officialMCP.rawValue
            return ArchiveAccessMode(rawValue: rawValue) ?? .starterPack
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: archiveAccessModeKey)
        }
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

    static var effectiveArchiveAccessMode: ArchiveAccessMode {
        guard archiveAccessMode != .starterPack else { return .starterPack }
        return detectedOfficialMCPSources.isEmpty ? .starterPack : .officialMCP
    }

    static var detectedOfficialMCPSources: [OfficialMCPSource] {
        var sources: [OfficialMCPSource] = []

        if claudeGlobalConfigURLs.contains(where: containsOfficialMCPConfiguration(at:)) {
            sources.append(.claudeGlobalConfig)
        }
        if containsOfficialMCPConfiguration(at: codexGlobalConfigURL) {
            sources.append(.codexGlobalConfig)
        }
        if officialLennyMCPToken != nil {
            sources.append(.settingsToken)
        }

        return sources
    }

    static var hasDetectedOfficialMCPConfiguration: Bool {
        !detectedOfficialMCPSources.isEmpty
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
        return lowered.contains("lennysdata") && lowered.contains(ClaudeSession.Constants.lennyMCPURL.lowercased())
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
                return "Paste the auth key from lennydata.com first."
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
            if AppSettings.containsOfficialMCPConfiguration(at: AppSettings.codexGlobalConfigURL) {
                preservedTargets.append(.codex)
            } else {
                try installCodexConfig()
                updatedTargets.append(.codex)
            }
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
            hint = "No Claude Code or Codex detected yet."
        case (_, 2):
            hint = "Detected Claude Code and Codex. Existing MCP setup will be kept."
        case (_, 1):
            hint = "Detected \(naturalList(detectedTargets.map(\.label))). Existing MCP setup will be kept."
        default:
            hint = "Detected \(naturalList(detectedTargets.map(\.label))). Lil-Lenny will configure what is missing."
        }

        SessionDebugLogger.log("mcp-install", "context=compact hint | hint=\(hint)")
        return hint
    }

    private static func installCodexConfig() throws {
        let configURL = AppSettings.codexGlobalConfigURL
        let configDirectory = configURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        } catch {
            throw InstallError.unableToCreateConfigDirectory(InstallTarget.codex.label)
        }

        let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = mergedCodexConfig(existing)
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

    private static func mergedCodexConfig(_ existing: String) -> String {
        let desiredBlock = """
        [mcp_servers.\(serverLabel)]
        url = "\(mcpURL)"
        bearer_token_env_var = "\(tokenEnvVar)"
        """

        let normalized = existing.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = #"(?ms)^\[mcp_servers\.lennysdata\]\n.*?(?=^\[|\z)"#

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
