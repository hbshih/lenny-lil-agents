import Foundation

struct LocalArchiveEntry: Decodable {
    let title: String
    let filename: String
    let wordCount: Int
    let date: String
    let subtitle: String?
    let description: String?
    let guest: String?

    enum CodingKeys: String, CodingKey {
        case title
        case filename
        case wordCount = "word_count"
        case date
        case subtitle
        case description
        case guest
    }

    var typeLabel: String {
        filename.hasPrefix("podcasts/") ? "podcast" : "newsletter"
    }
}

struct LocalArchiveIndexFile: Decodable {
    let podcasts: [LocalArchiveEntry]
    let newsletters: [LocalArchiveEntry]
}

struct LocalArchiveSearchMatch {
    let entry: LocalArchiveEntry
    let excerpt: String
    let score: Int
}

final class LocalArchive {
    static let shared = LocalArchive()

    private(set) var entries: [LocalArchiveEntry] = []
    private var resourceRoot: URL?
    private var contentCache: [String: String] = [:]
    private var isLoaded = false

    private init() {}

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        guard let root = Bundle.main.resourceURL?.appendingPathComponent("StarterArchive", isDirectory: true),
              let indexData = try? Data(contentsOf: root.appendingPathComponent("index.json")) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode(LocalArchiveIndexFile.self, from: indexData)
            entries = decoded.podcasts + decoded.newsletters
            resourceRoot = root
        } catch {
            entries = []
            resourceRoot = nil
        }
    }

    func search(query: String, limit: Int = 5) -> [LocalArchiveSearchMatch] {
        loadIfNeeded()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let normalizedQuery = normalize(trimmedQuery)
        let tokens = queryTokens(from: trimmedQuery)
        guard !tokens.isEmpty else { return [] }

        var matches: [LocalArchiveSearchMatch] = []
        for entry in entries {
            let content = contentForEntry(entry)
            let score = score(entry: entry, content: content, normalizedQuery: normalizedQuery, tokens: tokens)
            guard score > 0 else { continue }
            let excerpt = excerptForEntry(entry, content: content, query: trimmedQuery, tokens: tokens)
            matches.append(LocalArchiveSearchMatch(entry: entry, excerpt: excerpt, score: score))
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.entry.date > rhs.entry.date
            }
            .prefix(limit)
            .map { $0 }
    }

    func contentForEntry(_ entry: LocalArchiveEntry) -> String {
        if let cached = contentCache[entry.filename] {
            return cached
        }

        guard let root = resourceRoot else { return "" }
        let url = root.appendingPathComponent(entry.filename)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        contentCache[entry.filename] = content
        return content
    }

    private func score(entry: LocalArchiveEntry, content: String, normalizedQuery: String, tokens: [String]) -> Int {
        let title = entry.title.lowercased()
        let subtitle = (entry.subtitle ?? "").lowercased()
        let description = (entry.description ?? "").lowercased()
        let guest = (entry.guest ?? "").lowercased()
        let lowerContent = content.lowercased()

        var score = 0
        if title.contains(normalizedQuery) || guest.contains(normalizedQuery) {
            score += 80
        }
        if subtitle.contains(normalizedQuery) || description.contains(normalizedQuery) {
            score += 45
        }

        for token in tokens {
            if title.contains(token) { score += 14 }
            if guest.contains(token) { score += 18 }
            if subtitle.contains(token) { score += 8 }
            if description.contains(token) { score += 6 }
            if lowerContent.contains(token) { score += 2 }
        }

        return score
    }

    private func excerptForEntry(_ entry: LocalArchiveEntry, content: String, query: String, tokens: [String]) -> String {
        let lines = content.components(separatedBy: "\n")
        let lowerTokens = [query.lowercased()] + tokens

        for line in lines {
            let lower = line.lowercased()
            if lowerTokens.contains(where: { !$0.isEmpty && lower.contains($0) }) {
                let compact = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !compact.isEmpty {
                    return String(compact.prefix(240))
                }
            }
        }

        let compact = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(compact.prefix(240))
    }

    private func queryTokens(from query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
