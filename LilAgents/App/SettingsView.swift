import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.preferredTransportKey) private var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSection(icon: "bolt.horizontal.fill", title: "AI Transport") {
                    Picker("Transport", selection: $preferredTransport) {
                        Text("Auto select")
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

                    Text("Auto select prefers Claude Code first, then Codex, then direct OpenAI API fallback. Choose a specific transport to force that path instead.")
                        .settingsCaption()

                    HStack(alignment: .center) {
                        Label(transportStatusText, systemImage: transportStatusIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                    }
                }

                // Archive Source
                SettingsSection(icon: "archivebox.fill", title: "Archive Source") {
                    Picker("Source", selection: $archiveAccessMode) {
                        Text("Starter pack  —  local free search")
                            .tag(AppSettings.ArchiveAccessMode.starterPack.rawValue)
                        Text("Official Lenny MCP")
                            .tag(AppSettings.ArchiveAccessMode.officialMCP.rawValue)
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Starter pack searches the bundled free archive locally on device. Official MCP uses your own Lenny access through Claude Code or Codex.")
                        .settingsCaption()
                }

                // MCP Configuration
                SettingsSection(icon: "key.fill", title: "Official MCP") {
                    SecureField("Optional bearer token", text: $officialToken)
                        .textFieldStyle(.roundedBorder)

                    Text("Leave blank to use your CLI MCP configuration. Paste your bearer token here to let the app inject the official MCP server directly.")
                        .settingsCaption()

                    VStack(alignment: .leading, spacing: 8) {
                        SettingsCodeBlock(
                            label: "Claude Code",
                            code: "claude mcp add lennysdata --transport http https://mcp.lennysdata.com/mcp --header \"Authorization: Bearer <your-token>\""
                        )
                        SettingsCodeBlock(
                            label: "Codex  (two steps)",
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
                            Button("Clear token") { officialToken = "" }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                        }
                    }
                }

                // Debug Logging
                SettingsSection(icon: "ant.fill", title: "Debug Logging") {
                    Toggle("Print verbose session logs to the Xcode console", isOn: $debugLoggingEnabled)

                    Text("Logs backend selection, archive mode, MCP setup, CLI arguments, and parsed responses. Sensitive tokens are redacted in all output.")
                        .settingsCaption()
                }
            }
            .padding(16)
        }
        .frame(width: 560, alignment: .topLeading)
    }

    private var statusText: String {
        let trimmed = officialToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue {
            return "Using bundled starter pack"
        }
        return trimmed.isEmpty ? "Official MCP via CLI config" : "Official MCP with bearer token"
    }

    private var statusIcon: String {
        archiveAccessMode == AppSettings.ArchiveAccessMode.starterPack.rawValue
            ? "internaldrive.fill" : "network"
    }

    private var transportStatusText: String {
        switch AppSettings.PreferredTransport(rawValue: preferredTransport) ?? .automatic {
        case .automatic:
            return "Default transport: auto-select Claude, then Codex, then OpenAI API."
        case .claudeCode:
            return "Default transport: Claude Code only. Requires Claude login or ANTHROPIC_API_KEY."
        case .codex:
            return "Default transport: Codex only. Requires Codex login or OPENAI_API_KEY."
        case .openAIAPI:
            return "Default transport: direct OpenAI Responses API only. Requires OPENAI_API_KEY."
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
