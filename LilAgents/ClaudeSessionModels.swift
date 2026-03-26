import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ResponderExpert: Equatable {
    let name: String
    let avatarPath: String
    let archiveContext: String
    let responseScript: String
}

struct SessionAttachment: Equatable {
    enum Kind: Equatable {
        case image
        case document
    }

    let url: URL
    let kind: Kind

    var displayName: String { url.lastPathComponent }

    static func from(url: URL) -> SessionAttachment? {
        let lowercasedExtension = url.pathExtension.lowercased()

        if let type = UTType(filenameExtension: lowercasedExtension) {
            if type.conforms(to: .image) {
                return SessionAttachment(url: url, kind: .image)
            }
            if type.conforms(to: .pdf) || type.conforms(to: .text) {
                return SessionAttachment(url: url, kind: .document)
            }
        }

        let documentExtensions = Set(["md", "markdown", "txt", "rtf", "json", "csv", "log"])
        if documentExtensions.contains(lowercasedExtension) {
            return SessionAttachment(url: url, kind: .document)
        }

        return nil
    }
}

struct ConversationState {
    var previousResponseID: String?
    var history: [ClaudeSession.Message] = []
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
    }
}
