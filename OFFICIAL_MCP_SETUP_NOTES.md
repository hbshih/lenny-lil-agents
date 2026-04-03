# Official MCP Setup Notes

This note captures the current local onboarding flow for connecting LennyData so we can tighten the logic later without re-tracing the implementation.

## Goal

When the user wants the official archive:

- detect whether `Claude Code` and/or `Codex` are installed
- if either is already configured with the LennyData MCP, preserve that setup
- if both are installed, configure both
- if both are already connected, prefer `Claude Code` over `Codex`
- keep the bearer token local on the Mac

## Current UX Flow

### Welcome / starter-pack upsell

- Clicking `Connect official MCP` now opens an inline setup card instead of jumping straight to Settings.
- The card explains:
  - open `lennysdata.com`
  - copy the auth key
  - paste it into Lil-Lenny
  - everything stays local on the Mac

### Current inline onboarding layout

The inline setup card was simplified to avoid the popover blowing out in height or width.

Current structure:

- short title
- one short explanatory sentence
- local-only badge in the title row beside the title
- one auth-key input row
- `Get auth key` in the same row as the input for compact mode
- one compact detected-target hint
- `Connect`
- `Back`

Implementation notes:

- the auth key field is rendered as a single custom inset row instead of a stack of nested wrappers
- the compact card now uses explicit `14pt` leading/trailing constraints instead of stack `edgeInsets`, which fixed the left-padding drift on title, input, and detection text
- the target-detection copy now uses a compact hint instead of the full long summary
- the transcript starter-pack upsell and the welcome-panel connect flow now both use the same compact MCP card so the UI stays consistent
- in compact mode, the detection hint is hidden by default and only shown after save if there is a success or error result
- the secure token field now listens to live text-change notifications, so pasting a token enables `Connect` immediately
- compact controls were tightened further:
  - smaller vertical insets
  - smaller helper text
  - smaller badge
  - smaller buttons
  - shorter placeholder and button labels
- the goal is to keep the onboarding short enough to fit inside the existing transcript/popover shell without introducing a second full-screen-feeling flow

Current product intent:

- keep the connect flow local-first and obvious
- keep the card visually aligned with the existing Lil-Lenny UI language
- minimize vertical height so the composer and transcript still feel usable while onboarding is open

### Save behavior

On save, Lil-Lenny:

1. stores the bearer token in app settings
2. switches archive mode to `officialMCP`
3. detects local Claude/Codex installs
4. preserves any existing LennyData MCP setup
5. configures whichever detected clients are still missing the MCP entry

## Detection Rules

Detection currently lives in `LilAgents/App/AppSettings.swift` under `OfficialMCPInstaller`.

### Claude detection

Claude is considered available if any of these is true:

- `claude` is found on the current process `PATH`
- `claude` is found via a login shell lookup (`/bin/zsh -l -c "command -v claude"`)
- a fallback binary path exists, currently:
  - `~/.local/bin/claude`
  - `/opt/homebrew/bin/claude`
  - `/usr/local/bin/claude`
- Claude config files/folders already exist:
  - `~/.claude`
  - `~/.claude.json`

### Codex detection

Codex is considered available if any of these is true:

- `codex` is found on the current process `PATH`
- `codex` is found via a login shell lookup (`/bin/zsh -l -c "command -v codex"`)
- a fallback binary path exists, currently:
  - `~/.local/bin/codex`
  - `~/.nvm/versions/node/current/bin/codex`
  - `/opt/homebrew/bin/codex`
  - `/usr/local/bin/codex`
- Codex config files/folders already exist:
  - `~/.codex`
  - `~/.codex/config.toml`

## Config Targets

### Claude

Lil-Lenny writes to:

- `~/.claude/settings.local.json`

Current MCP shape:

```json
{
  "mcpServers": {
    "lennysdata": {
      "type": "http",
      "url": "https://mcp.lennysdata.com/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

### Codex

Lil-Lenny writes to:

- `~/.codex/config.toml`

Current MCP shape:

```toml
[mcp_servers.lennysdata]
url = "https://mcp.lennysdata.com/mcp"
bearer_token_env_var = "LENNYSDATA_MCP_AUTH_TOKEN"
```

## Precedence

Current preference order for already-connected sources:

1. `Claude Code`
2. `Codex`
3. saved settings token

That order is reflected in `AppSettings.detectedOfficialMCPSources`.

Automatic backend selection in `ClaudeSessionBackend.swift` already prefers:

1. Claude Code
2. Codex
3. OpenAI API

So if both clients are present and both support the official MCP, Claude is chosen first.

## Console Diagnostics

To inspect the onboarding logic, Lil-Lenny now logs MCP detection details with the `mcp-install` category.

These logs currently include:

- Claude executable path or `missing`
- Codex executable path or `missing`
- whether `~/.claude` exists
- whether `~/.claude.json` exists
- whether `~/.codex` exists
- whether `~/.codex/config.toml` exists
- detected install targets
- configured MCP targets
- the final summary string shown in the UI
- install results after save

Related UI diagnostics are also still visible through the normal app logs:

- backend resolution / archive mode
- official-vs-starter source selection
- any onboarding save/install result surfaced back into the inline card

## Known Gaps / Follow-ups

These are the parts most likely to need refinement later:

1. `command -v` is done through a login shell and is synchronous. This is acceptable for setup, but we may want a more explicit async detection path later.
2. The Codex fallback path `~/.nvm/versions/node/current/bin/codex` is heuristic only. The login-shell lookup is the more reliable path.
3. Claude config merging currently writes into `settings.local.json`. If users already have a more complex layered Claude MCP setup, we may want a smarter merge strategy or CLI-driven configuration later.
4. Codex config replacement is regex-based for the `lennysdata` block. It is safe for the current shape, but not a full TOML parser.
5. The settings token is still used as a universal fallback for official MCP mode. That is useful, but we may want to make the “connected client vs saved token” distinction more explicit in future UI.
6. The inline onboarding card is intentionally compact now, but it is still constrained by the transcript/popover layout. If this continues to feel brittle, the cleanest next step is a dedicated compact sheet instead of a transcript-embedded setup card.
7. The detected-target hint is now intentionally short. If we need richer troubleshooting later, that should likely live behind an expandable detail state instead of being shown by default.
8. The compact card currently optimizes for low-height embedding inside the transcript/welcome panel. If the connect flow needs richer explanation later, it should likely become a second-step sheet rather than growing the inline card again.

## Files Touched

- `LilAgents/App/AppSettings.swift`
- `LilAgents/App/SettingsView.swift`
- `LilAgents/Terminal/TerminalView.swift`
- `LilAgents/Terminal/TerminalView+Panels.swift`
- `LilAgents/Terminal/TerminalView+Setup.swift`
- `LilAgents/Terminal/TerminalView+TranscriptBehavior.swift`
- `LilAgents/Terminal/TerminalView+TranscriptSupport.swift`
