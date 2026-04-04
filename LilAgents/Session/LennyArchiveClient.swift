import Foundation

enum LennyArchiveClientError: LocalizedError {
    case invalidEndpoint
    case unsupportedResponse
    case invalidPayload
    case httpError(Int, String)
    case serverError(String)
    case missingToolResult

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The Lenny archive endpoint is invalid."
        case .unsupportedResponse:
            return "The Lenny archive returned an unsupported response."
        case .invalidPayload:
            return "The Lenny archive returned malformed data."
        case let .httpError(statusCode, message):
            return message.isEmpty ? "The Lenny archive request failed with HTTP \(statusCode)." : message
        case let .serverError(message):
            return message
        case .missingToolResult:
            return "The Lenny archive returned no tool result."
        }
    }
}

final class LennyArchiveClient {
    private let endpointURL: URL
    private let token: String
    private let urlSession: URLSession
    private let protocolVersion = "2025-03-26"
    private var sessionID: String?
    private var nextRequestID = 1

    init(token: String, endpointURLString: String = ClaudeSession.Constants.lennyMCPURL, urlSession: URLSession = .shared) throws {
        guard let endpointURL = URL(string: endpointURLString) else {
            throw LennyArchiveClientError.invalidEndpoint
        }
        self.endpointURL = endpointURL
        self.token = token
        self.urlSession = urlSession
    }

    func listContent(limit: Int, offset: Int, contentType: String? = nil) async throws -> [String: Any] {
        var arguments: [String: Any] = [
            "limit": limit,
            "offset": offset
        ]
        if let contentType, !contentType.isEmpty {
            arguments["content_type"] = contentType
        }
        return try await callTool(name: "list_content", arguments: arguments)
    }

    func searchContent(query: String, limit: Int, contentType: String? = nil) async throws -> [String: Any] {
        var arguments: [String: Any] = [
            "query": query,
            "limit": limit
        ]
        if let contentType, !contentType.isEmpty {
            arguments["content_type"] = contentType
        }
        return try await callTool(name: "search_content", arguments: arguments)
    }

    func readExcerpt(filename: String, query: String, radius: Int = 700) async throws -> [String: Any] {
        try await callTool(name: "read_excerpt", arguments: [
            "filename": filename,
            "query": query,
            "radius": radius
        ])
    }

    func readContent(filename: String) async throws -> [String: Any] {
        try await callTool(name: "read_content", arguments: [
            "filename": filename
        ])
    }

    private func callTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        try await initializeIfNeeded()
        let payload = try await sendRequest(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": arguments
            ]
        )
        guard let result = payload["result"] as? [String: Any] else {
            throw LennyArchiveClientError.missingToolResult
        }
        return try decodeToolResult(result)
    }

    private func initializeIfNeeded() async throws {
        guard sessionID == nil else { return }

        let response = try await sendRequest(
            method: "initialize",
            params: [
                "protocolVersion": protocolVersion,
                "capabilities": [:],
                "clientInfo": [
                    "name": "Lil-Lenny",
                    "version": "1.0"
                ]
            ]
        )

        if let result = response["result"] as? [String: Any],
           let negotiatedVersion = result["protocolVersion"] as? String,
           !negotiatedVersion.isEmpty {
            SessionDebugLogger.log("archive-http", "initialized archive session protocolVersion=\(negotiatedVersion)")
        }

        _ = try await sendRequest(method: "notifications/initialized", params: nil, includeID: false)
    }

    @discardableResult
    private func sendRequest(method: String, params: [String: Any]?, includeID: Bool = true) async throws -> [String: Any] {
        var requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method
        ]
        if includeID {
            requestBody["id"] = nextRequestID
            nextRequestID += 1
        }
        if let params {
            requestBody["params"] = params
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "MCP-Session-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LennyArchiveClientError.unsupportedResponse
        }

        if let headerSessionID = httpResponse.value(forHTTPHeaderField: "MCP-Session-Id")
            ?? httpResponse.value(forHTTPHeaderField: "Mcp-Session-Id"),
           !headerSessionID.isEmpty {
            sessionID = headerSessionID
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LennyArchiveClientError.httpError(httpResponse.statusCode, message)
        }

        guard let payload = try decodeResponsePayload(data: data, response: httpResponse) else {
            return [:]
        }

        if let error = payload["error"] as? [String: Any] {
            let message = (error["message"] as? String) ?? "The Lenny archive request failed."
            throw LennyArchiveClientError.serverError(message)
        }

        return payload
    }

    private func decodeResponsePayload(data: Data, response: HTTPURLResponse) throws -> [String: Any]? {
        guard !data.isEmpty else { return nil }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("text/event-stream"),
           let string = String(data: data, encoding: .utf8) {
            let dataLines = string
                .components(separatedBy: .newlines)
                .filter { $0.hasPrefix("data:") }
                .map { String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0 != "[DONE]" }

            for line in dataLines.reversed() {
                if let lineData = line.data(using: .utf8),
                   let payload = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] {
                    return payload
                }
            }
            throw LennyArchiveClientError.unsupportedResponse
        }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return payload
        }

        throw LennyArchiveClientError.invalidPayload
    }

    private func decodeToolResult(_ result: [String: Any]) throws -> [String: Any] {
        if let structured = result["structuredContent"] as? [String: Any] {
            return structured
        }

        if let content = result["content"] as? [[String: Any]] {
            let texts = content.compactMap { $0["text"] as? String }.filter { !$0.isEmpty }
            if let first = texts.first,
               let data = first.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }
            if let first = texts.first {
                return ["content": first]
            }
        }

        if let resultValue = result["result"] as? [String: Any] {
            return resultValue
        }

        throw LennyArchiveClientError.missingToolResult
    }
}
