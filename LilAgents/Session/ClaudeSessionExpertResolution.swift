import AppKit
import Foundation

extension ClaudeSession {
    func expertsFromMCPPayloads(arguments: [String: Any], output: Any?) -> [ResponderExpert] {
        var scoredNames: [String: Int] = [:]
        var firstSeenOrder: [String: Int] = [:]
        var expertContexts: [String: [String]] = [:]
        var nextOrder = 0

        func record(_ names: [String], weight: Int) {
            for rawName in names {
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                scoredNames[name, default: 0] += weight
                if firstSeenOrder[name] == nil {
                    firstSeenOrder[name] = nextOrder
                    nextOrder += 1
                }
            }
        }

        record(expertNames(in: arguments), weight: 3)
        record(expertNames(in: output), weight: 3)

        for text in flattenOutputStrings(output) {
            if let data = text.data(using: .utf8),
               let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data) {
                for result in envelope.results {
                    let speakers = speakerNames(from: result)
                    record(speakers, weight: 5)
                    let contextLine = contextLine(from: result)
                    for speaker in speakers where !contextLine.isEmpty {
                        expertContexts[speaker, default: []].append(contextLine)
                    }
                }
            }
        }

        var experts: [ResponderExpert] = []
        let sortedNames = scoredNames.keys.sorted { lhs, rhs in
            let leftScore = scoredNames[lhs] ?? 0
            let rightScore = scoredNames[rhs] ?? 0
            if leftScore != rightScore { return leftScore > rightScore }
            return (firstSeenOrder[lhs] ?? 0) < (firstSeenOrder[rhs] ?? 0)
        }

