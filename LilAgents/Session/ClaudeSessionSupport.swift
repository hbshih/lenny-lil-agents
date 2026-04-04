import AppKit
import Foundation
import PDFKit

extension ClaudeSession {
    func runProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?,
        stdinApprovalCount: Int = 0,
        onLineReceived: ((String) -> Void)? = nil,
        completion: @escaping (Int32, String, String) -> Void
    ) {
        let process = Process()
        currentProcess = process
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

        // Pre-fill stdin with approval responses so permission prompts from
        // non-interactive CLIs (e.g. Codex MCP tool approval) get auto-answered.
        if stdinApprovalCount > 0 {
            let stdin = Pipe()
            process.standardInput = stdin
            let responses = Data(Array(repeating: "1\n", count: stdinApprovalCount).joined().utf8)
            stdin.fileHandleForWriting.write(responses)
            stdin.fileHandleForWriting.closeFile()
        }

        SessionDebugLogger.log(
            "process",
            "launching process executable=\(executablePath) args=\(arguments) cwd=\(workingDirectory?.path ?? FileManager.default.currentDirectoryPath)"
        )

        var finalStdout = ""
        var finalStderr = ""
        let queue = DispatchQueue(label: "lenny.runProcess", attributes: .concurrent)
        var stdoutLineBuffer = ""
        var stderrLineBuffer = ""

        func consumeBufferedLines(_ string: String, buffer: inout String, flush: Bool = false) -> [String] {
            buffer += string
            let segments = buffer.components(separatedBy: .newlines)
            let completed: [String]

            if flush {
                completed = segments
                buffer = ""
            } else {
                completed = Array(segments.dropLast())
                buffer = segments.last ?? ""
            }

            return completed.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }

        let processStdout: (Data) -> Void = { data in
            guard let string = String(data: data, encoding: .utf8), !string.isEmpty else { return }
            let linesToEmit: [String] = queue.sync(flags: .barrier) {
                finalStdout += string
                return consumeBufferedLines(string, buffer: &stdoutLineBuffer)
            }
            if let onLineReceived {
                for line in linesToEmit {
                    DispatchQueue.main.async {
                        onLineReceived(line)
                    }
                }
            }
        }

        let processStderr: (Data) -> Void = { data in
            guard let string = String(data: data, encoding: .utf8), !string.isEmpty else { return }
            let linesToEmit: [String] = queue.sync(flags: .barrier) {
                finalStderr += string
                return consumeBufferedLines(string, buffer: &stderrLineBuffer)
            }
            if let onLineReceived {
                for line in linesToEmit {
                    DispatchQueue.main.async {
                        onLineReceived(line)
                    }
                }
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { handle in processStdout(handle.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { handle in processStderr(handle.availableData) }

        process.terminationHandler = { process in
            DispatchQueue.main.async { [weak self] in
                if self?.currentProcess === process {
                    self?.currentProcess = nil
                }
            }
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            
            let remainingOut = stdout.fileHandleForReading.readDataToEndOfFile()
            let remainingErr = stderr.fileHandleForReading.readDataToEndOfFile()
            processStdout(remainingOut)
            processStderr(remainingErr)

            queue.sync {
                let bufferedLines = consumeBufferedLines("", buffer: &stdoutLineBuffer, flush: true)
                    + consumeBufferedLines("", buffer: &stderrLineBuffer, flush: true)
                let outText = finalStdout
                let errText = finalStderr
                DispatchQueue.main.async {
                    if let onLineReceived {
                        for line in bufferedLines {
                            onLineReceived(line)
                        }
                    }
                    completion(process.terminationStatus, outText, errText)
                }
            }
        }

        do {
            try process.run()
        } catch {
            currentProcess = nil
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
