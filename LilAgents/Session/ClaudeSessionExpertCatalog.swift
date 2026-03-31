import AppKit
import Foundation

extension ClaudeSession {
    func avatarPath(for name: String) -> String? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let directoryURL = resourceURL.appendingPathComponent(Constants.avatarsDirectory, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return genericExpertAvatarPath()
        }

        let target = normalize(name)
        for file in files {
            let stem = file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_pixel_art", with: "")
            if normalize(stem) == target {
                return resolvedAvatarPath(for: file)
            }
        }
        let fallback = genericExpertAvatarPath()
        if fallback != nil {
            SessionDebugLogger.log("experts", "using generic avatar fallback for \(name)")
        }
        return fallback
    }

    func genericExpertAvatarPath() -> String? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let path = resourceURL
            .appendingPathComponent("CharacterSprites", isDirectory: true)
            .appendingPathComponent("main-front.png")
            .path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    func resolvedAvatarPath(for file: URL) -> String {
        if file.pathExtension.lowercased() == "png" {
            return file.path
        }

        if let pngPath = pngAvatarPath(for: file) {
            return pngPath
        }

        return file.path
    }

    func expertNames(fromFreeformText text: String) -> [String] {
        var orderedNames: [String] = []

        func record(_ rawNames: [String]) {
            for rawName in rawNames {
                guard let canonical = canonicalExpertName(for: rawName),
                      !orderedNames.contains(canonical) else { continue }
                orderedNames.append(canonical)
            }
        }

        let structured = structuredExpertSuggestionNames(from: text)
        record(structured)
        if !orderedNames.isEmpty {
            return orderedNames
        }

        let boldMatches = markdownBoldedNames(from: text)
        record(boldMatches)
        if !orderedNames.isEmpty {
            return orderedNames
        }

        let normalizedText = normalize(text)
        for candidateName in knownExpertNames() {
            guard shouldAllowExpertSuggestionName(candidateName) else { continue }
            if normalizedText.contains(normalize(candidateName)), !orderedNames.contains(candidateName) {
                orderedNames.append(candidateName)
            }
        }

        return orderedNames
    }

    func expertsFromAssistantText(_ text: String) -> [ResponderExpert] {
        let candidateNames = expertNames(fromFreeformText: text)
        var experts: [ResponderExpert] = []

        for name in candidateNames {
            guard let avatarPath = avatarPath(for: name),
                  !experts.contains(where: { $0.name == name }) else { continue }

            let context = """
            Mentioned in the latest answer:
            \(String(text.prefix(320)))
            """

            experts.append(ResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: context,
                responseScript: responseScript(for: name, context: context)
            ))
        }

        return Array(experts.prefix(3))
    }

    func expertsFromTransport(payload: Any?, textCandidates: [String]) -> [ResponderExpert] {
        var orderedNames: [String] = []

        func record(_ rawNames: [String]) {
            for rawName in rawNames {
                guard let canonical = canonicalExpertName(for: rawName),
                      !orderedNames.contains(canonical) else { continue }
                orderedNames.append(canonical)
            }
        }

        record(expertNames(in: payload))
        for text in textCandidates where !text.isEmpty {
            record(expertNames(fromFreeformText: text))
        }

        var experts: [ResponderExpert] = []
        for name in orderedNames {
            guard let avatarPath = avatarPath(for: name),
                  !experts.contains(where: { $0.name == name }) else { continue }

            let context = """
            Mentioned during live transport:
            \(textCandidates.joined(separator: "\n").prefix(320))
            """

            experts.append(ResponderExpert(
                name: name,
                avatarPath: avatarPath,
                archiveContext: context,
                responseScript: responseScript(for: name, context: context)
            ))
        }

        return Array(experts.prefix(3))
    }

    func structuredExpertSuggestionNames(from text: String) -> [String] {
        guard let startRange = text.range(of: "<LIL_AGENTS_EXPERTS>"),
              let endRange = text.range(of: "</LIL_AGENTS_EXPERTS>"),
              startRange.upperBound <= endRange.lowerBound else {
            return []
        }

        let block = text[startRange.upperBound..<endRange.lowerBound]
        return block
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^\-\s*"#, with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty && $0.lowercased() != "none" }
    }

    func cleanedAssistantText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(
                of: #"\s*<LIL_AGENTS_EXPERTS>[\s\S]*?</LIL_AGENTS_EXPERTS>\s*"#,
                with: "\n",
                options: .regularExpression
            )

        // Strip structural JSON remnants if the model output malformed JSON chunks
        // e.g. leading `{ "answer_markdown": "`
        cleaned = cleaned.replacingOccurrences(
            of: #"^\s*\{\s*"answer_markdown"\s*:\s*""#,
            with: "",
            options: .regularExpression
        )
        // e.g. trailing `", "suggested_experts": [...] }`
        cleaned = cleaned.replacingOccurrences(
            of: #"\",?\s*"suggested_experts"[\s\S]*$"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\",?\s*"suggest_expert_prompt"[\s\S]*$"#,
            with: "",
            options: .regularExpression
        )

        // Unescape escaped quotes and newlines if it still looks like a JSON string block
        cleaned = cleaned.replacingOccurrences(of: "\\\"", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "\\n", with: "\n")

        // Run a second cleanup pass after unescaping. Some model outputs leak the
        // structured JSON tail as plain text, for example:
        // `", "suggested_experts": [], "suggest_expert_prompt": false }`
        cleaned = cleaned.replacingOccurrences(
            of: #"\n?\s*",?\s*"suggested_experts"\s*:\s*\[[\s\S]*$"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\n?\s*",?\s*"suggest_expert_prompt"\s*:\s*(true|false)[\s\S]*$"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\n?\s*\}\s*$"#,
            with: "",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func markdownBoldedNames(from text: String) -> [String] {
        let pattern = #"\*\*([^*\n]{3,80})\*\*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let candidate = nsText.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return canonicalExpertName(for: candidate)
        }
    }

    func canonicalExpertName(for rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for candidate in knownExpertNames() where normalize(candidate) == normalize(trimmed) {
            return shouldAllowExpertSuggestionName(candidate) ? candidate : nil
        }
        return nil
    }

    func knownExpertNames() -> [String] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let directoryURL = resourceURL.appendingPathComponent(Constants.avatarsDirectory, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.map { file in
            file.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_pixel_art", with: "")
                .replacingOccurrences(of: "-", with: " ")
        }
    }

    func shouldAllowExpertSuggestionName(_ name: String) -> Bool {
        let disallowed = ["Failure"]
        return !disallowed.contains(name)
    }

    func pngAvatarPath(for file: URL) -> String? {
        guard let image = NSImage(contentsOf: file),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lenny-avatar-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let fileName = file.deletingPathExtension().lastPathComponent + ".png"
        let pngURL = cacheDir.appendingPathComponent(fileName)

        if !FileManager.default.fileExists(atPath: pngURL.path) {
            try? pngData.write(to: pngURL)
        }

        return pngURL.path
    }

    func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
}
