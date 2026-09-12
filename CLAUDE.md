# QuickText Requirements Document

This document outlines the functional and technical requirements for **QuickText** (formerly "Swift Text"), a lightweight, high-performance scratchpad application reimagined for **Apple Silicon** and **macOS 15.0+**.

---

## 1. Project Overview
* **Objective:** To provide a "near-zero latency" digital scratchpad that feels like a native part of the operating system.
* **Target Platform:** macOS 15.0 or newer, optimized for ARM64 (Apple Silicon).
* **Core Philosophy:** The app should be "invisible" until needed, residing in the background with a minimal memory footprint (< 50MB RAM).

---

## 2. Functional Requirements

### 2.1. Accessibility and Summoning
* **Global Hotkey:** Users can define a custom global shortcut (e.g., `Option + Space`) to toggle the scratchpad window from any application.
* **Menu Bar Icon:** A resident icon in the macOS menu bar allows users to toggle the window with a single click.
* **Agent Mode:** The app operates as a UI Element (Agent), meaning it does not appear in the Dock or the `Cmd + Tab` switcher.

### 2.2. Text Management ("The Invisible Save")
* **Automatic Persistence:** Every keystroke is immediately saved to the disk using **SwiftData**.
* **Zero-Latency Editing:** A monospaced text editor is ready for input the moment the window appears.

### 2.3. Window Behavior and Aesthetics
* **Floating UI:** The scratchpad uses an `NSPanel` to "float" above all other windows, including full-screen applications.
* **State Persistence:** The window must remember its last size and screen coordinates across app restarts.
* **Vibrancy Effects:** Supports native macOS "blur" effects, with options for "HUD" (high-contrast) or standard "Window" background styles.
* **Space Agnostic:** The window stays visible and accessible regardless of which macOS "Space" (desktop) the user is currently on.

---

## 3. User Interface and Settings

### 3.1. Settings Dialog
* **Hotkey Recording:** A dedicated interface for users to physically record their preferred shortcut.
* **Font Customization:** Integration with the native macOS font picker to change the editor’s typeface and size.
* **"Stay on Top" Toggle:** Option to force the window to remain at the highest level of the UI stack.
* **Start at Login:** A toggle to register the app with `SMAppService` for automatic launch upon system reboot.

### 3.2. Utility Views
* **Welcome Screen:** A first-launch experience explaining the hotkey and login features, which can be disabled for subsequent starts.
* **About Screen:** Displays version information and credits in a native-styled window.
* **Feedback Integration:** A "Send Feedback" option that generates a pre-composed email to `gocodecloud@cp-soft.com`.

---

## 4. Technical Specifications
* **Language:** Swift 6.0 with strict concurrency enabled for stability on Silicon.
* **UI Framework:** SwiftUI for primary views, with `AppKit` (`NSPanel`) for specialized window management.
* **Data Layer:** SwiftData for low-overhead, automated database management.
* **Package Dependencies:** Uses the `KeyboardShortcuts` package for reliable global event monitoring.

---

## 5. Constraints and Exclusions
* **No AI Features:** The application explicitly excludes "Apple Intelligence," Writing Tools, or other AI-based integrations to maintain a lean performance profile.
* **Silicon Focus:** Development ignores legacy Intel-based hacks in favor of modern APIs like `SMAppService` and `SettingsLink`.
