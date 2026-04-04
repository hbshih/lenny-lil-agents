import Foundation

final class ClaudeSession {
    enum Constants {
        static let openAIEndpoint = URL(string: "https://api.openai.com/v1/responses")!
        static let requestTimeout: TimeInterval = 120
        static let lennyMCPURL = "https://mcp.lennysdata.com/mcp"
        static let lennyMCPServerLabel = "lennysdata"
        static let lennyMCPAuthEnvVar = "LENNYSDATA_MCP_AUTH_TOKEN"
        static let lennyToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzY29wZSI6Im1jcDpyZWFkIGFyY2hpdmU6ZnVsbCIsInRpZXIiOiJlbGlnaWJsZSIsImNsaWVudF9pZCI6Imxlbm55c2RhdGEtcGVyc29uYWwiLCJraW5kIjoicGVyc29uYWwiLCJyZXNvdXJjZSI6Imh0dHBzOi8vbWNwLmxlbm55c2RhdGEuY29tL21jcCIsInZlciI6MywiaXNzIjoiaHR0cHM6Ly93d3cubGVubnlzZGF0YS5jb20vIiwic3ViIjoiaGJzaGloQGdtYWlsLmNvbSIsImF1ZCI6Imh0dHBzOi8vbWNwLmxlbm55c2RhdGEuY29tL21jcCIsImlhdCI6MTc3NDQ3OTQwNSwiZXhwIjoxNzc3MDcxNDA1fQ.GL2l1xbWvq4lPcyr2gyXSoTlR0EWFKLek-fUigzZwac"
        static let lennyAllowedTools = ["search_content", "read_excerpt", "read_content", "list_content"]
        static let avatarsDirectory = "ExpertAvatars"
    }

    enum Backend: Equatable {
        case claudeCodeCLI(path: String)
        case codexCLI(path: String)
        case openAIResponsesAPI
    }

    var isRunning = false
    var isBusy = false
    var conversations: [String: ConversationState] = [:]
    var focusedExpert: ResponderExpert?
    var selectedBackend: Backend?
    var selectedBackendPreferenceKey: String?
    var pendingExperts: [ResponderExpert] = []
    var livePresenceExperts: [ResponderExpert] = []
    var liveToolCallsByID: [String: (name: String, arguments: [String: Any])] = [:]
    var assistantExplicitlyRequestedExperts = false
    var currentProcess: Process?
    var currentDataTask: URLSessionDataTask?
    var isCancellingTurn = false

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onSetupRequired: ((String) -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?
    var onExpertsUpdated: (([ResponderExpert]) -> Void)?

    static var shellEnvironment: [String: String]?
    static var openAIKey: String?

    func selectedClaudeModel() -> String? {
        let model = AppSettings.preferredClaudeModel
        return model == .default ? nil : model.rawValue
    }

    func selectedClaudeModelLabel() -> String {
        AppSettings.preferredClaudeModel.label
    }

    func selectedCodexModel() -> String? {
        let model = AppSettings.preferredCodexModel
        return model == .default ? nil : model.rawValue
    }

    func selectedCodexModelLabel() -> String {
        AppSettings.preferredCodexModel.label
    }

    func selectedOpenAIModel() -> String {
        AppSettings.preferredOpenAIModel.rawValue
    }

    func selectedOpenAIModelLabel() -> String {
        AppSettings.preferredOpenAIModel.label
    }
}
