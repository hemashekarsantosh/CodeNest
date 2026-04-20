//
//  ShellSession.swift
//  CodeNest
//

import Foundation

@MainActor
final class ShellSession {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let onOutput: (String) -> Void

    init(onOutput: @escaping @MainActor (String) -> Void) {
        self.onOutput = onOutput
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stdoutPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in onOutput(str) }
        }

        try? process.run()
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        stdinPipe.fileHandleForWriting.write(data)
    }

    func terminate() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        process.terminate()
    }
}
