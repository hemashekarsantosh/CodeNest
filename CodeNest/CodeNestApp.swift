 //
//  CodeNestApp.swift
//  CodeNest
//
//  Created by Santosh Hemashekar on 20/04/26.
//

import SwiftUI

@main
struct CodeNestApp: App {
    @State private var workspace = WorkspaceState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    workspace.openFileFromPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder...") {
                    workspace.openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Run") {
                    workspace.runActiveTab()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    workspace.openHelp(tab: .shortcuts)
                }
                .keyboardShortcut("/", modifiers: .command)
                Button("About CodeNest") {
                    workspace.openHelp(tab: .about)
                }
            }
        }
    }
}
