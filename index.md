# lil-agents Code Index

This document is a fast map of the current codebase: what the app does, where the main logic lives, and how the files relate to each other.

## What This App Is

`lil-agents` is a macOS accessory app that places a character above the Dock and turns that character into a conversational entry point.

Current behavior:
- The main character is Lenny.
- User questions can run through Claude Code CLI, Codex CLI, or a direct OpenAI Responses API fallback.
- Archive access has two modes:
  - `starterPack`: bundled local free archive search under `LilAgents/StarterArchive`
  - `officialMCP`: the official Lenny MCP path, using the user's own CLI setup or bearer token
- The app can surface relevant experts after a Lenny response completes.
- Expert switching is no longer automatic.
- Welcome pills live in a separate bottom suggestion panel above the composer.
- Expert suggestions now render inline in the transcript, per Lenny reply, with collapsed and expanded states preserved for older replies.
- Expert suggestions only appear for names that match bundled avatar assets.
- Clicking a suggested expert swaps the main character from Lenny into that expert instead of spawning companion avatars.
- The app maintains separate follow-up threads for Lenny and each guest, and returning to Lenny restores Lenny's own transcript.
- Expert suggestions can be reopened from their collapsed transcript state after a user has already chosen one.
- Live status now prefers transport- and tool-specific copy, and the minimized tag above the avatar uses a compact version of that status.
- The popover currently uses one default visual style instead of multiple selectable themes.

## Source Folder Layout

```
LilAgents/
  App/         — entry point, coordinator, settings
  Session/     — all AI / MCP / session logic
  Character/   — WalkerCharacter and all extensions
  Terminal/    — chat UI (TerminalView and extensions)
  Support/     — shared theme and view utilities
```

## Top-Level Structure

### App shell
- `LilAgents/App/LilAgentsApp.swift`
  App entry point, menu bar setup, app delegate, expert status items, theme/display controls, and the Settings window host.

- `LilAgents/App/LilAgentsController.swift`
  Coordinates all on-screen characters, display-link ticking, Dock geometry, expert focus, and companion guest avatars.

- `LilAgents/App/AppSettings.swift`
  Persistent app settings for archive mode, preferred transport, model selection labels, official MCP token override, and debug logging.

- `LilAgents/App/SettingsView.swift`
  Settings UI for archive mode selection, transport preference, official MCP token entry, debug logging, and setup instructions.

### Main character system
- `LilAgents/Character/WalkerCharacter.swift`
  Thin shell for the character object.

- `LilAgents/Character/WalkerCharacterTypes.swift`
  Shared enums/constants for `WalkerCharacter`.

- `LilAgents/Character/WalkerCharacterCore.swift`
  Character setup, asset loading, persona switching, click handling, transcript restoration, and companion-avatar suppression for expert suggestions.

- `LilAgents/Character/WalkerCharacterPopover.swift`
  Popover opening/closing, expert-focus wiring, live dialog behavior.

- `LilAgents/Character/WalkerCharacterPopoverWindow.swift`
  Popover window creation, title bar controls (expand, pin, close), theme resolution, return-to-Lenny behavior, and `TerminalView` instantiation.

- `LilAgents/Character/WalkerCharacterSessionWiring.swift`
  Wires `ClaudeSession` callbacks (`onText`, `onTurnComplete`, `onError`, `onToolUse`, `onToolResult`, `onExpertsUpdated`) to the character and terminal UI, including live-status formatting and compact avatar-tag status text.

- `LilAgents/Character/WalkerCharacterBubble.swift`
  Thinking/completion speech bubbles, sound playback, bubble positioning, and expert name tag height constant.

- `LilAgents/Character/WalkerCharacterExpertTag.swift`
  Floating expert-name tag window creation, positioning, styling, and compact activity-status display above the avatar.

- `LilAgents/Character/WalkerCharacterVisuals.swift`
  Handoff effects, smoke/genie visuals, and remaining visual helpers.

- `LilAgents/Character/WalkerCharacterMovement.swift`
  Walking state, pause timing, movement interpolation, per-frame position updates.

### Session / AI / MCP
- `LilAgents/Session/ClaudeSession.swift`
  Thin orchestration shell for a single conversation session, including staged expert suggestions and model-label helpers for status copy.

- `LilAgents/Session/ClaudeSessionModels.swift`
  Data models: `ResponderExpert`, `SessionAttachment`, `ConversationState`, `ExpertSuggestionEntry`, `SearchEnvelope`/`SearchResult`, and `Message`.

