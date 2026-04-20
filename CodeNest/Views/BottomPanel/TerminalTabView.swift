//
//  TerminalTabView.swift
//  CodeNest
//

import SwiftUI

struct TerminalTabView: View {
    @Environment(WorkspaceState.self) var workspace
    @State private var output: String = ""
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? " " : output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .background(Color.black)
                .onChange(of: output) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            Divider()

            HStack(spacing: 6) {
                Text("$")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.green)
                TextField("", text: $input)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.green)
                    .onSubmit {
                        let cmd = input
                        output += "$ \(cmd)\n"
                        workspace.terminalSession?.send(cmd + "\n")
                        input = ""
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black)
        }
        .onAppear {
            if workspace.terminalSession == nil {
                workspace.terminalSession = ShellSession { [self] data in
                    output += data
                }
            }
        }
    }
}