        for name in sortedNames {
            guard let avatarPath = avatarPath(for: name),
                  !experts.contains(where: { $0.name == name }) else { continue }
            let context = summarizedContext(for: name, lines: expertContexts[name] ?? [])
            experts.append(ResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: context,
                responseScript: responseScript(for: name, context: context)
            ))
        }
        return Array(experts.prefix(3))
    }

    func summarizeMCPOutput(_ output: Any?) -> String {
        let texts = flattenOutputStrings(output)
        for text in texts {
            if let data = text.data(using: .utf8),
               let envelope = try? JSONDecoder().decode(SearchEnvelope.self, from: data) {
                return "Retrieved \(envelope.results.count) archive matches"
            }
        }
        if let first = texts.first, !first.isEmpty {
            return String(first.prefix(80))
        }
        return "MCP call complete"
    }

    func processDisplay(for toolName: String, arguments: [String: Any]) -> (title: String, summary: String) {
        switch toolName {
        case "search_content":
            let query = (arguments["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "the archive"
            return ("Calling MCP Tool", "search_content: \(query)")
        case "read_excerpt":
            let filename = readableSourceName(from: arguments["filename"] as? String)
            let query = (arguments["query"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let query, !query.isEmpty {
                return ("Calling MCP Tool", "read_excerpt: \(filename) for \(query)")
            }
            return ("Calling MCP Tool", "read_excerpt: \(filename)")
        case "read_content":
            let filename = readableSourceName(from: arguments["filename"] as? String)
            return ("Calling MCP Tool", "read_content: \(filename)")
        case "list_content":
            return ("Calling MCP Tool", "list_content: \(summarizeArguments(arguments))")
        default:
            return ("Calling MCP Tool", "\(toolName): \(summarizeArguments(arguments))")
        }
    }

    func processResultDisplay(for toolName: String, arguments: [String: Any], output: Any?) -> String {
        switch toolName {
        case "search_content":
            let base = summarizeMCPOutput(output)
            let experts = expertsFromMCPPayloads(arguments: arguments, output: output).map(\.name)
            if experts.isEmpty {
                return base
            }
            return "\(base) from \(experts.prefix(3).joined(separator: ", "))"
        case "read_excerpt":
            let experts = expertsFromMCPPayloads(arguments: arguments, output: output).map(\.name)
            if let first = experts.first {
                return "Loaded excerpt from \(first)"
            }
            return "Loaded excerpt"
        case "read_content":
            let experts = expertsFromMCPPayloads(arguments: arguments, output: output).map(\.name)
            if let first = experts.first {
                return "Loaded full context for \(first)"
            }
            return "Loaded full article or transcript"
        default:
            return summarizeMCPOutput(output)
        }
    }

    func extractMessageText(from outputItems: [[String: Any]]) -> String? {
        for item in outputItems where item["type"] as? String == "message" {
            let content = item["content"] as? [[String: Any]] ?? []
            let texts = content.compactMap { block -> String? in
                guard block["type"] as? String == "output_text" else { return nil }
                return block["text"] as? String
            }
            if !texts.isEmpty {
                return texts.joined(separator: "\n")
            }
        }
        return nil
    }

    func summarizeArguments(_ arguments: [String: Any]) -> String {
        if let query = arguments["query"] as? String { return query }
        if let filename = arguments["filename"] as? String { return readableSourceName(from: filename) }
        return arguments.keys.sorted().prefix(3).joined(separator: ", ")
    }

    func readableSourceName(from filename: String?) -> String {
        guard let filename, !filename.isEmpty else { return "archive source" }
        let last = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        if last.isEmpty { return filename }
        return last
            .split(separator: "-")
            .map { chunk in
                let word = chunk.replacingOccurrences(of: "_", with: " ")
                if word.count <= 3 {
                    return word.uppercased()
                }
                return word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    func speakerNames(from result: SearchResult) -> [String] {
        var speakers: [String] = []

        if let speaker = speakerName(fromFilename: result.filename) {
            speakers.append(speaker)
        }

        if let speaker = speakerName(fromTitle: result.title) {
            speakers.append(speaker)
        }

        let snippet = result.snippet ?? result.snippets?.first?.text ?? ""
        if let match = snippet.range(of: "\\*by ([^*]+)\\*", options: .regularExpression) {
            let byline = String(snippet[match])
                .replacingOccurrences(of: "*by ", with: "")
                .replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !byline.isEmpty {
                speakers.append(byline)
            }
        }

        if let match = snippet.range(of: "\\*\\*([^*]+)\\*\\* \\(", options: .regularExpression) {
            let speaker = String(snippet[match])
                .replacingOccurrences(of: "**", with: "")
                .components(separatedBy: " (").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let speaker, !speaker.isEmpty {
                speakers.append(speaker)
            }
        }

        var unique: [String] = []
        for speaker in speakers where !unique.contains(speaker) {
            unique.append(speaker)
        }
        return unique
    }

    func speakerName(fromTitle title: String) -> String? {
        if let pipeRange = title.range(of: "|") {
            let trailing = title[pipeRange.upperBound...]
            let trimmed = trailing.split(separator: "(").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return trimmed
            }
        }

        if let onRange = title.range(of: " on ") {
            let leading = String(title[..<onRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if leading.split(separator: " ").count <= 4, !leading.isEmpty {
                return leading
            }
        }

        return nil
    }

    func speakerName(fromFilename filename: String) -> String? {
        guard filename.contains("podcasts/") else { return nil }
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        guard !stem.isEmpty else { return nil }

        return stem
            .split(separator: "-")
            .map { part in
                let lower = part.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    func contextLine(from result: SearchResult) -> String {
        let rawSnippet = result.snippet ?? result.snippets?.first?.text ?? ""
        let compactSnippet = rawSnippet
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = String(compactSnippet.prefix(220))
        let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if snippet.isEmpty {
            return "- \(title) (\(result.date))"
        }
        return "- \(title) (\(result.date)): \(snippet)"
    }

    func summarizedContext(for name: String, lines: [String]) -> String {
        var unique: [String] = []
        for line in lines where !line.isEmpty && !unique.contains(line) {
            unique.append(line)
        }

        if unique.isEmpty {
            return "Use the Lenny archive tools to continue grounding follow-up answers for \(name)."
        }

        return Array(unique.prefix(3)).joined(separator: "\n")
    }
}