- `LilAgents/Session/ClaudeSessionState.swift`
  Per-thread conversation state, per-reply expert suggestion state, prompt building (`buildInstructions`, `buildUserPrompt`, `buildConversationPrompt`, `buildInputContent`), and turn lifecycle (`finishTurn`, `failTurn`).

- `LilAgents/Session/ClaudeSessionBackend.swift`
  Shell environment resolution, backend discovery (Claude Code CLI → Codex CLI → OpenAI API), forced-backend handling, executable PATH lookup, auth checks, MCP token resolution, and setup/status messaging.

- `LilAgents/Session/ClaudeSessionTransport.swift`
  Top-level `start()` and `send()` entry points, archive-mode routing (starter pack vs. official MCP), local starter-archive search, expert publishing after responses, and process termination.

- `LilAgents/Session/ClaudeSessionCLI.swift`
  Claude Code CLI and Codex CLI dispatch: argument assembly, Claude stream-json setup, MCP config file creation, process execution, and result routing.

- `LilAgents/Session/ClaudeSessionCLIParsing.swift`
  CLI output parsing: structured JSON envelope extraction (`answer_markdown` / `suggested_experts`), fallback malformed-envelope recovery, Claude CLI stream-event parsing, result/metadata extraction, error normalization (with prompt-dump suppression), and `prepareAssistantOutput`.

- `LilAgents/Session/ClaudeSessionOpenAI.swift`
  Direct OpenAI Responses API transport: request construction, MCP tool injection, response handling, `mcp_call`/`mcp_list_tools` processing, status summaries, and message text extraction.

- `LilAgents/Session/ClaudeSessionExpertResolution.swift`
  Local/MCP expert extraction, scoring, avatar resolution, assistant-text fallback parsing, MCP status summaries, speaker-name extraction from filenames/titles, and guest context building.

- `LilAgents/Session/ClaudeSessionExpertCatalog.swift`
  Expert name catalog: avatar path lookup, canonical name matching, known-expert enumeration from bundled assets, markdown bold-name extraction, structured expert-tag parsing, PNG avatar conversion/caching, and name normalization.

- `LilAgents/Session/ClaudeSessionExpertTextResolution.swift`
  `responseScript` generation, `flattenOutputStrings` for varied API output shapes, and recursive `expertNames(in:)` extraction from nested payloads.

- `LilAgents/Session/ClaudeSessionSupport.swift`
  Low-level helpers: `runProcess` (subprocess execution), `imageDataURL` (base64 image encoding), `documentText` (PDF/RTF/text extraction), and document truncation.

- `LilAgents/Session/LocalArchive.swift`
  Local starter-pack indexing and retrieval over the bundled free newsletter and podcast subset.

- `LilAgents/Session/SessionDebugLogger.swift`
  Structured debug logging for backend selection, archive mode, requests, subprocess output, and responses.

### Popover / terminal UI
- `LilAgents/Terminal/TerminalView.swift`
  Thin shell for the chat UI view, including deferred expert suggestions, inline expert-picker callbacks, attachment previews, the return-to-Lenny hook, and property declarations.

- `LilAgents/Terminal/TerminalView+Setup.swift`
  View creation, layout, controls, status bar, welcome suggestion panel, input field, attachment previews, pin/close actions, and drag/drop registration.

- `LilAgents/Terminal/TerminalView+Panels.swift`
  Welcome suggestion panel population, live-status display, status clearing, transcript suggestion rendering, expert-button tap handling, and `NSTextViewDelegate` link-click routing.

- `LilAgents/Terminal/TerminalViewLayout.swift`
  Layout constants, `relayoutPanels()` frame calculations, panel styling helpers, and panel visibility toggling.

- `LilAgents/Terminal/TerminalView+Transcript.swift`
  Transcript appending, replay, greeting restoration, per-reply expert suggestion rendering, compact picked-expert summaries, and transcript sizing/scroll behavior.

- `LilAgents/Terminal/TerminalView+Attachments.swift`
  Drag-and-drop attachment extraction, attachment preview rendering, and removal controls.

- `LilAgents/Terminal/TerminalMarkdownRenderer.swift`
  Markdown and inline markdown rendering for transcript output.

- `LilAgents/Terminal/PaddedTextFieldCell.swift`
  Custom text field cell used by the composer input.

