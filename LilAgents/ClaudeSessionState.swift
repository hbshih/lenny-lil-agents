extension ClaudeSession {
    var history: [Message] { history(for: focusedExpert) }

    func history(for expert: ResponderExpert?) -> [Message] {
        conversations[key(for: expert)]?.history ?? []
    }

    func key(for expert: ResponderExpert?) -> String {
        if let expert {
            return "expert:\(normalize(expert.name))"
        }
        return "lenny"
    }

    func appendHistory(_ message: Message, to key: String) {
        var state = conversations[key] ?? ConversationState()
        state.history.append(message)
        conversations[key] = state
    }

    func finishTurn() {
        isBusy = false
        onTurnComplete?()
    }

    func failTurn(_ text: String) {
        failTurn(text, conversationKey: key(for: focusedExpert))
    }

    func failTurn(_ text: String, conversationKey: String) {
        isBusy = false
        appendHistory(Message(role: .error, text: text), to: conversationKey)
        onError?(text)
        onTurnComplete?()
    }
}
