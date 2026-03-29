import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.preferredTransportKey) private var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true
    @AppStorage(AppSettings.preferredClaudeModelKey) private var preferredClaudeModel = AppSettings.ClaudeModel.default.rawValue
    @AppStorage(AppSettings.preferredCodexModelKey) private var preferredCodexModel = AppSettings.CodexModel.default.rawValue
    @AppStorage(AppSettings.preferredOpenAIModelKey) private var preferredOpenAIModel = AppSettings.OpenAIModel.gpt5Nano.rawValue

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSection(icon: "bolt.horizontal.fill", title: "How Lenny Answers") {
                    Picker("Transport", selection: $preferredTransport) {
                        Text("Choose automatically")
                            .tag(AppSettings.PreferredTransport.automatic.rawValue)
                        Text("Claude Code")
                            .tag(AppSettings.PreferredTransport.claudeCode.rawValue)
                        Text("Codex")
                            .tag(AppSettings.PreferredTransport.codex.rawValue)
                        Text("OpenAI API")
                            .tag(AppSettings.PreferredTransport.openAIAPI.rawValue)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Automatic mode tries Claude Code first, then Codex, then the OpenAI API. Pick a single transport only if you want to force that path.")
                        .settingsCaption()

                    HStack(alignment: .center) {
                        Label(transportStatusText, systemImage: transportStatusIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                    }
                }

                SettingsSection(icon: "slider.horizontal.3", title: "Model Choices") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledModelPicker(
                            title: "Claude Code",
                            selection: $preferredClaudeModel,
                            options: AppSettings.ClaudeModel.allCases.map { ($0.label, $0.rawValue) }
                        )

                        LabeledModelPicker(
                            title: "Codex",
                            selection: $preferredCodexModel,
                            options: AppSettings.CodexModel.allCases.map { ($0.label, $0.rawValue) }
                        )

                        LabeledModelPicker(
                            title: "OpenAI API",
                            selection: $preferredOpenAIModel,
                            options: AppSettings.OpenAIModel.allCases.map { ($0.label, $0.rawValue) }
                        )
                    }

                    Text("These choices apply only when that transport is active. Claude and Codex use their CLI model flags. OpenAI uses the exact API model shown here.")
                        .settingsCaption()

                    HStack(alignment: .center) {
                        Label(activeModelStatusText, systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                    }
                }

                // Archive Source
                SettingsSection(icon: "archivebox.fill", title: "Archive Access") {
                    Picker("Source", selection: $archiveAccessMode) {
                        Text("Starter pack — local sample archive")
                            .tag(AppSettings.ArchiveAccessMode.starterPack.rawValue)
                        Text("Official Lenny archive")
                            .tag(AppSettings.ArchiveAccessMode.officialMCP.rawValue)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Starter pack searches the bundled archive on your Mac. The official archive uses your own Lenny access through Claude Code, Codex, or a bearer token.")
                        .settingsCaption()

                    if AppSettings.hasOfficialArchiveConnectionInSettings {
                        Text("A bearer token is currently saved in Settings, so Lenny will use the official archive even if Starter pack is selected above.")
                            .settingsCaption()
                    }
                }

                // MCP Configuration
                SettingsSection(icon: "key.fill", title: "Official Archive Setup") {
                    SecureField("Optional bearer token", text: $officialToken)
                        .textFieldStyle(.roundedBorder)

                    Text("Leave this blank if you already set up the archive in Claude Code or Codex. Paste a bearer token only if you want the app to connect directly.")
                        .settingsCaption()

                    VStack(alignment: .leading, spacing: 8) {
                        SettingsCodeBlock(
                            label: "Claude Code",
                            code: "claude mcp add lennysdata --transport http https://mcp.lennysdata.com/mcp --header \"Authorization: Bearer <your-token>\""
                        )
                        SettingsCodeBlock(
                            label: "Codex (two steps)",
                            code: "codex mcp add lennysdata --url https://mcp.lennysdata.com/mcp\ncodex mcp login lennysdata"
                        )
                    }

                    HStack(alignment: .center) {
                        Label(statusText, systemImage: statusIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if !officialToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Clear Token") { officialToken = "" }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                        }
                    }
                }

                // Debug Logging
                SettingsSection(icon: "ant.fill", title: "Debug Logs") {
                    Toggle("Show detailed session logs in Xcode", isOn: $debugLoggingEnabled)

                    Text("Includes backend selection, archive mode, MCP setup, CLI arguments, and parsed responses. Sensitive tokens are redacted.")
                        .settingsCaption()
                }

                SettingsSection(icon: "person.text.rectangle.fill", title: "Credits") {
                    Text("This app is a fork of Ryan Stephen’s original lil agents project. The original concept and code remain credited under the MIT License.")
                        .settingsCaption()

                    Text("Before shipping updates from this fork, publish your signed Sparkle releases to this repository and replace the public update key in `LilAgents/Info.plist` with your own.")
                        .settingsCaption()
                }
            }
            .padding(16)
        }
        .frame(width: 560, alignment: .topLeading)
    }

    private var statusText: String {
        let trimmed = officialToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return "Using the official archive with the saved Settings token"
        }
        if archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue {
            return "Using the starter pack on this device"
        }
        return "Using the official archive through your CLI setup"
    }

    private var statusIcon: String {
        (officialToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue)
            ? "internaldrive.fill" : "network"
    }

    private var transportStatusText: String {
        switch AppSettings.PreferredTransport(rawValue: preferredTransport) ?? .automatic {
        case .automatic:
            return "Lenny will choose Claude Code first, then Codex, then the OpenAI API."
        case .claudeCode:
            return "Lenny will use Claude Code only. This requires a Claude login or `ANTHROPIC_API_KEY`."
        case .codex:
            return "Lenny will use Codex only. This requires a Codex login or `OPENAI_API_KEY`."
        case .openAIAPI:
            return "Lenny will use the OpenAI API only. This requires `OPENAI_API_KEY`."
        }
    }

    private var activeModelStatusText: String {
        let transport = AppSettings.PreferredTransport(rawValue: preferredTransport) ?? .automatic
        let claude = AppSettings.ClaudeModel(rawValue: preferredClaudeModel)?.label ?? "Claude"
        let codex = AppSettings.CodexModel(rawValue: preferredCodexModel)?.label ?? "Codex"
        let openAI = AppSettings.OpenAIModel(rawValue: preferredOpenAIModel)?.label ?? "GPT-5 nano"

        switch transport {
        case .automatic:
            return "Automatic mode is set to Claude: \(claude), Codex: \(codex), OpenAI API: \(openAI)."
        case .claudeCode:
            return "Claude Code is set to \(claude)."
        case .codex:
            return "Codex is set to \(codex)."
        case .openAIAPI:
            return "OpenAI is set to \(openAI)."
        }
    }

    private var transportStatusIcon: String {
        switch AppSettings.PreferredTransport(rawValue: preferredTransport) ?? .automatic {
        case .automatic:
            return "arrow.triangle.branch"
        case .claudeCode:
            return "person.crop.square.fill"
        case .codex:
            return "terminal.fill"
        case .openAIAPI:
            return "network.badge.shield.half.filled"
        }
    }
}

private struct LabeledModelPicker: View {
    let title: String
    @Binding var selection: String
    let options: [(label: String, value: String)]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(width: 100, alignment: .leading)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Reusable section card

private struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.bottom, 2)
        }
    }
}

// MARK: - Code block

private struct SettingsCodeBlock: View {
    let label: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.separator.opacity(0.5), lineWidth: 0.75)
                )
        }
    }
}

// MARK: - Convenience modifier

private extension Text {
    func settingsCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
