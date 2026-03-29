import AppKit
import Foundation
import PDFKit

extension ClaudeSession {
    func runProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?,
        onLineReceived: ((String) -> Void)? = nil,
        completion: @escaping (Int32, String, String) -> Void
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        SessionDebugLogger.log(
            "process",
            "launching process executable=\(executablePath) args=\(arguments) cwd=\(workingDirectory?.path ?? FileManager.default.currentDirectoryPath)"
        )

        var finalStdout = ""
        var finalStderr = ""
        let queue = DispatchQueue(label: "lenny.runProcess", attributes: .concurrent)

        func processLines(_ string: String) {
            if let onLineReceived {
                let lines = string.components(separatedBy: .newlines)
                for line in lines {
                    let trim = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trim.isEmpty else { continue }
                    DispatchQueue.main.async {
                        onLineReceived(trim)
                    }
                }
            }
        }

        let processStdout: (Data) -> Void = { data in
            guard let string = String(data: data, encoding: .utf8), !string.isEmpty else { return }
            queue.sync(flags: .barrier) { finalStdout += string }
            processLines(string)
        }

        let processStderr: (Data) -> Void = { data in
            guard let string = String(data: data, encoding: .utf8), !string.isEmpty else { return }
            queue.sync(flags: .barrier) { finalStderr += string }
            processLines(string)
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in processStdout(handle.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { handle in processStderr(handle.availableData) }

        process.terminationHandler = { process in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            
            let remainingOut = stdout.fileHandleForReading.readDataToEndOfFile()
            let remainingErr = stderr.fileHandleForReading.readDataToEndOfFile()
            processStdout(remainingOut)
            processStderr(remainingErr)

            queue.sync {
                let outText = finalStdout
                let errText = finalStderr
                DispatchQueue.main.async {
                    completion(process.terminationStatus, outText, errText)
                }
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                completion(-1, "", error.localizedDescription)
            }
        }
    }

    func imageDataURL(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mimeType: String
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            mimeType = "image/jpeg"
        case "gif":
            mimeType = "image/gif"
        case "webp":
            mimeType = "image/webp"
        default:
            mimeType = "image/png"
        }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    func documentText(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url) else { return nil }
            var pages: [String] = []
            for index in 0..<document.pageCount {
                pages.append(document.page(at: index)?.string ?? "")
            }
            return trimmedDocumentText(pages.joined(separator: "\n\n"))
        case "rtf":
            guard let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else { return nil }
            return trimmedDocumentText(attributed.string)
        default:
            return trimmedDocumentText(try? String(contentsOf: url))
        }
    }

    func trimmedDocumentText(_ text: String?) -> String? {
        guard let text else { return nil }
        let compact = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }

        let limit = 12_000
        if compact.count <= limit {
            return compact
        }
        let truncated = compact.prefix(limit)
        return "\(truncated)\n\n[Document truncated for length]"
    }
}
