# QuickText

**QuickText** is a lightweight, high-performance digital scratchpad designed for **Apple Silicon** and **macOS 15.0+**. Built with a focus on "near-zero latency," it provides a seamless, native experience for quick note-taking without the overhead of traditional text editors.

## Technical Architecture

### Core Stack
- **UI Framework**: SwiftUI for primary views, providing a modern and declarative interface.
- **Window Management**: `AppKit` (`NSPanel`) for specialized behavior, allowing the scratchpad to float above all windows and full-screen applications.
- **Data Layer**: `SwiftData` for automated, low-overhead persistence. Every keystroke is saved immediately to disk.
- **Concurrency**: Swift 6.0 with strict concurrency enabled for maximum stability on modern hardware.

### Key Engineering Features
- **Agent Mode**: Operates as a `UI Element` (LSUIElement), keeping the Dock and App Switcher (`Cmd+Tab`) clean.
- **Global Event Monitoring**: Integration with the `KeyboardShortcuts` package for reliable, system-wide window toggling via a customizable hotkey.
- **Space Agnostic**: Configured with `.canJoinAllSpaces`, ensuring the scratchpad is accessible across all macOS Desktops.
- **Zero-Latency Editor**: Custom-tuned `TextEditor` with direct binding to the SwiftData model for instantaneous feedback and storage.
- **Dynamic Styling**: Support for native macOS "vibrancy" effects (HUD/Standard) using `NSVisualEffectView` integration.

## Documentation
For instructions on how to use QuickText, please refer to the [User Documentation](UserDocumentation.md).
