import AppKit
import Combine
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case source
    case models
    case about
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: return "Lenny source"
        case .models: return "Models"
        case .about: return "About"
        case .developer: return "Developer"
        }
    }

    var subtitle: String {
        switch self {
        case .source: return "Starter Pack or Full LennyData"
        case .models: return "Runtime and model choices"
        case .about: return "Credits and release notes"
        case .developer: return "Logs and preview states"
        }
    }

    var icon: String {
        switch self {
        case .source: return "books.vertical.fill"
        case .models: return "cpu.fill"
        case .about: return "person.text.rectangle.fill"
        case .developer: return "wrench.and.screwdriver.fill"
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppSettings.preferredTransportKey) private var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) private var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) private var officialToken = ""
    @AppStorage(AppSettings.openAIAPIKeyKey) private var openAIAPIKey = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) private var debugLoggingEnabled = true
    @AppStorage(AppSettings.preferredClaudeModelKey) private var preferredClaudeModel = AppSettings.ClaudeModel.default.rawValue
    @AppStorage(AppSettings.preferredCodexModelKey) private var preferredCodexModel = AppSettings.CodexModel.default.rawValue
    @AppStorage(AppSettings.preferredOpenAIModelKey) private var preferredOpenAIModel = AppSettings.OpenAIModel.gpt5Nano.rawValue
    @AppStorage(AppSettings.welcomePreviewModeKey) private var welcomePreviewMode = AppSettings.WelcomePreviewMode.live.rawValue

    @State private var selectedPane: SettingsPane = .source
    @State private var showResetConfirmation = false
    @State private var resetErrorMessage: String?

    private let officialArchiveURL = URL(string: "https://www.lennysdata.com")!

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                ForEach(visiblePanes) { pane in
                    SettingsSidebarRow(
                        pane: pane,
                        isSelected: selectedPane == pane,
                        action: { selectedPane = pane }
                    )
                    .tag(pane)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 250)
        } detail: {
            ScrollView(.vertical, showsIndicators: false) {
                currentPaneView
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Settings")
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 840, idealWidth: 920, minHeight: 620, idealHeight: 700)
        .onAppear {
            AppSettings.refreshDetectionState()
            guard !AppSettings.hasStoredArchiveAccessModePreference else { return }
            archiveAccessMode = AppSettings.defaultArchiveAccessMode.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            AppSettings.refreshDetectionState()
            guard !AppSettings.hasStoredArchiveAccessModePreference else { return }
            archiveAccessMode = AppSettings.defaultArchiveAccessMode.rawValue
        }
        .onChange(of: debugLoggingEnabled) { _, enabled in
            if !enabled && selectedPane == .developer {
                selectedPane = .source
            }
        }
        .alert("Reset Lil-Lenny data?", isPresented: $showResetConfirmation) {
            Button("Reset All Data", role: .destructive) {
                do {
                    try AppSettings.resetAllData()
                } catch {
                    resetErrorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears Lil-Lenny’s saved token, API keys, model/runtime settings, onboarding state, and removes the `lennysdata` MCP config it wrote for Claude and Codex.")
        }
        .alert("Reset Failed", isPresented: Binding(
            get: { resetErrorMessage != nil },
            set: { if !$0 { resetErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
        }
    }

    private var visiblePanes: [SettingsPane] {
        var panes: [SettingsPane] = [.source, .models, .about]
        if debugLoggingEnabled {
            panes.append(.developer)
        }
        return panes
    }

    @ViewBuilder
    private var currentPaneView: some View {
        switch selectedPane {
        case .source:
            sourcePane
        case .models:
            modelsPane
        case .about:
            aboutPane
        case .developer:
            developerPane
        }
    }

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "Lenny source",
                subtitle: "Choose whether Lil-Lenny answers from the bundled Starter Pack or the full LennyData archive."
            )

            SettingsSectionCard(title: "Answer source", subtitle: "Starter Pack is local and fast. Full LennyData uses the official archive when available.") {
                VStack(spacing: 0) {
                    sourceRow(
                        mode: .starterPack,
                        title: "Starter Pack",
                        subtitle: "Bundled on this Mac",
                        detail: "Fast, local, and ready immediately for quick questions and demos.",
                        isLast: false
                    )

                    sourceRow(
                        mode: .officialMCP,
                        title: "Full LennyData",
                        subtitle: "Official archive access",
                        detail: "Broader and deeper answers from the full LennyData archive.",
                        isLast: archiveAccessMode != AppSettings.ArchiveAccessMode.officialMCP.rawValue
                    )
                }

                if archiveAccessMode == AppSettings.ArchiveAccessMode.officialMCP.rawValue {
                    Divider()
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        if AppSettings.hasDetectedOfficialMCPConfiguration {
                            SettingsInfoRow(
                                icon: "checkmark.circle.fill",
                                iconColor: .accentColor,
                                text: detectedOfficialSourceStatusText
                            )
                        } else {
                            HStack(alignment: .center, spacing: 12) {
                                SecureField("Paste auth key", text: $officialToken)
                                    .textFieldStyle(.roundedBorder)

                                Button("Open lennysdata.com") {
                                    NSWorkspace.shared.open(officialArchiveURL)
                                }
                                .buttonStyle(.bordered)
                            }

                            Text("Lil-Lenny stores this auth key locally on this Mac and uses it to configure Claude Code and/or Codex without replacing any existing MCP setup.")
                                .settingsCaption()

                            SettingsInfoRow(
                                icon: "info.circle.fill",
                                iconColor: .secondary,
                                text: OfficialMCPInstaller.installTargetStatusSummary()
                            )
                        }
                    }
                }
            }
        }
    }

    private var modelsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "Models",
                subtitle: "Choose how Lil-Lenny should answer on this Mac."
            )

            SettingsSectionCard(title: "Runtime", subtitle: modelSectionSubtitle) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Runtime", selection: $preferredTransport) {
                        Text("Automatic")
                            .tag(AppSettings.PreferredTransport.automatic.rawValue)
                        Text("Claude Code")
                            .tag(AppSettings.PreferredTransport.claudeCode.rawValue)
                        Text("Codex")
                            .tag(AppSettings.PreferredTransport.codex.rawValue)
                        Text("OpenAI API")
                            .tag(AppSettings.PreferredTransport.openAIAPI.rawValue)
                    }
                    .pickerStyle(.segmented)

                    SettingsInfoRow(
                        icon: isAutomaticSelected ? "arrow.triangle.branch" : selectedRuntimeIcon,
                        iconColor: .accentColor,
                        text: isAutomaticSelected ? automaticRuntimeDescription : selectedRuntimeDescription
                    )

                    if effectiveModelTransport == .claudeCode {
                        LabeledModelPicker(
                            title: "Claude model",
                            selection: $preferredClaudeModel,
                            options: AppSettings.ClaudeModel.allCases.map { ($0.label, $0.rawValue) }
                        )
                    } else if effectiveModelTransport == .codex {
                        LabeledModelPicker(
                            title: "Codex model",
                            selection: $preferredCodexModel,
                            options: AppSettings.CodexModel.allCases.map { ($0.label, $0.rawValue) }
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledModelPicker(
                                title: "OpenAI model",
                                selection: $preferredOpenAIModel,
                                options: AppSettings.OpenAIModel.allCases.map { ($0.label, $0.rawValue) }
                            )

                            SecureField("Paste OpenAI API key", text: $openAIAPIKey)
                                .textFieldStyle(.roundedBorder)

                            Text("Used only when Lil-Lenny needs to fall back to the OpenAI API on this Mac.")
                                .settingsCaption()
                        }
                    }
                }
            }
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "About",
                subtitle: "Credits, project story, and links to learn more."
            )

            SettingsSectionCard(title: "Credits", subtitle: "Original project and this fork.") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Lil-Lenny is built on top of the original lil agents project.")
                        .settingsCaption()

                    Link("Ryan Stephen · Original lil agents project", destination: URL(string: "https://github.com/ryanstephen/lil-agents")!)
                        .font(.subheadline.weight(.medium))

                    Text("This fork is designed and developed by Ben Shih.")
                        .settingsCaption()

                    Link("Ben Shih · benshih.design", destination: URL(string: "https://benshih.design")!)
                        .font(.subheadline.weight(.medium))
                }
            }

            SettingsSectionCard(title: "Why I built this", subtitle: "The thinking behind Lil-Lenny.") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("I built Lil-Lenny because I wanted fast, grounded product advice to feel as lightweight and ambient as opening a desktop companion, not another heavy research workflow.")
                        .settingsCaption()

                    Text("The goal was to bring Lenny’s writing, podcast transcripts, and expert perspectives into a format that feels conversational, local-first, and easy to keep nearby while working through product, growth, pricing, leadership, and startup questions.")
                        .settingsCaption()

                    Text("It is also a small experiment in making agent workflows feel more human: multiple voices, clearer provenance, and a calmer desktop-native interface instead of a generic chat window.")
                        .settingsCaption()
                }
            }

            SettingsSectionCard(title: "Notes", subtitle: "Maintenance and release details for this fork.") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before shipping updates from this fork, publish your signed Sparkle releases to this repository and replace the public update key in `LilAgents/Info.plist` with your own.")
                        .settingsCaption()
                }
            }
        }
    }

    private var developerPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                title: "Developer",
                subtitle: "Behavior toggles and preview states for local testing."
            )

            SettingsSectionCard(title: "Developer", subtitle: "Logs and preview behavior.") {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show detailed session logs in Xcode", isOn: $debugLoggingEnabled)
                        Text("Sensitive tokens stay redacted in logs.")
                            .settingsCaption()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome preview")
                            .font(.headline)

                        Picker("Preview mode", selection: $welcomePreviewMode) {
                            ForEach(AppSettings.WelcomePreviewMode.allCases, id: \.rawValue) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reset")
                            .font(.headline)

                        Text("Clear Lil-Lenny’s local settings and remove its Claude/Codex LennyData MCP configuration so you can test the setup flow from a clean state.")
                            .settingsCaption()

                        Button("Reset all local data…", role: .destructive) {
                            showResetConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sourceRow(
        mode: AppSettings.ArchiveAccessMode,
        title: String,
        subtitle: String,
        detail: String,
        isLast: Bool
    ) -> some View {
        let selected = archiveAccessMode == mode.rawValue

        Button {
            archiveAccessMode = mode.rawValue
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if selected {
                            SettingsStatusPill(title: "Selected", systemImage: "checkmark.circle.fill", tone: .accent)
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(detail)
                        .settingsCaption()
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.06) : Color.clear)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var isAutomaticSelected: Bool {
        preferredTransport == AppSettings.PreferredTransport.automatic.rawValue
    }

    private var effectiveModelTransport: AppSettings.PreferredTransport {
        if let selected = AppSettings.PreferredTransport(rawValue: preferredTransport), selected != .automatic {
            return selected
        }

        if AppSettings.hasDetectedClaudeLogin {
            return .claudeCode
        }
        if AppSettings.hasDetectedCodexLogin {
            return .codex
        }
        if AppSettings.hasDetectedOpenAIAPIKey {
            return .openAIAPI
        }
        return .automatic
    }

    private var modelSectionSubtitle: String {
        if isAutomaticSelected {
            return "Automatic checks Claude first, then Codex, then OpenAI."
        }

        switch effectiveModelTransport {
        case .claudeCode:
            return "Lil-Lenny will answer through Claude Code."
        case .codex:
            return "Lil-Lenny will answer through Codex."
        case .openAIAPI:
            return "Lil-Lenny will answer through the OpenAI API."
        case .automatic:
            return "Automatic chooses the best available runtime on this Mac."
        }
    }

    private var automaticRuntimeDescription: String {
        switch effectiveModelTransport {
        case .claudeCode:
            return "Automatic currently prefers Claude Code on this Mac."
        case .codex:
            return "Automatic currently prefers Codex on this Mac."
        case .openAIAPI:
            return AppSettings.hasDetectedOfficialMCPConfiguration
                ? "Automatic would use the OpenAI API with LennyData right now."
                : "Automatic would fall back to the OpenAI API right now."
        case .automatic:
            if AppSettings.hasDetectedOfficialMCPConfiguration {
                return "LennyData is configured, but no logged-in Claude Code or Codex runtime was detected. Open Settings to check the local sign-in."
            }
            return AppSettings.hasDetectedOpenAIAPIKey
                ? "Automatic would fall back to the OpenAI API right now."
                : "Nothing is configured yet. Open Settings to connect Claude, Codex, or add an OpenAI API key."
        }
    }

    private var detectedOfficialSourceStatusText: String {
        let sources = AppSettings.detectedOfficialMCPSources

        if sources == [.settingsToken] {
            return "A LennyData token is saved on this Mac. Lil-Lenny will verify it the next time you ask a question."
        }

        if sources == [.environmentToken] {
            return "LennyData is configured through the shell environment on this Mac."
        }

        if sources.allSatisfy({ $0 == .settingsToken || $0 == .environmentToken }) {
            return "LennyData tokens are configured on this Mac. Lil-Lenny will verify them the next time you ask a question."
        }

        return "MCP has already been configured locally through \(detectedOfficialSourceLabel)."
    }

    private var selectedRuntimeDescription: String {
        switch effectiveModelTransport {
        case .claudeCode:
            return "Choose which Claude model Lil-Lenny should use."
        case .codex:
            return "Choose which Codex model Lil-Lenny should use."
        case .openAIAPI:
            return "Choose which OpenAI model Lil-Lenny should use and add an API key below."
        case .automatic:
            return "Automatic chooses the best available runtime on this Mac."
        }
    }

    private var selectedRuntimeIcon: String {
        switch effectiveModelTransport {
        case .claudeCode:
            return "person.crop.square.fill"
        case .codex:
            return "terminal.fill"
        case .openAIAPI:
            return "network.badge.shield.half.filled"
        case .automatic:
            return "arrow.triangle.branch"
        }
    }

    private var detectedOfficialSourceLabel: String {
        let labels = AppSettings.detectedOfficialMCPSources.map(\.label)
        switch labels.count {
        case 0:
            return "your current setup"
        case 1:
            return labels[0]
        case 2:
            return "\(labels[0]) and \(labels[1])"
        default:
            let prefix = labels.dropLast().joined(separator: ", ")
            return "\(prefix), and \(labels.last ?? "your current setup")"
        }
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: pane.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.title)
                        .font(.headline)
                    Text(pane.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .settingsCaption()
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(text)
                .settingsCaption()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsStatusPill: View {
    enum Tone {
        case accent
        case warning
        case neutral
    }

    let title: String
    let systemImage: String
    let tone: Tone

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor, in: Capsule(style: .continuous))
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return .accentColor.opacity(0.12)
        case .warning:
            return Color.orange.opacity(0.14)
        case .neutral:
            return Color.primary.opacity(0.06)
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return .accentColor
        case .warning:
            return .orange
        case .neutral:
            return .secondary
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
                .frame(width: 110, alignment: .leading)

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

private extension Text {
    func settingsCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
