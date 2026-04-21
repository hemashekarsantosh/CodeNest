//
//  HelpView.swift
//  CodeNest
//

import SwiftUI

enum HelpTab {
    case shortcuts, about
}

struct HelpView: View {
    @Environment(WorkspaceState.self) var workspace
    @State private var selectedTab: HelpTab

    init(tab: HelpTab = .shortcuts) {
        _selectedTab = State(initialValue: tab)
    }

    private let shortcuts: [(action: String, keys: String)] = [
        ("Open File",        "⌘ O"),
        ("Open Folder",      "⌘ ⇧ O"),
        ("Run",              "⌘ R"),
        ("Close Tab",        "⌘ W"),
        ("Toggle Sidebar",   "toolbar button"),
        ("Keyboard Shortcuts", "⌘ ?"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CodeNest Help")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    workspace.isHelpPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Keyboard Shortcuts").tag(HelpTab.shortcuts)
                Text("About").tag(HelpTab.about)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Content
            Group {
                if selectedTab == .shortcuts {
                    shortcutsContent
                } else {
                    aboutContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 380)
    }

    private var shortcutsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(shortcuts, id: \.action) { item in
                    HStack {
                        Text(item.action)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(item.keys)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    if item.action != shortcuts.last?.action {
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var aboutContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text("CodeNest")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("A lightweight native macOS code editor\nbuilt with SwiftUI.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("© 2026 Santosh Hemashekar")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
