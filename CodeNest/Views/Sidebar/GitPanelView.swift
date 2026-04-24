import SwiftUI

struct GitPanelView: View {
    @Bindable var gitState: GitState
    @Environment(WorkspaceState.self) var workspace
    @State private var showCommits = true

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
                // Commit form at top
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $gitState.commitMessage)
                        .font(.system(.body, design: .monospaced))
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

                // Two-column layout
                HStack(spacing: 0) {
                    // Left: File Status
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            let stagedFiles = gitState.fileStatuses.filter { $0.isStaged }
                            let modifiedFiles = gitState.fileStatuses.filter {
                                !$0.isStaged && $0.worktreeStatus == .modified
                            }
                            let untrackedFiles = gitState.fileStatuses.filter {
                                $0.indexStatus == .untracked
                            }

                            // Stage all button
                            if !modifiedFiles.isEmpty || !untrackedFiles.isEmpty {
                                Button(action: {
                                    for file in modifiedFiles + untrackedFiles {
                                        gitState.stage(file.path)
                                    }
                                }) {
                                    Text("Stage All")
                                        .font(.system(.caption, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.horizontal, 4)
                            }

                            if !stagedFiles.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Staged Changes")
                                        .font(.system(.subheadline, weight: .semibold))
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
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Modified")
                                        .font(.system(.subheadline, weight: .semibold))
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
                                        .font(.system(.subheadline, weight: .semibold))
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
                    .frame(minWidth: 250, maxWidth: 320)

                    Divider()

                    // Right: Recent Commits
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recent Commits (\(gitState.commits.count))")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 6)

                        if !gitState.commits.isEmpty {
                            let graphNodes = CommitGraphLayout.compute(gitState.commits)
                            GitGraphView(nodes: graphNodes, currentBranch: gitState.currentBranch)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 6)
                .fill(.background)
                .stroke(.separator, lineWidth: 1)

            VStack(alignment: .leading, spacing: 6) {
                // Row 1: Status badge + filename
                HStack(spacing: 6) {
                    // Status badge
                    Text(file.displayCode)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(file.indexStatus != .unmodified ? file.indexStatus.badgeColor : .gray)
                        .cornerRadius(3)

                    // File name only (not full path)
                    Text(URL(fileURLWithPath: file.path).lastPathComponent)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Row 2: Action button (full width)
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
