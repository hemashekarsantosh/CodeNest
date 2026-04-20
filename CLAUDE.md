# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CodeNest** is a native macOS application built with SwiftUI, targeting macOS 26.4 (Sequoia). The project is in its initial stage with minimal implementation.

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** macOS
- **App Bundle ID:** io.santosh.CodeNest
- **Build System:** Xcode (project file: `CodeNest.xcodeproj`)

## Build Commands

```bash
# Build (Debug)
xcodebuild -scheme CodeNest -configuration Debug

# Build (Release)
xcodebuild -scheme CodeNest -configuration Release

# List available schemes
xcodebuild -list -json

# Show build settings
xcodebuild -showBuildSettings
```

There are no unit test targets configured. SwiftUI Previews (`#Preview`) are the primary mechanism for UI validation during development.

## Architecture

The app uses a single-scene SwiftUI architecture with `NavigationSplitView` for the IDE layout:

- **`CodeNestApp.swift`** — `@main` entry; creates `WorkspaceState` as `@State`, injects via `.environment`, registers `Cmd+Shift+O` menu command
- **`ContentView.swift`** — `NavigationSplitView` root: sidebar + tab bar + editor
- **`Models/WorkspaceState.swift`** — `@Observable @MainActor` central state: open folder, file tree, tabs
- **`Models/FileNode.swift`** — `@Observable` recursive file tree node with lazy child loading
- **`Models/TabItem.swift`** — Value type for open editor tabs
- **`Views/Sidebar/`** — `SidebarView` + `FileTreeRowView` (recursive `DisclosureGroup`, lazy expansion)
- **`Views/Tabs/TabBarView.swift`** — Horizontal scrolling tab strip with hover-close
- **`Views/Editor/CodeTextView.swift`** — `NSViewRepresentable` wrapping `NSTextView`; wires `SyntaxHighlighter` as `textStorage?.delegate`
- **`Views/Editor/EditorContainerView.swift`** — Tab content binding + empty state
- **`Syntax/`** — Syntax highlighting layer (see below)

The Xcode project uses **file system synchronized groups**, meaning new Swift files added to the `CodeNest/` directory are automatically included in the build without manually editing the project file.

## Syntax Highlighting

Files in `CodeNest/Syntax/`:

- **`SyntaxToken.swift`** — `TokenType` enum + `HighlightTheme` (adaptive dark/light `NSColor` values via `NSColor(name:dynamicProvider:)`)
- **`SyntaxGrammar.swift`** — `SyntaxRule` (pre-compiled `NSRegularExpression` + token type), `SyntaxGrammar` protocol, `Language.grammar(for:)` factory
- **`SwiftGrammar.swift`**, **`JSONGrammar.swift`**, **`MarkdownGrammar.swift`**, **`GenericGrammar.swift`** — Concrete grammars; rules are ordered highest-to-lowest priority (first match wins)
- **`SyntaxHighlighter.swift`** — `@MainActor NSTextStorageDelegate`; hooks into `textStorage(_:didProcessEditing:range:changeInLength:)`; re-highlights only the edited line range on keystrokes, full document on file load

**Key invariant:** `guard editedMask.contains(.editedCharacters) else { return }` in `SyntaxHighlighter` prevents infinite loops — attribute-only changes (from the highlighter itself) are skipped.

**Adding a new language:** create a struct conforming to `SyntaxGrammar`, add a `case` to `Language.grammar(for:)`.

## Observable Pattern

This project uses `@Observable` (not `ObservableObject`) for all state types. This is required because `InferIsolatedConformances` (an enabled upcoming Swift feature) makes `@MainActor` class conformances to `ObservableObject` incompatible with SwiftUI injection patterns.

- Injection: `.environment(workspace)` / `@Environment(WorkspaceState.self) var workspace`
- Bindings on `@Observable` objects use `@Bindable` (e.g., `@Bindable var node: FileNode` to get `$node.isExpanded`)

## Swift Concurrency

The project enables strict concurrency settings:

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor` by default
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — stricter concurrency warnings enabled
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — stricter API boundary checking

Be explicit about `@MainActor`, `async/await`, and `Sendable` conformance when adding new code.