### Theme / support
- `LilAgents/Support/PopoverTheme.swift`
  Theme definitions, colors, typography, and character-color adjustments. The app currently ships with a single default theme.

- `LilAgents/Support/CharacterContentView.swift`
  Transparent clickable character host view with alpha-aware hit testing.

## Asset Structure

### Bundled runtime assets
- `LilAgents/CharacterSprites/`
  Lenny directional PNG sprites.

- `LilAgents/ExpertAvatars/`
  Guest avatar PNGs bundled into the app.

- `LilAgents/StarterArchive/`
  Local free archive bundle used for starter-pack search.

- `LilAgents/Sounds/`
  Sound effects.

- `LilAgents/Assets.xcassets/`
  Standard app asset catalog resources.

### Legacy assets still present
- `LilAgents/walk-bruce-01.mov`
- `LilAgents/walk-jazz-01.mov`

These are old assets from the original app and are no longer the main runtime character path.

## Runtime Flow

## 1. App launch
1. `LilAgentsApp.swift` creates the app delegate and menu bar UI.
2. `LilAgentsController.start()` creates the main Lenny character.
3. The controller starts a display link and updates character positions every frame.

## 2. User asks a question
1. The user clicks Lenny.
2. `WalkerCharacterPopover` opens the popover above the character.
3. `ClaudeSessionTransport.send()` resolves the current archive mode and the best available backend via `ClaudeSessionBackend`.
4. In `starterPack` mode, `LocalArchive` retrieves bundled local context.
5. In `officialMCP` mode, the app prefers Claude Code CLI, then Codex CLI, then direct OpenAI Responses API fallback.
6. Official mode can use:
   - the user's existing Claude/Codex MCP configuration
   - or a bearer token entered in Settings
7. The actual request is dispatched through `ClaudeSessionCLI` (for CLI backends) or `ClaudeSessionOpenAI` (for direct API).
8. The response path emits:
   - live status updates
   - transcript content
   - optional staged expert suggestions
   - structured answer parsing via `ClaudeSessionCLIParsing` when the model returns the JSON response envelope
   - verbose debug logs when enabled
9. In official MCP mode, prompts now instruct the backend to route through `index.md` first before deeper reads.

## 3. Expert suggestions appear
1. `ClaudeSessionExpertResolution` and `ClaudeSessionExpertCatalog` identify relevant experts from local search, MCP-derived data, or assistant text fallback.
2. The app does not auto-switch to another expert.
3. After a Lenny response completes, the transcript shows an inline expert picker for that specific reply.
4. Clicking one of those buttons swaps Lenny into the selected expert and collapses that specific picker entry.
5. Returning to Lenny restores Lenny's transcript, including older picker entries in their prior state.
6. Suggestions only surface when the expert name resolves to a bundled avatar.

## 4. Follow-up mode
- Each guest has their own conversation history.
- Lenny has a separate thread.
- Switching avatars restores the correct thread and context.
- Expert suggestions are staged until the end of the turn so the current speaker does not change mid-response.
- Each Lenny reply can own its own suggestion picker state, so older replies stay collapsed or expanded as last seen while new replies get fresh options.
- The popover UI is now content-first: larger transcript, simplified header copy, single default theme, a separate welcome panel above the composer, and inline transcript-native expert suggestions.

## Navigation Guide

### If you want to change AI behavior
Start with:
- `LilAgents/Session/ClaudeSessionTransport.swift`
- `LilAgents/Session/ClaudeSessionBackend.swift`
- `LilAgents/Session/ClaudeSessionCLI.swift`
- `LilAgents/Session/ClaudeSessionCLIParsing.swift`
- `LilAgents/Session/ClaudeSessionOpenAI.swift`
- `LilAgents/Session/ClaudeSessionState.swift`

### If you want to change which guests appear
Start with:
- `LilAgents/Session/ClaudeSessionExpertResolution.swift`
- `LilAgents/Session/ClaudeSessionExpertCatalog.swift`
- `LilAgents/Session/ClaudeSessionExpertTextResolution.swift`
- `LilAgents/App/LilAgentsController.swift`
- `LilAgents/Character/WalkerCharacterPopover.swift`

### If you want to change character behavior or animations
Start with:
- `LilAgents/Character/WalkerCharacterCore.swift`
- `LilAgents/Character/WalkerCharacterVisuals.swift`
- `LilAgents/Character/WalkerCharacterBubble.swift`
- `LilAgents/Character/WalkerCharacterMovement.swift`
- `LilAgents/Character/WalkerCharacterExpertTag.swift`

