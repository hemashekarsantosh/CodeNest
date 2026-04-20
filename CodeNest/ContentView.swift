//
//  ContentView.swift
//  CodeNest
//
//  Created by Santosh Hemashekar on 20/04/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                if !workspace.openTabs.isEmpty {
                    TabBarView()
                    Divider()
                    BreadcrumbView()
                    Divider()
                }
                EditorContainerView()
                if !workspace.openTabs.isEmpty {
                    Divider()
                    BottomPanelView()
                        .frame(height: 200)
                }
            }
        }
        .onAppear {
            workspace.restoreWorkspaceIfNeeded()
        }
    }
}
