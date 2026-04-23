# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CodeNest** is a native macOS IDE built with SwiftUI, targeting macOS 26.4 (Sequoia). It provides a lightweight code editor with syntax highlighting, Git integration, terminal support, and project scaffolding.

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** macOS
- **App Bundle ID:** io.santosh.CodeNest
- **Build System:** Xcode (project file: `CodeNest.xcodeproj`)

**Core Features:**
- Syntax highlighting for Swift, JSON, Markdown, and generic files
- Git integration (status, staging, commits, history)
- Integrated terminal and command output
- Project scaffolding from Spring Boot Initializr

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

## Running the App

```bash
# Build and run in Xcode
open CodeNest.xcodeproj

# Or build and run directly
xcodebuild -scheme CodeNest -configuration Debug -derivedDataPath build
```

After building, the app will launch automatically. To open a folder in CodeNest, use **File → Open** or drag a folder into the app. The app enables the Git panel only for folders with a `.git` directory.

## Architecture

The app uses a single-scene SwiftUI architecture with `NavigationSplitView` for the IDE layout:

- **`CodeNestApp.swift`** — `@main` entry; creates `WorkspaceState` as `@State`, injects via `.environment`, registers `Cmd+Shift+O` menu command
- **`ContentView.swift`** — `NavigationSplitView` root: sidebar + tab bar + editor + bottom panel
- **`Models/WorkspaceState.swift`** — `@Observable @MainActor` central state: open folder, file tree, tabs, Git state
- **`Models/FileNode.swift`** — `@Observable` recursive file tree node with lazy child loading
- **`Models/TabItem.swift`** — Value type for open editor tabs
- **`Models/GitState.swift`** — `@Observable @MainActor` Git repository state: current branch, file statuses, commit history
- **`Models/GitFileStatus.swift`** — Value type for file status (staged/unstaged/untracked)
- **`Models/GitCommit.swift`** — Value type for commit history entries (hash, message, author, date)
- **`Views/Sidebar/`** — Three-tab sidebar: Files (tree), Packages (project scaffold), Git (status + history)
  - **`SidebarView.swift`** — Tab switcher + header
  - **`FileTreeRowView.swift`** — Recursive `DisclosureGroup` for file tree with lazy expansion
  - **`GitPanelView.swift`** — Git status (staged/modified/untracked files), commit form, recent commits
  - **`PackagesPanelView.swift`** — Spring Boot Initializr UI for creating new projects
- **`Views/Tabs/TabBarView.swift`** — Horizontal scrolling tab strip with hover-close
- **`Views/Editor/CodeTextView.swift`** — `NSViewRepresentable` wrapping `NSTextView`; wires `SyntaxHighlighter` as `textStorage?.delegate`
- **`Views/Editor/EditorContainerView.swift`** — Tab content binding + empty state
- **`Views/Editor/DiffTextView.swift`** — Side-by-side diff viewer for staged/unstaged changes
- **`Views/Editor/BreadcrumbView.swift`** — File path breadcrumb navigation
- **`Views/BottomPanel/`** — Terminal and output views
  - **`BottomPanelView.swift`** — Tab switcher for Terminal and Output tabs
  - **`TerminalTabView.swift`** — Interactive shell session with pseudo-terminal
  - **`ShellSession.swift`** — Manages shell process and I/O
  - **`OutputTabView.swift`** — Read-only output display
- **`Views/Help/HelpView.swift`** — Help and documentation panel
- **`Views/NewProject/NewProjectSheet.swift`** — Modal for creating new projects via Initializr
- **`Syntax/`** — Syntax highlighting layer (see below)

The Xcode project uses **file system synchronized groups**, meaning new Swift files added to the `CodeNest/` directory are automatically included in the build without manually editing the project file.

## Services

Services wrap external system interactions and are stateless, static utilities:

- **`GitService`** — Static git command runner; methods include:
  - `run(args:at:)` — Core Process-based git executor; returns stdout or throws `GitError`
  - `isGitRepository(at:)`, `currentBranch(at:)` — Repository introspection
  - `status(at:)` — Parses null-delimited porcelain v1 output → `[GitFileStatus]`
  - `log(at:limit:)` — Parses commit history → `[GitCommit]` (short hash, message, author, date)
  - `stage(path:at:)`, `unstage(path:at:)`, `commit(message:at:)` — Git operations
  - `diff(for:staged:at:)` — Unified diff for a file
  - **Auto-configuration:** On first commit, if `user.name` or `user.email` missing, sets local defaults (`CodeNest User` / `user@codenest.local`)

- **`SpringInitializrService`** — HTTP client for Spring Boot Initializr API (start.spring.io); fetches available dependencies, starters, and generates project zips

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
