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
                Button("Open Folder...") {
                    workspace.openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