### If you want to change the chat popup
Start with:
- `LilAgents/Terminal/TerminalView+Setup.swift`
- `LilAgents/Terminal/TerminalView+Panels.swift`
- `LilAgents/Terminal/TerminalView+Transcript.swift`
- `LilAgents/Terminal/TerminalViewLayout.swift`
- `LilAgents/Terminal/TerminalMarkdownRenderer.swift`
- `LilAgents/Character/WalkerCharacterPopoverWindow.swift`

### If you want to change menu bar behavior
Start with:
- `LilAgents/App/LilAgentsApp.swift`

### If you want to change settings or archive-source behavior
Start with:
- `LilAgents/App/AppSettings.swift`
- `LilAgents/App/SettingsView.swift`
- `LilAgents/Session/ClaudeSessionBackend.swift`
- `LilAgents/Session/ClaudeSessionTransport.swift`
- `LilAgents/Session/LocalArchive.swift`

### If you want to inspect verbose runtime logs
Start with:
- `LilAgents/Session/SessionDebugLogger.swift`
- `LilAgents/Session/ClaudeSessionTransport.swift`

## File Size Overview

After the refactor, responsibilities are well-split across focused files. The larger files are:
- `LilAgents/ClaudeSessionBackend.swift` — backend discovery and environment resolution
- `LilAgents/ClaudeSessionTransport.swift` — top-level send/start routing and starter-pack search
- `LilAgents/ClaudeSessionExpertResolution.swift` — expert extraction from MCP payloads
- `LilAgents/ClaudeSessionExpertCatalog.swift` — expert name catalog and avatar management
- `LilAgents/TerminalView+Setup.swift` — terminal view construction
- `LilAgents/WalkerCharacterVisuals.swift` — visual effects
- `LilAgents/WalkerCharacterBubble.swift` — bubbles and sound
- `LilAgents/WalkerCharacterPopoverWindow.swift` — popover window assembly

## Notes

- The Xcode project is explicit-file based, so new Swift files usually need to be added to `lil-agents.xcodeproj/project.pbxproj`.
- The app currently depends on bundled avatar resources under `LilAgents/CharacterSprites` and `LilAgents/ExpertAvatars`.
- The starter-pack experience depends on bundled content under `LilAgents/StarterArchive`.
- Official Lenny archive access depends on the user's own MCP setup or token, depending on the selected mode.
- Debug logging is intentionally verbose and is meant for Xcode console inspection while developing.
- There is also a helper script folder:
  - `Scripts/convert_avatars_to_png.swift`

## Suggested Reading Order

If you are new to the codebase, read in this order:
1. `LilAgents/LilAgentsApp.swift`
2. `LilAgents/LilAgentsController.swift`
3. `LilAgents/AppSettings.swift`
4. `LilAgents/SettingsView.swift`
5. `LilAgents/WalkerCharacter.swift`
6. `LilAgents/WalkerCharacterCore.swift`
7. `LilAgents/WalkerCharacterPopover.swift`
8. `LilAgents/WalkerCharacterPopoverWindow.swift`
9. `LilAgents/WalkerCharacterSessionWiring.swift`
10. `LilAgents/ClaudeSession.swift`
11. `LilAgents/ClaudeSessionModels.swift`
12. `LilAgents/ClaudeSessionState.swift`
13. `LilAgents/ClaudeSessionBackend.swift`
14. `LilAgents/ClaudeSessionTransport.swift`
15. `LilAgents/ClaudeSessionCLI.swift`
16. `LilAgents/ClaudeSessionCLIParsing.swift`
17. `LilAgents/ClaudeSessionOpenAI.swift`
18. `LilAgents/ClaudeSessionExpertResolution.swift`
19. `LilAgents/ClaudeSessionExpertCatalog.swift`
20. `LilAgents/ClaudeSessionExpertTextResolution.swift`
21. `LilAgents/ClaudeSessionSupport.swift`
22. `LilAgents/LocalArchive.swift`
23. `LilAgents/SessionDebugLogger.swift`
24. `LilAgents/TerminalView.swift`
25. `LilAgents/TerminalView+Setup.swift`
26. `LilAgents/TerminalView+Panels.swift`
27. `LilAgents/TerminalViewLayout.swift`
28. `LilAgents/TerminalView+Transcript.swift`
