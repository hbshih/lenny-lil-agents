import Foundation

enum AppSettings {
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
}
