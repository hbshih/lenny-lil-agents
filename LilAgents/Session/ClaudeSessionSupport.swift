import AppKit
import Foundation
import PDFKit

extension ClaudeSession {
    func runProcess(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL?,
        wantsInteractiveInput: Bool = false,
        onLineReceived: ((String) -> Void)? = nil,
        completion: @escaping (Int32, String, String) -> Void
    ) {
        let process = Process()
        currentProcess = process
        currentProcessStdin = nil
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

        if wantsInteractiveInput {
            let stdin = Pipe()
            process.standardInput = stdin
            currentProcessStdin = stdin.fileHandleForWriting
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
                    self?.currentProcessStdin = nil
                }
                self?.clearPendingApprovalRequest()
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
            currentProcessStdin = nil
            DispatchQueue.main.async {
                self.clearPendingApprovalRequest()
                completion(-1, "", error.localizedDescription)
            }
        }
    }

    func handleApprovalPromptLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let prefix = "Allow the "
        let infix = " MCP server to run tool \""
        let suffix = "\"?"

        if trimmed.hasPrefix(prefix),
           let toolStart = trimmed.range(of: infix),
           let toolEnd = trimmed.range(of: suffix, range: toolStart.upperBound..<trimmed.endIndex) {
            let serverStart = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let serverName = String(trimmed[serverStart..<toolStart.lowerBound])
            let toolName = String(trimmed[toolStart.upperBound..<toolEnd.lowerBound])
            pendingApprovalRequest = ApprovalRequest(serverName: serverName, toolName: toolName)
            if let pendingApprovalRequest {
                onApprovalRequested?(pendingApprovalRequest)
            }
            SessionDebugLogger.log("approval", "prompted for \(serverName).\(toolName)")
            return true
        }

        guard var request = pendingApprovalRequest else { return false }

        if trimmed.hasPrefix("Field ") ||
            trimmed.hasPrefix("› ") ||
            trimmed.hasPrefix("1. Allow") ||
            trimmed.hasPrefix("2. Allow for this session") ||
            trimmed.hasPrefix("3. Always allow") ||
            trimmed.hasPrefix("4. Cancel") ||
            trimmed.lowercased().contains("enter to submit") {
            return true
        }

        if trimmed.contains(":"),
           let colonIndex = trimmed.firstIndex(of: ":"),
           colonIndex != trimmed.startIndex {
            let key = trimmed[..<colonIndex]
            if key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) {
                if !request.details.contains(trimmed) {
                    request.details.append(trimmed)
                    request.details = Array(request.details.prefix(2))
                    pendingApprovalRequest = request
                    onApprovalRequested?(request)
                }
                return true
            }
        }

        return false
    }

    func submitApprovalChoice(_ choice: ApprovalChoice) {
        guard let currentProcessStdin else { return }
        let payload = Data((choice.rawValue + "\n").utf8)
        currentProcessStdin.write(payload)
        SessionDebugLogger.log("approval", "submitted choice \(choice.rawValue)")
        clearPendingApprovalRequest()
    }

    func clearPendingApprovalRequest() {
        pendingApprovalRequest = nil
        onApprovalCleared?()
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
