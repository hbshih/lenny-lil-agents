# Lenny

![Lenny](hero-thumbnail.png)

Tiny AI guidance that lives on your macOS dock.

Lenny sits above your Dock so you can ask product, growth, pricing, startup, and AI questions without leaving your flow. Click the character to open a chat grounded in Lenny's archive, then branch into specialist follow-ups when they help.

## features

- Animated characters rendered from transparent HEVC video
- Click a character to chat in a themed popover terminal
- Warm, focused popover UI with inline expert follow-ups
- Thinking bubbles with playful phrases while Claude works
- Sound effects on completion
- First-run onboarding with a friendly welcome
- Auto-updates via Sparkle

## requirements

- macOS Sonoma (14.0+)
- [Claude Code CLI](https://claude.ai/download) or [Codex CLI](https://developers.openai.com/codex/cli)

## building

Open `lil-agents.xcodeproj` in Xcode and hit run.

## privacy

Lenny runs on your Mac and does not send personal data anywhere except through the AI transport you configure.

- **Your data stays local by default.** The app plays bundled animations and calculates your dock size to position the characters. No user account, analytics, or separate app database is involved.
- **AI transport.** Conversations run through one of these paths, in order: Claude Code CLI, Codex CLI, or the direct OpenAI Responses API fallback. Any data sent to Anthropic or OpenAI is governed by their terms and privacy policy.
- **Archive access.** The app connects the selected transport to Lenny’s MCP server. A bundled free archive token is used by default, and paid Lenny members can override it in Settings or with `LENNYSDATA_MCP_AUTH_TOKEN`.
- **No accounts.** No login, no user database, no analytics in the app.
- **Updates.** Lenny uses Sparkle to check for updates, which sends your app version and macOS version. Nothing else.

## credits

This fork builds on the original `lil agents` project by Ryan Stephen. See [LICENSE](LICENSE) for the original license and attribution.

## license

MIT License. See [LICENSE](LICENSE) for details.
