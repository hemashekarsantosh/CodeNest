# CodeNest

A native macOS code editor built with SwiftUI, designed as a lightweight IDE for viewing and editing code files with syntax highlighting, integrated Git management, and a built-in terminal.

## Overview

CodeNest is a modern macOS application that provides a clean, native interface for browsing projects and editing code files. Currently in early development, the project demonstrates SwiftUI's capabilities for building desktop applications with focus on file tree navigation, tabbed editing, and syntax-aware code display.

**Platform:** macOS 14.0+ (tested on macOS Sequoia 26.4)  
**Language:** Swift  
**UI Framework:** SwiftUI  
**Build System:** Xcode 15.0+

## Features

- 📁 **File Tree Navigation** — Recursive folder browsing with lazy-loaded directory expansion
- 📑 **Tabbed Editor** — Open multiple files simultaneously with intuitive tab management
- 🎨 **Syntax Highlighting** — Language-aware code highlighting for Swift, JSON, Markdown, and generic text
- 🌓 **Adaptive UI** — Native support for macOS light and dark mode
- ⌨️ **Keyboard Shortcuts** — Cmd+Shift+O quick open (future expansion planned)
- 🏗️ **Project Support** — Java/Spring Boot project templates and dependency management
- 🔀 **Git Integration** — Branch indicator in toolbar with popover for staging, commits, and history
- 🖥️ **Integrated Terminal** — Run shell commands and view output inline

## Git Integration

CodeNest provides native Git integration accessible via the **branch indicator in the toolbar**:

- **Branch Pill** — Shows current branch name and dirty file count in the unified toolbar (Xcode-style)
- **Git Popover** — Click the branch pill to open a detailed git panel with:
  - **Staging & Commits** — Stage/unstage individual files, write commits, auto-config git user
  - **File Status** — View staged, modified, and untracked files with quick actions
  - **Commit History** — Visual graph of last 10 commits with branch refs and authorship
  - **Diff Viewer** — Side-by-side diffs for staged/unstaged changes
- **Git Folder Requirement** — Git panel only appears when a folder contains a `.git` directory

## Architecture

CodeNest follows a single-scene SwiftUI architecture with clear separation of concerns:

```
CodeNest/
├── CodeNestApp.swift              # @main entry point with unified toolbar style
├── ContentView.swift              # HStack root with toolbar branch pill
├── Models/
│   ├── WorkspaceState.swift       # @Observable central state
│   ├── FileNode.swift             # Recursive file tree nodes
│   ├── TabItem.swift              # Editor tab representation
│   ├── GitState.swift             # Git repo state & operations
│   ├── GitCommit.swift            # Commit data model
│   ├── GitFileStatus.swift        # File change tracking
│   └── Language.swift             # Language support
├── Views/
│   ├── Sidebar/                   # Files & Packages tabs
│   │   ├── GitGraphView.swift     # Commit graph visualization
│   │   └── GitPanelView.swift     # Git operations popover
│   ├── Tabs/                      # Tab bar & tab management
│   ├── Editor/                    # Code display & editing
│   ├── BottomPanel/               # Terminal & output
│   └── NewProject/                # Project creation UI
├── Services/
│   ├── GitService.swift           # Git command execution
│   └── SpringInitializrService.swift  # Spring Boot integration
└── Syntax/
    ├── SyntaxToken.swift          # Token types & themes
    ├── SyntaxGrammar.swift        # Grammar protocol
    ├── SwiftGrammar.swift         # Swift syntax rules
    ├── JSONGrammar.swift          # JSON syntax rules
    ├── MarkdownGrammar.swift      # Markdown syntax rules
    └── SyntaxHighlighter.swift    # Real-time highlighting
```

### Key Design Patterns

- **@Observable Pattern** — Uses Swift's `@Observable` macro (not `ObservableObject`) for state management, enabling strict concurrency
- **Lazy Loading** — File tree nodes load children on-demand for performance
- **Syntax Highlighting** — Incremental highlighting on edit, full re-highlight on file load
- **Environment Injection** — Centralized state injected via `.environment()` modifier

## Getting Started

### Prerequisites

- **Xcode 15.0+** (Swift 5.9+)
- **macOS 14.0+** for running the application

### Building

```bash
# Debug build
xcodebuild -scheme CodeNest -configuration Debug

# Release build
xcodebuild -scheme CodeNest -configuration Release

# List available schemes
xcodebuild -list -json

# Show build settings
xcodebuild -showBuildSettings
```

### Running

Open `CodeNest.xcodeproj` in Xcode and run the `CodeNest` scheme, or:

```bash
xcodebuild -scheme CodeNest -configuration Debug -derivedDataPath build run
```

## Development

### Code Structure

- **State Management** — All state types use `@Observable @MainActor` with strict concurrency enabled
- **UI Components** — SwiftUI views with `@Environment` access to shared state
- **Bindings** — Use `@Bindable` for reactive property updates on `@Observable` objects

### Adding a New Language

Create a new grammar file conforming to `SyntaxGrammar` protocol:

```swift
struct MyLanguageGrammar: SyntaxGrammar {
    let rules: [SyntaxRule] = [
        // Define syntax rules in priority order (highest to lowest)
    ]
}
```

Then add a case to `Language.grammar(for:)`:

```swift
case .myLanguage:
    return MyLanguageGrammar()
```

### Testing

CodeNest uses **SwiftUI Previews** (`#Preview`) for UI validation during development. Navigate to any view file and use Xcode's Preview Canvas to test UI behavior.

## Supported Languages

- **Swift** — Full syntax highlighting
- **JSON** — Key-value pair highlighting
- **Markdown** — Common markdown elements
- **Generic Text** — Fallback for unsupported formats

## Project Management

- **Task Tracking** — Use Linear or GitHub Issues for bug reports and feature requests
- **CI/CD** — Configured via GitHub Actions (if applicable)
- **Code Style** — Follow Swift API Design Guidelines and SwiftUI best practices

## Swift Concurrency

This project enables strict Swift concurrency settings:

```swift
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
```

All new code must be explicit about actor isolation and `Sendable` conformance.

## Debugging

**Xcode Console** — View application logs and runtime warnings  
**View Hierarchy Debugger** — Inspect SwiftUI view structure  
**SwiftUI Previews** — Real-time UI testing during development

## Future Enhancements

- [ ] Text editing with document save
- [ ] Search within files
- [ ] Find and replace
- [ ] Additional language support (Python, JavaScript, Go, Rust)
- [ ] Theme customization
- [ ] Diff viewer enhancements
- [ ] Merge conflict resolution UI

## License

This project is open source and currently in development.

## Author

**Santosh H**  
Email: itssanbharlee@gmail.com

---

For detailed development guidance, see [CLAUDE.md](./CLAUDE.md).
