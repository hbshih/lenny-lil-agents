import Foundation

enum SessionDebugLogger {
    static func log(_ category: String, _ message: String) {
        guard AppSettings.debugLoggingEnabled else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[LilAgents][\(timestamp)][\(category)] \(redactSensitiveValues(in: message))")
    }

    static func logMultiline(_ category: String, header: String, body: String) {
        guard AppSettings.debugLoggingEnabled else { return }
        log(category, "\(header)\n\(body)")
    }

    static func summarizeEnvironment(_ environment: [String: String]) -> String {
        let interestingKeys = [
            "PATH",
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            ClaudeSession.Constants.lennyMCPAuthEnvVar
        ]

        return interestingKeys.map { key in
            let value = environment[key]
            switch key {
            case "PATH":
                return "\(key)=\(value?.isEmpty == false ? "<present>" : "<missing>")"
            default:
                return "\(key)=\(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "<present>" : "<missing>")"
            }
        }.joined(separator: ", ")
    }

    static func summarizeAttachments(_ attachments: [SessionAttachment]) -> String {
        guard !attachments.isEmpty else { return "none" }
        return attachments.map { "\($0.displayName) [\($0.kind)]" }.joined(separator: ", ")
    }

    private static func redactSensitiveValues(in text: String) -> String {
        let patterns = [
            #"Bearer\s+[A-Za-z0-9\-\._~\+\/=]+"#,
            #""Authorization"\s*:\s*"Bearer\s+[A-Za-z0-9\-\._~\+\/=]+""#,
            #""officialLennyMCPToken"\s*:\s*"[^"]+""#
        ]

        return patterns.reduce(text) { partial, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return partial
            }
            let range = NSRange(partial.startIndex..<partial.endIndex, in: partial)
            return regex.stringByReplacingMatches(in: partial, options: [], range: range, withTemplate: "Bearer <redacted>")
        }
    }
}
