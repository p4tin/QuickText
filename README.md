# QuickText

A near-zero-latency scratchpad for macOS. Hit a global hotkey or click the
menu bar icon from anywhere, a floating panel appears, you type, it's saved —
no save button, no "unsaved changes" state, ever.

## Features

- **Global hotkey + menu bar icon** — summon the panel from any app; it
  floats above everything (including full-screen apps) and follows you
  across Spaces.
- **Notes organized into folders** — a sidebar tree with drag-and-drop
  reorganizing, inline rename, and delete.
- **Backup / Restore** — since there's no undo or trash, "Backup…" (gear
  menu, bottom of the editor) snapshots every note and folder to a
  `.tar.gz` file; "Restore…" replaces the entire tree from one. This is the
  one recovery path against mistakes, so back up before anything risky.
- **Customization** — hotkey, font, window vibrancy style, stay-on-top,
  launch at login (Settings).

## Requirements

- macOS 15.0+ (built/tested against 15.6), Apple Silicon.
- Xcode (current stable).

## Building

Open `QuickText.xcodeproj` in Xcode and run the `QuickText` scheme, or from
the CLI:

```sh
xcodebuild -project QuickText.xcodeproj -scheme QuickText \
  -configuration Debug -destination 'platform=macOS' build
```

Swap `-configuration Release` for a release build.

### Packaging a `.dmg`

```sh
xcodebuild -project QuickText.xcodeproj -scheme QuickText \
  -configuration Release -destination 'platform=macOS' clean build

# Stage QuickText.app + an Applications symlink, then:
hdiutil create -volname QuickText -srcfolder <staging-dir> \
  -format UDZO release/QuickText.dmg
```

## Project docs

This repo uses a spec-driven workflow for feature work — see
`.claude/steering/` for the living product/architecture/tech reference, and
`.claude/designs/{feature-name}/` for each feature's requirements, design,
and task breakdown.
