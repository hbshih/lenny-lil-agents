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
        case settingsToken
        case codexGlobalConfig
        case claudeGlobalConfig

        var label: String {
            switch self {
            case .settingsToken:
                return "saved token"
            case .codexGlobalConfig:
                return "Codex"
            case .claudeGlobalConfig:
                return "Claude Code"
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

        if officialLennyMCPToken != nil {
            sources.append(.settingsToken)
        }
        if containsOfficialMCPConfiguration(at: homeDirectoryURL.appendingPathComponent(".codex/config.toml")) {
            sources.append(.codexGlobalConfig)
        }
        if claudeGlobalConfigURLs.contains(where: containsOfficialMCPConfiguration(at:)) {
            sources.append(.claudeGlobalConfig)
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

    private static var claudeGlobalConfigURLs: [URL] {
        [
            homeDirectoryURL.appendingPathComponent(".claude.json"),
            homeDirectoryURL.appendingPathComponent(".claude/settings.json"),
            homeDirectoryURL.appendingPathComponent(".claude/settings.local.json")
        ]
    }

    private static func containsOfficialMCPConfiguration(at url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }

        let lowered = contents.lowercased()
        return lowered.contains("lennysdata") && lowered.contains(ClaudeSession.Constants.lennyMCPURL.lowercased())
    }
}
