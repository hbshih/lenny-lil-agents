import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case models
        case dataAccess
        case advanced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .models: return "Models"
            case .dataAccess: return "Data & Access"
            case .advanced: return "Advanced"
            }
        }

        var icon: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .models: return "cpu"
            case .dataAccess: return "folder.badge.gearshape"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    @State private var selectedTab: SettingsTab = .general
    @State private var workspaceFolderLabel = SettingsView.workspaceFolderDisplayName()

    @AppStorage(AppSettings.preferredTransportKey) private var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true
    @AppStorage(AppSettings.preferredClaudeModelKey) private var preferredClaudeModel = AppSettings.ClaudeModel.default.rawValue
    @AppStorage(AppSettings.preferredCodexModelKey) private var preferredCodexModel = AppSettings.CodexModel.default.rawValue
    @AppStorage(AppSettings.preferredOpenAIModelKey) private var preferredOpenAIModel = AppSettings.OpenAIModel.gpt5Nano.rawValue

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .models:
                        modelsTab
                    case .dataAccess:
                        dataAndAccessTab
                    case .advanced:
                        advancedTab
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 700, height: 560, alignment: .topLeading)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.top, 14)

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .frame(width: 16)
                        Text(tab.title)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()
        }
        .frame(width: 180, alignment: .topLeading)
    }

    private var generalTab: some View {
        Group {
            SettingsSection(icon: "bolt.horizontal.fill", title: "How Lenny Answers") {
                Picker("Transport", selection: $preferredTransport) {
                    Text("Choose automatically").tag(AppSettings.PreferredTransport.automatic.rawValue)
                    Text("Claude Code only").tag(AppSettings.PreferredTransport.claudeCode.rawValue)
                    Text("Codex only").tag(AppSettings.PreferredTransport.codex.rawValue)
                    Text("OpenAI API only").tag(AppSettings.PreferredTransport.openAIAPI.rawValue)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Text("Automatic mode tries Claude Code first, then Codex, then OpenAI API. Pick a fixed transport when you need strict behavior.")
                    .settingsCaption()
                statusLine(text: transportStatusText, icon: transportStatusIcon)
            }

            SettingsSection(icon: "person.text.rectangle.fill", title: "Credits") {
                Text("This app is a fork of Ryan Stephen’s original lil agents project. The original concept and code remain credited under the MIT License.")
                    .settingsCaption()
                Text("Before shipping updates from this fork, publish your signed Sparkle releases to this repository and replace the public update key in `LilAgents/Info.plist` with your own.")
                    .settingsCaption()
            }
        }
    }

    private var modelsTab: some View {
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

            Text("These choices apply only when that transport is active.")
                .settingsCaption()
            statusLine(text: activeModelStatusText, icon: "cpu")
        }
    }

    private var dataAndAccessTab: some View {
        Group {
            SettingsSection(icon: "folder.fill", title: "Workspace Folder Access") {
                Text("Grant one workspace folder so Claude Code and Codex can search or edit local files when a prompt needs it.")
                    .settingsCaption()

                HStack(spacing: 10) {
                    Button("Choose Folder…") {
                        chooseWorkspaceFolder()
                    }
                    .buttonStyle(.borderedProminent)

                    if AppSettings.hasWorkspaceFolderAccess {
                        Button("Clear") {
                            AppSettings.clearWorkspaceFolderAccess()
                            workspaceFolderLabel = Self.workspaceFolderDisplayName()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                statusLine(
                    text: AppSettings.hasWorkspaceFolderAccess
                        ? "Granted: \(workspaceFolderLabel)"
                        : "No folder granted yet. Lenny will ask in chat before showing the system picker.",
                    icon: AppSettings.hasWorkspaceFolderAccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
            }

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
                    Text("A bearer token is saved in Settings, so Lenny will use the official archive even if Starter pack is selected.")
                        .settingsCaption()
                }
            }

            SettingsSection(icon: "key.fill", title: "Official Archive Setup") {
                SecureField("Optional bearer token", text: $officialToken)
                    .textFieldStyle(.roundedBorder)

                Text("Leave this blank if you already set up archive access in Claude Code or Codex.")
                    .settingsCaption()

                SettingsCodeBlock(
                    label: "Claude Code",
                    code: "claude mcp add lennysdata --transport http https://mcp.lennysdata.com/mcp --header \"Authorization: Bearer <your-token>\""
                )
                SettingsCodeBlock(
                    label: "Codex (two steps)",
                    code: "codex mcp add lennysdata --url https://mcp.lennysdata.com/mcp\ncodex mcp login lennysdata"
                )

                HStack {
                    statusLine(text: statusText, icon: statusIcon)
                    Spacer()
                    if !officialToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear Token") { officialToken = "" }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var advancedTab: some View {
        SettingsSection(icon: "ant.fill", title: "Debug Logs") {
            Toggle("Show detailed session logs in Xcode", isOn: $debugLoggingEnabled)
            Text("Includes backend selection, archive mode, MCP setup, CLI arguments, and parsed responses. Sensitive tokens are redacted.")
                .settingsCaption()
        }
    }

    private func statusLine(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose a workspace folder for Claude Code and Codex."
        panel.directoryURL = AppSettings.workspaceFolderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        AppSettings.setWorkspaceFolderURL(url)
        workspaceFolderLabel = Self.workspaceFolderDisplayName()
    }

    private static func workspaceFolderDisplayName() -> String {
        AppSettings.workspaceFolderURL?.path ?? "None"
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
            return "Lenny will use Claude Code only. This requires a Claude login or ANTHROPIC_API_KEY."
        case .codex:
            return "Lenny will use Codex only. This requires a Codex login or OPENAI_API_KEY."
        case .openAIAPI:
            return "Lenny will use OpenAI API only. This requires OPENAI_API_KEY."
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
            return "OpenAI API is set to \(openAI)."
        }
    }

    private var transportStatusIcon: String {
        switch AppSettings.PreferredTransport(rawValue: preferredTransport) ?? .automatic {
        case .automatic: return "arrow.triangle.branch"
        case .claudeCode: return "person.crop.square.fill"
        case .codex: return "terminal.fill"
        case .openAIAPI: return "network.badge.shield.half.filled"
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

private extension Text {
    func settingsCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
