# lil-agents Code Index

This document is a fast map of the current codebase: what the app does, where the main logic lives, and how the files relate to each other.

## What This App Is

`lil-agents` is a macOS accessory app that places a character above the Dock and turns that character into a conversational entry point.

Current behavior:
- The main character is Lenny.
- User questions go to the OpenAI Responses API.
- The model gets the LennyData MCP server as a remote tool.
- Relevant guests can appear as extra avatars.
- Clicking a guest opens that guest's own dialog above that avatar.
- The app maintains separate follow-up threads for Lenny and each guest.

## Top-Level Structure

### App shell
- `LilAgents/LilAgentsApp.swift`
  App entry point, menu bar setup, app delegate, expert status items, theme/display controls.

- `LilAgents/LilAgentsController.swift`
  Coordinates all on-screen characters, display-link ticking, Dock geometry, expert focus, and companion guest avatars.

### Main character system
- `LilAgents/WalkerCharacter.swift`
  Thin shell for the character object.

- `LilAgents/WalkerCharacterTypes.swift`
  Shared enums/constants for `WalkerCharacter`.

- `LilAgents/WalkerCharacterCore.swift`
  Character setup, asset loading, persona switching, click handling, companion avatar configuration.

- `LilAgents/WalkerCharacterPopover.swift`
  Popover creation, session wiring, input placeholder updates, popover opening/closing, live dialog behavior.

- `LilAgents/WalkerCharacterVisuals.swift`
  Handoff effects, smoke/genie visuals, thinking/completion bubbles, sound playback.

- `LilAgents/WalkerCharacterMovement.swift`
  Walking state, pause timing, movement interpolation, per-frame position updates.

### Session / AI / MCP
- `LilAgents/ClaudeSession.swift`
  Thin orchestration shell for a single conversation session.

- `LilAgents/ClaudeSessionModels.swift`
  Data models such as `ResponderExpert`, attachments, and message structures.

- `LilAgents/ClaudeSessionState.swift`
  Per-thread conversation state and history helpers.

- `LilAgents/ClaudeSessionTransport.swift`
  OpenAI Responses API request/response handling, attachment packaging, error handling.

- `LilAgents/ClaudeSessionExpertResolution.swift`
  MCP tool-output parsing, expert extraction, scoring, avatar resolution, and guest context building.

### Popover / terminal UI
- `LilAgents/TerminalView.swift`
  Thin shell for the chat UI view.

- `LilAgents/TerminalView+Setup.swift`
  View creation, layout, controls, status bar, input field, attachment label, drag/drop registration.

- `LilAgents/TerminalView+Transcript.swift`
  Transcript appending, replay, user/assistant/status/error lines, scrolling behavior.

- `LilAgents/TerminalView+Attachments.swift`
  Drag-and-drop attachment extraction and attachment label refresh.

- `LilAgents/TerminalMarkdownRenderer.swift`
  Markdown and inline markdown rendering for transcript output.

- `LilAgents/PaddedTextFieldCell.swift`
  Custom text field cell used by the composer input.

### Theme / support
- `LilAgents/PopoverTheme.swift`
  Theme definitions, colors, typography, and character-color adjustments.

- `LilAgents/CharacterContentView.swift`
  Transparent clickable character host view with alpha-aware hit testing.

## Asset Structure

### Bundled runtime assets
- `LilAgents/CharacterSprites/`
  Lenny directional PNG sprites.

- `LilAgents/ExpertAvatars/`
  Guest avatar PNGs bundled into the app.

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
3. `ClaudeSession` sends the prompt to OpenAI Responses API.
4. The model can call the LennyData MCP server tools.
5. Tool outputs are parsed into:
   - live status updates
   - transcript content
   - ranked guest experts

## 3. Guests appear
1. `ClaudeSessionExpertResolution` identifies up to 3 relevant guests.
2. `LilAgentsController` creates or updates companion avatars.
3. The main character may hand off to the first guest.
4. Clicking another guest opens that guest's own dialog above that avatar.

## 4. Follow-up mode
- Each guest has their own conversation history.
- Lenny has a separate thread.
- Switching avatars restores the correct thread and context.

## Navigation Guide

### If you want to change AI behavior
Start with:
- `LilAgents/ClaudeSessionTransport.swift`
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/ClaudeSessionModels.swift`

### If you want to change which guests appear
Start with:
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/LilAgentsController.swift`

### If you want to change character behavior or animations
Start with:
- `LilAgents/WalkerCharacterCore.swift`
- `LilAgents/WalkerCharacterVisuals.swift`
- `LilAgents/WalkerCharacterMovement.swift`

### If you want to change the chat popup
Start with:
- `LilAgents/TerminalView+Setup.swift`
- `LilAgents/TerminalView+Transcript.swift`
- `LilAgents/TerminalMarkdownRenderer.swift`

### If you want to change menu bar behavior
Start with:
- `LilAgents/LilAgentsApp.swift`

## Current Larger Files

After the refactor, most responsibilities are split, but a few helper files are still on the larger side:
- `LilAgents/ClaudeSessionExpertResolution.swift`
- `LilAgents/ClaudeSessionTransport.swift`
- `LilAgents/WalkerCharacterVisuals.swift`
- `LilAgents/WalkerCharacterPopover.swift`

These are the next best candidates if you want to continue breaking the codebase into smaller units.

## Notes

- The Xcode project is explicit-file based, so new Swift files usually need to be added to `lil-agents.xcodeproj/project.pbxproj`.
- The app currently depends on bundled avatar resources under `LilAgents/CharacterSprites` and `LilAgents/ExpertAvatars`.
- There is also a helper script folder:
  - `Scripts/convert_avatars_to_png.swift`

## Suggested Reading Order

If you are new to the codebase, read in this order:
1. `LilAgents/LilAgentsApp.swift`
2. `LilAgents/LilAgentsController.swift`
3. `LilAgents/WalkerCharacter.swift`
4. `LilAgents/WalkerCharacterPopover.swift`
5. `LilAgents/ClaudeSession.swift`
6. `LilAgents/ClaudeSessionTransport.swift`
7. `LilAgents/ClaudeSessionExpertResolution.swift`
8. `LilAgents/TerminalView.swift`
9. `LilAgents/TerminalView+Setup.swift`

