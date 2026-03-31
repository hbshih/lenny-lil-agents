import AppKit
import Foundation

extension TerminalView {
    func queueAttachments(_ attachments: [SessionAttachment]) {
        guard !attachments.isEmpty else { return }

        let newAttachments = attachments.filter { !pendingAttachments.contains($0) }
        guard !newAttachments.isEmpty else { return }

        pendingAttachments.append(contentsOf: newAttachments)
        refreshAttachmentPreviews()
        appendStatus("Queued \(newAttachments.count) attachment\(newAttachments.count == 1 ? "" : "s")")
    }

    func removeAttachment(_ attachment: SessionAttachment) {
        pendingAttachments.removeAll { $0 == attachment }
        refreshAttachmentPreviews()
    }

    func draggedAttachments(from sender: NSDraggingInfo) -> [SessionAttachment] {
        attachments(from: sender.draggingPasteboard)
    }

    func attachments(from pasteboard: NSPasteboard) -> [SessionAttachment] {
        var attachments: [SessionAttachment] = []

        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL] ?? []
        attachments.append(contentsOf: fileURLs.compactMap(SessionAttachment.from(url:)))

        if attachments.isEmpty,
           let remoteURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in remoteURLs where !url.isFileURL {
                if let attachment = createURLAttachment(url) {
                    attachments.append(attachment)
                }
            }
        }

        if attachments.isEmpty,
           let image = NSImage(pasteboard: pasteboard),
           let attachment = createImageAttachment(image) {
            attachments.append(attachment)
        }

        if attachments.isEmpty,
           let rawString = pasteboard.string(forType: .string),
           let attachment = createTextAttachment(rawString, suggestedName: "Dropped Note.txt") {
            attachments.append(attachment)
        }

        return attachments
    }

    func dragContainsSupportedAttachment(from pasteboard: NSPasteboard) -> Bool {
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL],
           fileURLs.contains(where: { SessionAttachment.from(url: $0) != nil }) {
            return true
        }

        if let remoteURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           remoteURLs.contains(where: { !$0.isFileURL }) {
            return true
        }

        if NSImage(pasteboard: pasteboard) != nil {
            return true
        }

        if let rawString = pasteboard.string(forType: .string),
           !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return false
    }

    func createImageAttachment(_ image: NSImage) -> SessionAttachment? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let url = temporaryAttachmentURL(named: "Dropped Image.png")
        do {
            try pngData.write(to: url, options: .atomic)
            return SessionAttachment.from(url: url)
        } catch {
            return nil
        }
    }

    func createTextAttachment(_ text: String, suggestedName: String) -> SessionAttachment? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = temporaryAttachmentURL(named: suggestedName)
        do {
            try trimmed.write(to: url, atomically: true, encoding: .utf8)
            return SessionAttachment.from(url: url)
        } catch {
            return nil
        }
    }

    func createURLAttachment(_ url: URL) -> SessionAttachment? {
        createTextAttachment(url.absoluteString, suggestedName: "Dropped Link.txt")
    }

    func temporaryAttachmentURL(named suggestedName: String) -> URL {
        let cleanedBase = ((suggestedName as NSString).deletingPathExtension)
            .replacingOccurrences(of: "[^A-Za-z0-9 _-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBase = cleanedBase.isEmpty ? "Attachment" : cleanedBase
        let fileExtension = (suggestedName as NSString).pathExtension.isEmpty ? "txt" : (suggestedName as NSString).pathExtension
        let uniqueName = "\(fallbackBase)-\(UUID().uuidString.prefix(8)).\(fileExtension)"
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueName)
    }
}
