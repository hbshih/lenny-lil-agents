import Foundation

extension ClaudeSession {
    func responseScript(for name: String, context: String) -> String {
        """
        Answer in first person as \(name), not as a generic assistant.
        Keep the tone practical and crisp.
        Speak like \(name) is directly answering the question.
        Do not mention the archive, references, MCP, or retrieved evidence in the final answer unless the user explicitly asks.
        Stay close to \(name)'s known domain and, if needed, simply say you are not sure rather than bluffing.
        Relevant references for \(name):
        \(context)
        """
    }

    func flattenOutputStrings(_ output: Any?) -> [String] {
        if let string = output as? String {
            return [string]
        }
        if let array = output as? [[String: Any]] {
            return array.compactMap { $0["text"] as? String }
        }
        if let array = output as? [Any] {
            return array.compactMap { item in
                if let dict = item as? [String: Any] {
                    return dict["text"] as? String
                }
                return item as? String
            }
        }
        if let dict = output as? [String: Any], let text = dict["text"] as? String {
            return [text]
        }
        return []
    }

    func expertNames(in payload: Any?) -> [String] {
        var names: [String] = []

        if let dict = payload as? [String: Any] {
            if let filename = dict["filename"] as? String, let speaker = speakerName(fromFilename: filename) {
                names.append(speaker)
            }
            if let title = dict["title"] as? String, let speaker = speakerName(fromTitle: title) {
                names.append(speaker)
            }
            for value in dict.values {
                names.append(contentsOf: expertNames(in: value))
            }
        } else if let array = payload as? [Any] {
            for item in array {
                names.append(contentsOf: expertNames(in: item))
            }
        } else if let string = payload as? String {
            if let speaker = speakerName(fromFilename: string) {
                names.append(speaker)
            } else if let speaker = speakerName(fromTitle: string) {
                names.append(speaker)
            }
            names.append(contentsOf: expertNames(fromFreeformText: string))
        }

        return names
    }
}
