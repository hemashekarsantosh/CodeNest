//
//  BottomPanelView.swift
//  CodeNest
//

import SwiftUI

enum BottomTab {
    case output, terminal
}

struct BottomPanelView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        @Bindable var ws = workspace
        VStack(spacing: 0) {
            // Header tab bar
            HStack(spacing: 0) {
                tabButton("Output", tab: .output)
                tabButton("Terminal", tab: .terminal)
                Spacer()
                if workspace.isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }
                Button {
                    workspace.isBottomPanelVisible = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 10)
            }
            .frame(height: 28)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            switch workspace.selectedBottomTab {
            case .output:
                OutputTabView()
            case .terminal:
                TerminalTabView()
            }
        }
    }

    @ViewBuilder
    private func tabButton(_ title: String, tab: BottomTab) -> some View {
        let isSelected = workspace.selectedBottomTab == tab
        Button(action: { workspace.selectedBottomTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
