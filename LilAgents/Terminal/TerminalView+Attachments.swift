import AppKit

extension TerminalView {
    func presentAttachmentPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.title = "Add Attachments"
        panel.message = "Choose screenshots, PDFs, or other supported files to send with your question."

        guard panel.runModal() == .OK else { return }
        queueAttachments(panel.urls.compactMap(SessionAttachment.from(url:)))
    }

    func refreshAttachmentLabel() {
        if pendingAttachments.isEmpty {
            attachmentLabel.stringValue = ""
            attachmentLabel.isHidden = true
            relayoutPanels()
            return
        }

        let names = pendingAttachments.map(\.displayName).joined(separator: ", ")
        attachmentLabel.stringValue = "Attached: \(names)"
        attachmentLabel.isHidden = false
        relayoutPanels()
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
        queueAttachments(attachments)
        return true
    }

    private func queueAttachments(_ attachments: [SessionAttachment]) {
        guard !attachments.isEmpty else { return }

        let newAttachments = attachments.filter { !pendingAttachments.contains($0) }
        guard !newAttachments.isEmpty else { return }

        pendingAttachments.append(contentsOf: newAttachments)
        refreshAttachmentLabel()
        appendStatus("Queued \(newAttachments.count) attachment\(newAttachments.count == 1 ? "" : "s")")
    }

    private func draggedAttachments(from sender: NSDraggingInfo) -> [SessionAttachment] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL] ?? []
        return urls.compactMap(SessionAttachment.from(url:))
    }
}
