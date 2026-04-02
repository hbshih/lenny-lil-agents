import Foundation
import UniformTypeIdentifiers

struct SessionAttachment: Equatable {
    enum Kind: Equatable {
        case image
        case document
    }

    let url: URL
    let kind: Kind
    let detail: String

    var displayName: String { url.lastPathComponent }
    var fileExtensionLabel: String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? "FILE" : ext.uppercased()
    }

    static let supportedTextExtensions = Set([
        "md", "markdown", "txt", "rtf", "json", "csv", "tsv", "log",
        "yaml", "yml", "xml", "html", "htm",
        "js", "jsx", "ts", "tsx", "swift", "py", "rb", "go", "rs", "java", "kt",
        "c", "cc", "cpp", "h", "hpp", "m", "mm", "css", "scss", "sql", "sh"
    ])

    static var supportedContentTypes: [UTType] {
        [
            .image,
            .pdf,
            .plainText,
            .utf8PlainText,
            .rtf,
            .commaSeparatedText,
            .json,
            .xml,
            .html,
            .sourceCode
        ]
    }

    static var pickerContentTypes: [UTType] {
        supportedContentTypes.filter { !$0.conforms(to: .image) }
    }

    static func from(url: URL) -> SessionAttachment? {
        let lowercasedExtension = url.pathExtension.lowercased()

        if let type = UTType(filenameExtension: lowercasedExtension) {
            if type.conforms(to: .image) {
                return SessionAttachment(url: url, kind: .image, detail: "Image")
            }
            if type.conforms(to: .pdf) {
                return SessionAttachment(url: url, kind: .document, detail: "PDF")
            }
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) {
                return SessionAttachment(url: url, kind: .document, detail: displayDetail(for: lowercasedExtension, type: type))
            }
        }

        if supportedTextExtensions.contains(lowercasedExtension) {
            return SessionAttachment(url: url, kind: .document, detail: displayDetail(for: lowercasedExtension, type: nil))
        }

        return nil
    }

    static func displayDetail(for lowercasedExtension: String, type: UTType?) -> String {
        switch lowercasedExtension {
        case "csv":
            return "CSV"
        case "tsv":
            return "TSV"
        case "json":
            return "JSON"
        case "md", "markdown":
            return "Markdown"
        case "txt", "":
            return "Text"
        case "pdf":
            return "PDF"
        case "rtf":
            return "RTF"
        case "yaml", "yml":
            return "YAML"
        case "xml":
            return "XML"
        default:
            if type?.conforms(to: .sourceCode) == true {
                return "Code"
            }
            if type?.conforms(to: .image) == true {
                return "Image"
            }
            return lowercasedExtension.isEmpty ? "Document" : lowercasedExtension.uppercased()
        }
    }
}
