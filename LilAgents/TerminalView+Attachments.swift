import AppKit

extension TerminalView {
    func refreshAttachmentLabel() {
        if pendingAttachments.isEmpty {
            attachmentLabel.stringValue = ""
            attachmentLabel.isHidden = true
            return
        }

        let names = pendingAttachments.map(\.displayName).joined(separator: ", ")
        attachmentLabel.stringValue = "Attached: \(names)"
        attachmentLabel.isHidden = false
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedAttachments(from: sender).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedAttachments(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let attachments = draggedAttachments(from: sender)
        guard !attachments.isEmpty else { return false }

        for attachment in attachments where !pendingAttachments.contains(attachment) {
            pendingAttachments.append(attachment)
        }

        refreshAttachmentLabel()
        appendStatus("Queued \(attachments.count) attachment\(attachments.count == 1 ? "" : "s")")
        return true
    }

    private func draggedAttachments(from sender: NSDraggingInfo) -> [SessionAttachment] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL] ?? []
        return urls.compactMap(SessionAttachment.from(url:))
    }
}
