# Implementation Log — 2026-03-29

This log summarizes the implementation work completed today around the chat popover shell, composer, attachment flow, expert handoff UX, per-reply picker state, and live backend status rendering.

## Scope

Main goals covered:
- tighten and simplify the chat popover shell and header controls
- rebalance the composer input, button sizing, and welcome suggestions layout
- improve attachment handling with previews, removal, and broader drag/drop support
- move expert recommendations into a more understandable transcript flow
- keep Lenny and expert conversations separate while preserving per-reply suggestion state
- improve live status copy so users can see what the backend is actually doing
- bias MCP usage toward `index.md` first for faster archive routing

## Architecture Changes

### 1. Popover and composer cleanup

The popover shell was narrowed and visually flattened:
- reduced over-rounded outer chrome
- removed the translucent double-shell look
- tightened top-right controls
- added pin and close actions to the title bar

The composer was also reworked:
- input radius now better matches the suggestion pills
- placeholder/input text is vertically centered
- attach and send buttons now share the same size

### 2. Attachment flow upgrade

Attachments are no longer represented as plain text only.

The chat UI now supports:
- compact attachment preview chips
- delete/remove controls before send
- drag-and-drop while pinned
- broader local-file and dragged-content handling

The attachment pipeline was widened to cover common practical document types such as:
- images and screenshots
- PDFs
- text and markdown
- CSV / TSV
- JSON / XML / HTML
- logs and common source files

### 3. Expert suggestion UX rework

The expert recommendation flow changed substantially over the course of the day.

Final behavior:
- welcome pills remain in the separate bottom panel above the composer
- expert recommendations appear inline in the transcript, attached to the specific Lenny reply that produced them
- selecting an expert swaps the main Lenny character into that expert instead of opening a separate expert dialog or spawning extra avatars
- returning to Lenny restores the original Lenny conversation
- once picked, the expert selector collapses into a compact summary row with a re-open action

### 4. Per-reply picker persistence

The expert picker is now stored per Lenny reply instead of as a single global UI state.

That means:
- old replies keep their own collapsed or expanded state
- new replies can show fresh expert options
- selecting an expert for one reply does not overwrite the state of earlier reply-level selectors

### 5. Backend-status and archive-routing improvements

The live-status path was reworked so the UI uses more specific backend/tool summaries instead of generic text.

The status system now:
- shows model-aware planning copy
- shows explicit MCP-tool labels when available
- uses shorter compact text above the avatar when minimized
- avoids overwriting a meaningful live status with fallback generic text

The archive instructions were also updated so MCP-backed turns prefer:
1. `index.md`
2. narrowing to the right person or source
3. deeper `read_excerpt` / `read_content` calls only when needed

On the Claude Code path specifically, the app now uses streaming JSON plus `--verbose` so live step updates can actually reach the UI.

## File-Level Changes

### Popover and UI shell

- `LilAgents/Character/WalkerCharacterPopoverWindow.swift`
  Narrowed the popover, flattened shell styling, tightened titlebar control layout, and added pin/close handling.

- `LilAgents/Character/WalkerCharacterPopover.swift`
  Updated open/close behavior for the pinned window path.

- `LilAgents/Character/WalkerCharacterCore.swift`
  Restored the correct transcript when switching between Lenny and experts, including first-time greeting handling.

- `LilAgents/Support/PopoverTheme.swift`
  Adjusted panel/background treatment toward a flatter, more opaque look.

### Composer, transcript, and layout

- `LilAgents/Terminal/TerminalView.swift`
  Added callback/state plumbing for expert-picker actions, attachments, pinning, and close behavior.

- `LilAgents/Terminal/TerminalView+Setup.swift`
  Reworked composer sizing, control setup, drag/drop registration, and the welcome panel arrangement.

- `LilAgents/Terminal/TerminalViewLayout.swift`
  Tuned spacing between transcript, welcome suggestions, and composer.

- `LilAgents/Terminal/PaddedTextFieldCell.swift`
  Improved vertical centering and input padding behavior.

- `LilAgents/Terminal/TerminalView+Transcript.swift`
  Moved expert recommendations into transcript-native cards, added compact picked-expert summaries, added first-time expert greeting messages, and preserved per-reply selector state.

- `LilAgents/Terminal/TerminalView+Panels.swift`
  Split the welcome panel from transcript-native expert selectors and updated the live-status pill behavior.

