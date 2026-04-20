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

The app uses a single-scene SwiftUI architecture:

- **`CodeNestApp.swift`** — App entry point using `@main` and `WindowGroup`
- **`ContentView.swift`** — Root view; currently a placeholder with globe icon and "Hello, world!" text
- **`Assets.xcassets/`** — Asset catalog with app icon and accent color

The Xcode project uses **file system synchronized groups**, meaning new Swift files added to the `CodeNest/` directory are automatically included in the build without manually editing the project file.

## Swift Concurrency

The project enables strict concurrency settings:

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor` by default
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` — stricter concurrency warnings enabled
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` — stricter API boundary checking

Be explicit about `@MainActor`, `async/await`, and `Sendable` conformance when adding new code.
