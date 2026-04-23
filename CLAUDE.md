# CLAUDE.md

File guides Claude Code (claude.ai/code) when working with code in repo.

## Project Overview

**CodeNest**: native macOS IDE, SwiftUI-built, macOS 26.4 (Sequoia). Lightweight code editor: syntax highlighting, Git integration, terminal, project scaffolding.

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** macOS
- **App Bundle ID:** io.santosh.CodeNest
- **Build System:** Xcode (project file: `CodeNest.xcodeproj`)

**Core Features:**
- Syntax highlighting: Swift, JSON, Markdown, generic files
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

No unit test targets. SwiftUI Previews (`#Preview`): primary UI validation.

## Running the App

```bash
# Build and run in Xcode
open CodeNest.xcodeproj

# Or build and run directly
xcodebuild -scheme CodeNest -configuration Debug -derivedDataPath build
```

After build, app launches auto. Open folder: **File → Open** or drag into app. Git panel enabled only for folders with `.git`.

## Architecture

Single-scene SwiftUI, NavigationSplitView IDE layout:

- **`CodeNestApp.swift`** — `@main` entry; creates `WorkspaceState` @State, injects via `.environment`, registers `Cmd+Shift+O` menu
- **`ContentView.swift`** — `NavigationSplitView` root: sidebar + tab bar + editor + bottom panel
- **`Models/WorkspaceState.swift`** — `@Observable @MainActor` central state: open folder, file tree, tabs, Git state
- **`Models/FileNode.swift`** — `@Observable` recursive file tree node, lazy child loading
- **`Models/TabItem.swift`** — Value type for open editor tabs
- **`Models/GitState.swift`** — `@Observable @MainActor` Git repo state: branch, file statuses, commit history
- **`Models/GitFileStatus.swift`** — Value type for file status (staged/unstaged/untracked)
- **`Models/GitCommit.swift`** — Value type for commit entries (hash, message, author, date)
- **`Views/Sidebar/`** — Three-tab sidebar: Files (tree), Packages (project scaffold), Git (status + history)
  - **`SidebarView.swift`** — Tab switcher + header
  - **`FileTreeRowView.swift`** — Recursive `DisclosureGroup` for file tree, lazy expansion
  - **`GitPanelView.swift`** — Git status (staged/modified/untracked), commit form, recent commits
  - **`PackagesPanelView.swift`** — Spring Boot Initializr UI for new projects
- **`Views/Tabs/TabBarView.swift`** — Horizontal scrolling tab strip, hover-close
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
- **`Views/NewProject/NewProjectSheet.swift`** — Modal for new projects via Initializr
- **`Syntax/`** — Syntax highlighting layer (see below)

Xcode project uses **file system synchronized groups** — new Swift files in `CodeNest/` auto-included without manual project file edits.

## Services

Services: stateless, static utilities wrapping external system interactions.

- **`GitService`** — Static git command runner; methods include:
  - `run(args:at:)` — Core Process-based git executor; returns stdout or throws `GitError`
  - `isGitRepository(at:)`, `currentBranch(at:)` — Repository introspection
  - `status(at:)` — Parses null-delimited porcelain v1 output → `[GitFileStatus]`
  - `log(at:limit:)` — Parses commit history → `[GitCommit]` (short hash, message, author, date)
  - `stage(path:at:)`, `unstage(path:at:)`, `commit(message:at:)` — Git operations
  - `diff(for:staged:at:)` — Unified diff for file
  - **Auto-configuration:** On first commit, if `user.name` or `user.email` missing, sets local defaults (`CodeNest User` / `user@codenest.local`)

- **`SpringInitializrService`** — HTTP client for Spring Boot Initializr API (start.spring.io); fetches dependencies, starters, generates zips

## Syntax Highlighting

Files in `CodeNest/Syntax/`:

- **`SyntaxToken.swift`** — `TokenType` enum + `HighlightTheme` (adaptive dark/light `NSColor` via `NSColor(name:dynamicProvider:)`)
- **`SyntaxGrammar.swift`** — `SyntaxRule` (pre-compiled `NSRegularExpression` + token type), `SyntaxGrammar` protocol, `Language.grammar(for:)` factory
- **`SwiftGrammar.swift`**, **`JSONGrammar.swift`**, **`MarkdownGrammar.swift`**, **`GenericGrammar.swift`** — Concrete grammars; rules ordered highest-to-lowest priority (first match wins)
- **`SyntaxHighlighter.swift`** — `@MainActor NSTextStorageDelegate`; hooks into `textStorage(_:didProcessEditing:range:changeInLength:)`; re-highlights only edited line range on keystrokes, full document on file load

**Key invariant:** `guard editedMask.contains(.editedCharacters) else { return }` in `SyntaxHighlighter` prevents infinite loops — attribute-only changes (highlighter's own) skipped.

**Add language:** create struct conforming `SyntaxGrammar`, add case to `Language.grammar(for:)`.

## Observable Pattern

Project uses `@Observable` (not `ObservableObject`) for all state. Required: `InferIsolatedConformances` makes `@MainActor` `ObservableObject` incompatible with SwiftUI injection.

- Injection: `.environment(workspace)` / `@Environment(WorkspaceState.self) var workspace`
- Bindings on `@Observable` use `@Bindable` (e.g., `@Bindable var node: FileNode` to get `$node.isExpanded`)

## Swift Concurrency

Project enables strict concurrency:

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types implicitly `@MainActor` by default
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — stricter concurrency warnings
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — stricter API boundary checking

Be explicit: `@MainActor`, `async/await`, `Sendable` when adding code.