# Next Steps To Publish Lenny

This repo now builds and runs as `Lenny.app`, but it is not fully ready to ship until you replace the remaining fork placeholders with your own release infrastructure.

## 1. Finalize the shipped identity

- Confirm the app name you want to publish. It is currently set to `Lenny`.
- Confirm the bundle identifier you want to ship. It is currently set to `com.hbshih.lenny` in [lil-agents.xcodeproj/project.pbxproj](/Users/benmiro/Documents/GitHub/lenny-lil-agents/lil-agents.xcodeproj/project.pbxproj).
- If you want a different brand name or bundle ID, change those before your first public release so Sparkle, code signing, and Launch Services all stay consistent.

## 2. Replace the Sparkle signing key

- Generate your own Sparkle EdDSA key pair.
- Replace `SUPublicEDKey` in [LilAgents/Info.plist](/Users/benmiro/Documents/GitHub/lenny-lil-agents/LilAgents/Info.plist) with your public key.
- Keep the private signing key outside the repo.
- Do not ship updates signed with the upstream key.

## 3. Decide where the update feed will live

- `SUFeedURL` currently points to the raw `appcast.xml` file in this fork:
  - `https://raw.githubusercontent.com/hbshih/lenny-lil-agents/main/appcast.xml`
- This is acceptable for early testing, but for production you may prefer a stable domain or GitHub Pages URL you control.
- If you move the feed, update both `SUFeedURL` in [LilAgents/Info.plist](/Users/benmiro/Documents/GitHub/lenny-lil-agents/LilAgents/Info.plist) and the release links in [appcast.xml](/Users/benmiro/Documents/GitHub/lenny-lil-agents/appcast.xml).

## 4. Publish your first real Sparkle release

- Archive the app in Xcode or build a signed release app bundle.
- Notarize and staple the app.
- Zip it with:

```bash
ditto -c -k - --keepParent Lenny.app Lenny-v1.0.zip
```

- Sign the zip with Sparkle’s `sign_update` using your private key.
- Add a new `<item>` entry to [appcast.xml](/Users/benmiro/Documents/GitHub/lenny-lil-agents/appcast.xml) with:
  - version
  - short version string
  - publication date
  - minimum macOS version
  - enclosure URL
  - `sparkle:edSignature`
  - file length
- Upload the signed zip to a release location you control.

## 5. Review code signing and notarization

- Make sure the app is signed with your Apple Developer identity, not just `Sign to Run Locally`.
- Verify the bundle identifier in the signing setup matches the one in the project.
- Test a notarized build outside Xcode on a clean machine or clean macOS user account.

## 6. Review the visible product copy one more time

- Re-read the Settings screen, README, and app menu labels for any copy you still want to personalize.
- Settings now credits Ryan Stephen for the original `lil agents` project. Keep that unless you intentionally want different attribution language.
- Check whether you want to keep the app name as `Lenny` everywhere or introduce a fuller product name.

## 7. Replace the icon if you want a higher-fidelity source image

- The current app and menu bar icons were regenerated locally from a simplified pixel-art version to make the asset catalog valid.
- If you have a master PNG for the new icon, replace the generated assets and rerun the helper script or regenerate the exact sizes:
  - [LilAgents/Assets.xcassets/AppIcon.appiconset](/Users/benmiro/Documents/GitHub/lenny-lil-agents/LilAgents/Assets.xcassets/AppIcon.appiconset)
  - [LilAgents/Assets.xcassets/MenuBarIcon.imageset](/Users/benmiro/Documents/GitHub/lenny-lil-agents/LilAgents/Assets.xcassets/MenuBarIcon.imageset)
- The helper used for the current generated icons lives at [tools/generate_lenny_icons.swift](/Users/benmiro/Documents/GitHub/lenny-lil-agents/tools/generate_lenny_icons.swift).

## 8. Clean up release-facing docs

- Update [README.md](/Users/benmiro/Documents/GitHub/lenny-lil-agents/README.md) if you want public install/release instructions that match your exact distribution flow.
- Update [index.md](/Users/benmiro/Documents/GitHub/lenny-lil-agents/index.md) if you make further architectural or branding changes.

## 9. Test update flow end to end

- Install an older signed build.
- Publish a newer signed build and updated `appcast.xml`.
- Use `Check for Updates…` in the app menu.
- Confirm Sparkle detects, downloads, validates, and installs the new release correctly.

## 10. Before committing a release branch

- Review `git status` and do not accidentally commit local debug artifacts like `firebase-debug.log`.
- Make sure `appcast.xml` and `Info.plist` point only to infrastructure you control.
- Tag the release commit so the appcast entry and GitHub release are easy to reconcile later.
