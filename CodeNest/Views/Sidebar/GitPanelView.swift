import SwiftUI

struct GitPanelView: View {
    @Bindable var gitState: GitState
    @Environment(WorkspaceState.self) var workspace

    var body: some View {
        if !gitState.isGitRepo {
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Not a Git Repository")
                    .font(.headline)
                Text("Open a folder with a .git directory to enable source control.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            VStack(spacing: 0) {
                // Commit section
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $gitState.commitMessage)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 60)
                        .border(.separator, width: 1)

                    Button(action: {
                        gitState.commit()
                    }) {
                        if gitState.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Commit \(gitState.fileStatuses.filter { $0.isStaged }.count) files")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(gitState.fileStatuses.filter { $0.isStaged }.isEmpty || gitState.isRefreshing)
                }
                .padding()
                .borderBottom(height: 1)

                // Status sections
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let stagedFiles = gitState.fileStatuses.filter { $0.isStaged }
                        let modifiedFiles = gitState.fileStatuses.filter {
                            !$0.isStaged && $0.worktreeStatus == .modified
                        }
                        let untrackedFiles = gitState.fileStatuses.filter {
                            $0.indexStatus == .untracked
                        }

                        if !stagedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Staged Changes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(stagedFiles) { file in
                                    GitFileRowView(
                                        file: file,
                                        action: {
                                            gitState.unstage(file.path)
                                        },
                                        actionLabel: "Unstage",
                                        onTap: {
                                            Task {
                                                await workspace.openDiffTab(for: file.path)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        if !modifiedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Modified")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(modifiedFiles) { file in
                                    GitFileRowView(
                                        file: file,
                                        action: {
                                            gitState.stage(file.path)
                                        },
                                        actionLabel: "Stage",
                                        onTap: {
                                            Task {
                                                await workspace.openDiffTab(for: file.path)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        if !untrackedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Untracked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(untrackedFiles) { file in
                                    GitFileRowView(
                                        file: file,
                                        action: {
                                            gitState.stage(file.path)
                                        },
                                        actionLabel: "Stage",
                                        onTap: {
                                            Task {
                                                await workspace.openDiffTab(for: file.path)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        if stagedFiles.isEmpty && modifiedFiles.isEmpty && untrackedFiles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.green)
                                Text("No changes")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

struct GitFileRowView: View {
    let file: GitFileStatus
    let action: () -> Void
    let actionLabel: String
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(file.displayCode)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(file.indexStatus != .unmodified ? file.indexStatus.badgeColor : .gray)
                    .cornerRadius(2)

                Text(file.path)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    Button(action: action) {
                        Text(actionLabel)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    let gitState = GitState()
    GitPanelView(gitState: gitState)
        .environment(WorkspaceState())
}

extension View {
    func borderBottom(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            self
            Divider().frame(height: height)
        }
    }
}
