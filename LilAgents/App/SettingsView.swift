import AppKit
import Combine
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
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
    @AppStorage(AppSettings.preferredTransportKey) var preferredTransport = AppSettings.PreferredTransport.automatic.rawValue
    @AppStorage(AppSettings.archiveAccessModeKey) var archiveAccessMode = AppSettings.ArchiveAccessMode.starterPack.rawValue
    @AppStorage(AppSettings.officialLennyMCPTokenKey) var officialToken = ""
    @AppStorage(AppSettings.openAIAPIKeyKey) var openAIAPIKey = ""
    @AppStorage(AppSettings.debugLoggingEnabledKey) var debugLoggingEnabled = true
    @AppStorage(AppSettings.preferredClaudeModelKey) var preferredClaudeModel = AppSettings.ClaudeModel.default.rawValue
    @AppStorage(AppSettings.preferredCodexModelKey) var preferredCodexModel = AppSettings.CodexModel.default.rawValue
    @AppStorage(AppSettings.preferredOpenAIModelKey) var preferredOpenAIModel = AppSettings.OpenAIModel.gpt5Nano.rawValue
    @AppStorage(AppSettings.welcomePreviewModeKey) var welcomePreviewMode = AppSettings.WelcomePreviewMode.live.rawValue

    @State var selectedPane: SettingsPane = .source
    @State var showResetConfirmation = false
    @State var resetErrorMessage: String?

    let officialArchiveURL = URL(string: "https://www.lennysdata.com")!

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
            Text("This clears Lil-Lenny's saved token, API keys, model/runtime settings, onboarding state, and removes the `lennysdata` MCP config it wrote for Claude and Codex.")
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
}
