//
//  ContentView.swift
//  CodeNest
//
//  Created by Santosh Hemashekar on 20/04/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(WorkspaceState.self) var workspace
    @Environment(GitState.self) var gitState

    @State private var sidebarWidth: CGFloat = 240
    @State private var isSidebarCollapsed: Bool = false
    @State private var showGitPopover: Bool = false

    private let minSidebarWidth: CGFloat = 160
    private let maxSidebarWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            if !isSidebarCollapsed {
                SidebarView()
                    .frame(width: sidebarWidth)

                SidebarDivider { delta in
                    sidebarWidth = max(minSidebarWidth, min(maxSidebarWidth, sidebarWidth + delta))
                }
            }

            VStack(spacing: 0) {
                if !workspace.openTabs.isEmpty {
                    TabBarView()
                    Divider()
                    BreadcrumbView()
                    Divider()
                }
                EditorContainerView()
                if !workspace.openTabs.isEmpty && workspace.isBottomPanelVisible {
                    Divider()
                    BottomPanelView()
                        .frame(height: 200)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(isSidebarCollapsed ? "Show Sidebar" : "Hide Sidebar")
            }

            ToolbarItem(placement: .principal) {
                if gitState.isGitRepo, let branch = gitState.currentBranch {
                    Button {
                        showGitPopover.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 11))
                            Text(branch)
                                .font(.system(size: 12, weight: .medium))
                            let dirtyCount = gitState.fileStatuses.count
                            if dirtyCount > 0 {
                                Text("\(dirtyCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.85))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("Source Control – \(branch)")
                    .popover(isPresented: $showGitPopover, arrowEdge: .bottom) {
                        GitPanelView(gitState: gitState)
                            .environment(workspace)
                            .frame(width: 320, height: 500)
                    }
                }
            }
        }
        .sheet(isPresented: Bindable(workspace).isHelpPresented) {
            HelpView(tab: workspace.helpTab)
                .environment(workspace)
        }
        .sheet(isPresented: Bindable(workspace).showNewProjectSheet) {
            NewProjectSheet()
                .environment(workspace)
        }
        .onAppear {
            workspace.restoreWorkspaceIfNeeded()
        }
    }
}

struct SidebarDivider: View {
    /// Called each drag event with the incremental delta (not cumulative).
    let onDrag: (CGFloat) -> Void

    @State private var isHovering = false
    @GestureState private var lastTranslation: CGFloat = 0

    var body: some View {
        ZStack {
            Color(nsColor: .separatorColor).frame(width: 1)
            Color.clear.frame(width: 8).contentShape(Rectangle())
        }
        .frame(width: 8)
        .overlay(alignment: .center) {
            if isHovering {
                Color.accentColor.opacity(0.5).frame(width: 2)
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .updating($lastTranslation) { value, state, _ in
                    let delta = value.translation.width - state
                    state = value.translation.width
                    onDrag(delta)
                }
        )
    }
}
