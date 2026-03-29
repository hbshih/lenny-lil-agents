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

    static let preferredTransportKey = "preferredTransport"
    static let archiveAccessModeKey = "archiveAccessMode"
    static let officialLennyMCPTokenKey = "officialLennyMCPToken"
    static let debugLoggingEnabledKey = "debugLoggingEnabled"
    static let preferredClaudeModelKey = "preferredClaudeModel"
    static let preferredCodexModelKey = "preferredCodexModel"
    static let preferredOpenAIModelKey = "preferredOpenAIModel"
    static let workspaceFolderBookmarkKey = "workspaceFolderBookmark"

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
            let rawValue = UserDefaults.standard.string(forKey: archiveAccessModeKey) ?? ArchiveAccessMode.starterPack.rawValue
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

    static var hasOfficialArchiveConnectionInSettings: Bool {
        officialLennyMCPToken != nil
    }

    static var effectiveArchiveAccessMode: ArchiveAccessMode {
        hasOfficialArchiveConnectionInSettings ? .officialMCP : archiveAccessMode
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

    static var workspaceFolderURL: URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: workspaceFolderBookmarkKey) else {
            return nil
        }

        var stale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }

        if stale {
            setWorkspaceFolderURL(resolvedURL)
        }

        return resolvedURL
    }

    static var hasWorkspaceFolderAccess: Bool {
        workspaceFolderURL != nil
    }

    static func setWorkspaceFolderURL(_ url: URL) {
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }
        UserDefaults.standard.set(bookmarkData, forKey: workspaceFolderBookmarkKey)
    }

    static func clearWorkspaceFolderAccess() {
        UserDefaults.standard.removeObject(forKey: workspaceFolderBookmarkKey)
    }
}
