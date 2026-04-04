import AppKit
import SwiftUI

extension SettingsView {
    var modelsPane: some View {
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

    var aboutPane: some View {
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

                    Text("The goal was to bring Lenny's writing, podcast transcripts, and expert perspectives into a format that feels conversational, local-first, and easy to keep nearby while working through product, growth, pricing, leadership, and startup questions.")
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

    var developerPane: some View {
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

                        Text("Clear Lil-Lenny's local settings and remove its Claude/Codex LennyData MCP configuration so you can test the setup flow from a clean state.")
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

    // MARK: - Model/transport helpers

    var isAutomaticSelected: Bool {
        preferredTransport == AppSettings.PreferredTransport.automatic.rawValue
    }

    var effectiveModelTransport: AppSettings.PreferredTransport {
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

    var modelSectionSubtitle: String {
        if isAutomaticSelected {
            return "Automatic checks Claude first, then Codex, then OpenAI."
        }

        switch effectiveModelTransport {
        case .claudeCode: return "Lil-Lenny will answer through Claude Code."
        case .codex: return "Lil-Lenny will answer through Codex."
        case .openAIAPI: return "Lil-Lenny will answer through the OpenAI API."
        case .automatic: return "Automatic chooses the best available runtime on this Mac."
        }
    }

    var automaticRuntimeDescription: String {
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

    var selectedRuntimeDescription: String {
        switch effectiveModelTransport {
        case .claudeCode: return "Choose which Claude model Lil-Lenny should use."
        case .codex: return "Choose which Codex model Lil-Lenny should use."
        case .openAIAPI: return "Choose which OpenAI model Lil-Lenny should use and add an API key below."
        case .automatic: return "Automatic chooses the best available runtime on this Mac."
        }
    }

    var selectedRuntimeIcon: String {
        switch effectiveModelTransport {
        case .claudeCode: return "person.crop.square.fill"
        case .codex: return "terminal.fill"
        case .openAIAPI: return "network.badge.shield.half.filled"
        case .automatic: return "arrow.triangle.branch"
        }
    }
}
