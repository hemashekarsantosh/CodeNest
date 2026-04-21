//
//  OutputTabView.swift
//  CodeNest
//

import SwiftUI

struct OutputTabView: View {
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                Text(workspace.runOutput.isEmpty ? " " : workspace.runOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color.black)

            if !workspace.runOutput.isEmpty {
                Button("Clear") {
                    workspace.runOutput = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(8)
            }
        }
    }
}
