import Foundation
import Observation

@Observable @MainActor final class GitState {
    var rootURL: URL?
    var isGitRepo: Bool = false
    var currentBranch: String?
    var fileStatuses: [GitFileStatus] = []
    var statusByPath: [String: GitFileStatus] = [:]
    var commits: [GitCommit] = []
    var commitMessage: String = ""
    var isRefreshing: Bool = false

    func setRoot(_ url: URL) {
        rootURL = url
        fileStatuses = []
        statusByPath = [:]
        commits = []
        commitMessage = ""
        refresh()
    }

    func refresh() {
        guard let rootURL else { return }
        Task.detached {
            let isGit = await GitService.isGitRepository(at: rootURL)
            let branch = await GitService.currentBranch(at: rootURL)
            let statuses = await GitService.status(at: rootURL)
            let commits = await GitService.log(at: rootURL)

            let stagedCount = statuses.filter { $0.isStaged }.count
            let totalCount = statuses.count

            print("🔄 Git: Refreshed status - \(stagedCount)/\(totalCount) files staged")

            await MainActor.run {
                self.isGitRepo = isGit
                self.currentBranch = branch
                self.fileStatuses = statuses
                self.statusByPath = Dictionary(uniqueKeysWithValues: statuses.map { ($0.path, $0) })
                self.commits = commits
                self.isRefreshing = false
            }
        }
    }

    func stage(_ path: String) {
        Task {
            guard let rootURL else {
                print("❌ Git: No repository loaded")
                return
            }
            do {
                print("📝 Git: Staging \(path)...")
                try await GitService.stage(path: path, at: rootURL)
                print("✅ Git: Staged \(path)")
                // Wait a moment for git to write changes, then refresh
                try await Task.sleep(nanoseconds: 200_000_000)
                refresh()
            } catch {
                print("❌ Git: Failed to stage \(path) - \(error.localizedDescription)")
            }
        }
    }

    func unstage(_ path: String) {
        Task {
            guard let rootURL else {
                print("❌ Git: No repository loaded")
                return
            }
            do {
                print("📝 Git: Unstaging \(path)...")
                try await GitService.unstage(path: path, at: rootURL)
                print("✅ Git: Unstaged \(path)")
                // Wait a moment for git to write changes, then refresh
                try await Task.sleep(nanoseconds: 200_000_000)
                refresh()
            } catch {
                print("❌ Git: Failed to unstage \(path) - \(error.localizedDescription)")
            }
        }
    }

    func commit() {
        Task {
            guard let rootURL else {
                print("❌ Git: No repository loaded")
                return
            }
            let msg = commitMessage
            guard !msg.trimmingCharacters(in: .whitespaces).isEmpty else {
                print("❌ Git: Commit message is empty")
                return
            }

            let stagedCount = fileStatuses.filter { $0.isStaged }.count
            guard stagedCount > 0 else {
                print("❌ Git: No files staged for commit")
                return
            }

            do {
                print("📝 Git: Committing \(stagedCount) files...")
                isRefreshing = true
                try await GitService.commit(message: msg, at: rootURL)
                print("✅ Git: Commit successful!")
                await MainActor.run {
                    self.commitMessage = ""
                    self.isRefreshing = false
                }
                // Wait a moment then refresh to ensure git has written the commit
                try await Task.sleep(nanoseconds: 500_000_000)
                refresh()
            } catch {
                print("❌ Git: Commit failed - \(error.localizedDescription)")
                await MainActor.run {
                    self.isRefreshing = false
                }
            }
        }
    }

    func getDiff(for path: String, staged: Bool) async -> String {
        guard let rootURL else { return "" }
        return await GitService.diff(for: path, staged: staged, at: rootURL)
    }

    func relativePath(for url: URL) -> String? {
        guard let rootURL else { return nil }
        let rootPath = rootURL.path
        let urlPath = url.path

        if urlPath.hasPrefix(rootPath + "/") {
            return String(urlPath.dropFirst(rootPath.count + 1))
        } else if urlPath == rootPath {
            return "."
        }
        return nil
    }
}
