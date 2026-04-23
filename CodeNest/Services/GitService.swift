import Foundation

enum GitError: LocalizedError {
    case commandFailed(command: String, message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let message):
            return "Git command failed: \(command)\n\(message)"
        }
    }
}

struct GitService {
    nonisolated static let gitPath = "/usr/bin/git"

    /// Run a git command with arguments in the given working directory.
    /// Returns stdout as a String, throws if command fails.
    nonisolated static func run(args: [String], at cwd: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.currentDirectoryURL = cwd

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        // Check exit status
        if process.terminationStatus != 0 {
            let errorMsg = stderr.isEmpty ? stdout : stderr
            throw GitError.commandFailed(command: "git \(args.joined(separator: " "))", message: errorMsg)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if a directory is a git repository.
    nonisolated static func isGitRepository(at rootURL: URL) async -> Bool {
        do {
            _ = try await run(args: ["rev-parse", "--git-dir"], at: rootURL)
            return true
        } catch {
            return false
        }
    }

    /// Get the current branch name.
    nonisolated static func currentBranch(at rootURL: URL) async -> String? {
        do {
            let output = try await run(args: ["rev-parse", "--abbrev-ref", "HEAD"], at: rootURL)
            return output.isEmpty ? nil : output
        } catch {
            return nil
        }
    }

    /// Get the list of file statuses using `git status --porcelain=v1 -z`.
    /// Returns an array of GitFileStatus structs.
    nonisolated static func status(at rootURL: URL) async -> [GitFileStatus] {
        do {
            let output = try await run(args: ["status", "--porcelain=v1", "-z"], at: rootURL)
            return parseStatusOutput(output, rootURL: rootURL)
        } catch {
            return []
        }
    }

    /// Get the unified diff for a file.
    nonisolated static func diff(for path: String, staged: Bool, at rootURL: URL) async -> String {
        do {
            var args = ["diff", "--no-color"]
            if staged {
                args.append("--cached")
            }
            args.append("--")
            args.append(path)
            return try await run(args: args, at: rootURL)
        } catch {
            return "Error generating diff: \(error.localizedDescription)"
        }
    }

    /// Stage a file (add it to the index).
    nonisolated static func stage(path: String, at rootURL: URL) async throws {
        _ = try await run(args: ["add", "--", path], at: rootURL)
    }

    /// Unstage a file (remove it from the index, but keep changes).
    nonisolated static func unstage(path: String, at rootURL: URL) async throws {
        _ = try await run(args: ["restore", "--staged", "--", path], at: rootURL)
    }

    /// Commit staged changes with the given message.
    nonisolated static func commit(message: String, at rootURL: URL) async throws {
        // Ensure git is configured with user info
        _ = try await configureGitIfNeeded(at: rootURL)
        _ = try await run(args: ["commit", "-m", message], at: rootURL)
    }

    /// Ensure git user.name and user.email are configured (at least locally).
    nonisolated private static func configureGitIfNeeded(at rootURL: URL) async throws {
        do {
            let name = try await run(args: ["config", "user.name"], at: rootURL)
            let email = try await run(args: ["config", "user.email"], at: rootURL)
            if name.isEmpty || email.isEmpty {
                throw GitError.commandFailed(
                    command: "git config",
                    message: "Git user.name or user.email is not configured. Run `git config user.name 'Your Name'` and `git config user.email 'your@email.com'`"
                )
            }
        } catch {
            // If config is missing, try to set defaults
            do {
                _ = try await run(args: ["config", "--local", "user.name", "CodeNest User"], at: rootURL)
                _ = try await run(args: ["config", "--local", "user.email", "user@codenest.local"], at: rootURL)
            } catch {
                throw GitError.commandFailed(
                    command: "git config",
                    message: "Could not configure git. Please run: git config user.name 'Your Name' && git config user.email 'your@email.com'"
                )
            }
        }
    }

    /// Parse `git status --porcelain=v1 -z` output.
    /// Each record is: XY PATH\0, where XY is two status characters and PATH starts at index 3.
    private nonisolated static func parseStatusOutput(_ output: String, rootURL: URL) -> [GitFileStatus] {
        let records = output.split(separator: "\0", omittingEmptySubsequences: true)
        var statuses: [GitFileStatus] = []

        for record in records {
            let recordStr = String(record)
            guard recordStr.count >= 3 else { continue }

            let indexChar = recordStr[recordStr.index(recordStr.startIndex, offsetBy: 0)]
            let worktreeChar = recordStr[recordStr.index(recordStr.startIndex, offsetBy: 1)]
            let path = String(recordStr.dropFirst(3))

            guard let indexStatus = GitStatusCode(from: indexChar),
                  let worktreeStatus = GitStatusCode(from: worktreeChar)
            else {
                continue
            }

            let fileStatus = GitFileStatus(
                id: path,
                path: path,
                indexStatus: indexStatus,
                worktreeStatus: worktreeStatus
            )
            statuses.append(fileStatus)
        }

        return statuses
    }
}