### Attachments

- `LilAgents/Terminal/TerminalView+Attachments.swift`
  Replaced plain-text attachment display with preview chips and removal actions, plus better drop/import handling.

- `LilAgents/Session/ClaudeSessionModels.swift`
  Expanded recognized attachment file types and attachment metadata used by the UI/session path.

### Expert handoff and session state

- `LilAgents/App/LilAgentsController.swift`
  Removed the behavior that spun up multiple companion avatars when expert suggestions appeared or were selected.

- `LilAgents/App/LilAgentsApp.swift`
  Added debug actions to force-render expert suggestion UI without waiting for a full reply path.

- `LilAgents/Character/WalkerCharacterSessionWiring.swift`
  Changed post-turn expert suggestion handling and live-status wiring.

- `LilAgents/Session/ClaudeSessionModels.swift`
  Added persisted per-reply picker entry data.

- `LilAgents/Session/ClaudeSessionState.swift`
  Added per-reply expert suggestion entry storage and MCP prompt instructions that prefer `index.md` first.

- `LilAgents/Character/WalkerCharacterPopoverWindow.swift`
  Wired picker selection/edit actions back into the correct reply-level entry.

### Backend status and structured output handling

- `LilAgents/App/AppSettings.swift`
  Cleaned default model labels so user-facing statuses read better.

- `LilAgents/Session/ClaudeSession.swift`
  Added model-label helper methods for Claude, Codex, and OpenAI status text.

- `LilAgents/Session/ClaudeSessionCLI.swift`
  Switched Claude Code to streaming JSON with `--verbose` and upgraded the planning copy.

- `LilAgents/Session/ClaudeSessionCLIParsing.swift`
  Added more defensive `answer_markdown` extraction and Claude stream-event parsing for better live statuses.

- `LilAgents/Session/ClaudeSessionOpenAI.swift`
  Updated planning copy to show the actual OpenAI model/backend path.

- `LilAgents/Session/ClaudeSessionExpertResolution.swift`
  Made MCP tool statuses more explicit and user-readable.

- `LilAgents/Character/WalkerCharacterExpertTag.swift`
  Shortened the minimized activity tag above the avatar.

## Behavior Changes

### Previous behavior

Earlier in the day, the app had several rough edges:
- the popover shell still looked double-wrapped and over-rounded
- attachment UI was mostly text-only
- expert suggestion rendering moved around between bottom-panel and transcript implementations
- expert picks could trigger surprising avatar behavior
- suggestion state was effectively global instead of tied to each reply
- live status often stayed generic even when the backend had more detail

### Current behavior

The current behavior is:
1. user opens a cleaner, narrower popover
2. welcome suggestions remain in the separate bottom panel above the composer
3. attachments can be previewed, removed, and dropped more flexibly
4. Lenny replies can append expert recommendations inline in the transcript
5. picking an expert swaps the main character into that expert
6. returning to Lenny restores Lenny’s conversation and its existing reply-level picker states
7. newer turns can show new expert options while older turns keep their historical collapsed/expanded state
8. live status is more explicit about planning, model calls, and MCP tool calls

## Commits Made Today

Two commits were made during today’s implementation cycle:

- `e5ca9ea` — `Refine chat popover and expert handoff UX`
- `2be4b48` — `Persist expert picker state per Lenny reply`

Additional live-status and `index.md`-first MCP routing work was completed after those commits and remains uncommitted at the time of this log.

## Verification

The project was rebuilt successfully after the UI and session changes with:

```sh
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -sdk macosx build
```

## Known Remaining Risks

- The Claude Code live-status path is improved, but the exact event richness still depends on what the CLI emits for a given turn.
- Structured response recovery is more defensive now, but future malformed payload shapes could still require another parser tweak.
- The expert suggestion system is now much more understandable, but it spans several UI layers and still deserves later cleanup once the product behavior stops moving.
- Binary office/media attachments are still not full native semantic inputs; they would need a separate ingestion path beyond the current image/text extraction model.

## Documentation Update

`index.md` was updated today to reflect:
- the separate welcome panel plus inline transcript-native expert suggestions
- per-reply expert picker persistence
- the direct Lenny-to-expert swap behavior
- more specific live-status handling
- Claude Code streaming status support
- MCP routing guidance that starts with `index.md`
