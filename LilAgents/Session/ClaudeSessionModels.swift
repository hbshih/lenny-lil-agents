import AppKit
import Foundation
import PDFKit

struct ResponderExpert: Equatable {
    let name: String
    let avatarPath: String
    let archiveContext: String
    let responseScript: String
}

enum TranscriptSpeakerKind: String, Codable, Equatable {
    case lenny
    case expert
    case status
    case assistant
    case system
}

enum TranscriptMessageActionKind: String, Codable, Equatable {
    case copy
    case followUp
}

struct TranscriptMessageAction: Codable, Equatable {
    let kind: TranscriptMessageActionKind
    let label: String
    let expertName: String?

    init(kind: TranscriptMessageActionKind, label: String, expertName: String? = nil) {
        self.kind = kind
        self.label = label
        self.expertName = expertName
    }
}

struct TranscriptSpeakerMessage: Codable, Equatable {
    let speakerName: String
    let kind: TranscriptSpeakerKind
    let markdown: String
    let actions: [TranscriptMessageAction]
    let isProvisional: Bool
    let avatarHint: String?
    let copyable: Bool
    let followUpExpertName: String?

    init(
        speakerName: String,
        kind: TranscriptSpeakerKind,
        markdown: String,
        actions: [TranscriptMessageAction] = [],
        isProvisional: Bool = false,
        avatarHint: String? = nil,
        copyable: Bool = true,
        followUpExpertName: String? = nil
    ) {
        self.speakerName = speakerName
        self.kind = kind
        self.markdown = markdown
        self.actions = actions
        self.isProvisional = isProvisional
        self.avatarHint = avatarHint
        self.copyable = copyable
        self.followUpExpertName = followUpExpertName
    }

    var resolvedSpeakerName: String {
        let trimmed = speakerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch kind {
        case .lenny:
            return "Lil-Lenny"
        case .expert:
            return followUpExpertName ?? "Expert"
        case .status:
            return "Status"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        }
    }
}

struct StructuredAssistantResponse: Codable, Equatable {
    let messages: [TranscriptSpeakerMessage]
    let suggestedExperts: [String]
    let suggestExpertPrompt: Bool
    let legacyAnswerMarkdown: String?

    init(
        messages: [TranscriptSpeakerMessage],
        suggestedExperts: [String] = [],
        suggestExpertPrompt: Bool = false,
        legacyAnswerMarkdown: String? = nil
    ) {
        self.messages = messages
        self.suggestedExperts = suggestedExperts
        self.suggestExpertPrompt = suggestExpertPrompt
        self.legacyAnswerMarkdown = legacyAnswerMarkdown
    }

    var resolvedSuggestedExperts: [String] {
        let explicit = suggestedExperts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !explicit.isEmpty {
            return explicit
        }

        var inferred: [String] = []
        for message in messages where message.kind == .expert {
            let candidate = message.followUpExpertName ?? message.resolvedSpeakerName
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !inferred.contains(trimmed) {
                inferred.append(trimmed)
            }
        }
        return inferred
    }

    var resolvedSuggestExpertPrompt: Bool {
        suggestExpertPrompt || !resolvedSuggestedExperts.isEmpty || messages.contains(where: { $0.kind == .expert && !$0.resolvedSpeakerName.isEmpty })
    }

    var renderedMarkdown: String {
        let visibleMessages = messages.filter { $0.kind != .status || !$0.isProvisional }
        let blocks: [String]

        if visibleMessages.count <= 1 {
            if let first = visibleMessages.first {
                return first.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return legacyAnswerMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        blocks = visibleMessages.map { message in
            let speaker = message.resolvedSpeakerName
            let body = message.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty {
                return "**\(speaker)**"
            }
            return "**\(speaker)**\n\n\(body)"
        }

        return blocks.joined(separator: "\n\n")
    }

    var primaryMarkdown: String {
        if let first = messages.first {
            return first.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return legacyAnswerMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct ConversationState {
    var previousResponseID: String?
    var history: [ClaudeSession.Message] = []
    var expertSuggestionEntries: [ExpertSuggestionEntry] = []
}

struct TranscriptSpeaker: Equatable {
    enum Kind: Equatable {
        case lenny
        case expert
        case user
        case system
    }

    let name: String
    let avatarPath: String?
    let kind: Kind
}

struct AssistantSegment: Equatable {
    let speaker: TranscriptSpeaker
    let markdown: String
    let followUpExpert: ResponderExpert?
}

struct ExpertSuggestionEntry: Equatable {
    let id: UUID
    let anchorHistoryCount: Int
    let experts: [ResponderExpert]
    var pickedExpert: ResponderExpert?
    var isCollapsed: Bool

    init(
        id: UUID = UUID(),
        anchorHistoryCount: Int,
        experts: [ResponderExpert],
        pickedExpert: ResponderExpert? = nil,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.anchorHistoryCount = anchorHistoryCount
        self.experts = experts
        self.pickedExpert = pickedExpert
        self.isCollapsed = isCollapsed
    }
}

struct SearchEnvelope: Decodable {
    let results: [SearchResult]
}

struct SearchResult: Decodable {
    let title: String
    let filename: String
    let type: String
    let date: String
    let snippet: String?
    let snippets: [Snippet]?
}

struct Snippet: Decodable {
    let text: String
}

extension ClaudeSession {
    struct Message: Equatable {
        enum Role { case user, assistant, error, toolUse, toolResult }
        let role: Role
        let text: String
        var speaker: TranscriptSpeaker? = nil
        var followUpExpert: ResponderExpert? = nil
    }
}
