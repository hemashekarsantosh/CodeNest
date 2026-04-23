import Foundation

struct GitCommit: Identifiable {
    let id: String        // short hash
    let message: String
    let author: String
    let date: String      // formatted date string (e.g. "2026-04-23")
}
