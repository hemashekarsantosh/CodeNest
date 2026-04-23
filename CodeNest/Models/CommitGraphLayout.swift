import SwiftUI

struct CommitGraphNode {
    let commit: GitCommit
    let column: Int
    let color: Color
    let edges: [GraphEdge]
}

struct GraphEdge {
    let fromColumn: Int
    let toColumn: Int
    let color: Color

    // Edge type: straight vertical, or diagonal merge
    var isDiagonal: Bool {
        fromColumn != toColumn
    }
}

enum CommitGraphLayout {
    /// Layout algorithm: takes ordered commits (newest→oldest from git log)
    /// and assigns each to a column with edge information for drawing.
    static func compute(_ commits: [GitCommit]) -> [CommitGraphNode] {
        guard !commits.isEmpty else { return [] }

        // Map commit hash to its index in the list
        let commitIndex = Dictionary(
            uniqueKeysWithValues: commits.enumerated().map { ($0.element.id, $0.offset) }
        )

        // Track active columns: [String?] where String is the commit hash being tracked in that column
        var activeColumns: [String?] = []

        // Assign each commit to a column
        var columnAssignments: [String: Int] = [:]
        var nodes: [CommitGraphNode] = []

        let colorPalette: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]

        for (index, commit) in commits.enumerated() {
            // Find or assign column for this commit
            var commitColumn = activeColumns.firstIndex { $0 == commit.id }

            if commitColumn == nil {
                // Not already assigned, find first free column
                if let freeIndex = activeColumns.firstIndex(where: { $0 == nil }) {
                    commitColumn = freeIndex
                    activeColumns[freeIndex] = commit.id
                } else {
                    // Open new column
                    commitColumn = activeColumns.count
                    activeColumns.append(commit.id)
                }
            }

            let col = commitColumn!
            columnAssignments[commit.id] = col

            // Build edges from this commit to its parents
            var edges: [GraphEdge] = []

            for (parentIndex, parentHash) in commit.parents.enumerated() {
                // Find parent in future commits (they have higher indices)
                guard let parentCommitIndex = commitIndex[parentHash],
                      parentCommitIndex > index else {
                    continue
                }

                // Assign column to parent
                let parentCol: Int
                if parentIndex == 0 {
                    // First parent: continue in same column (or closest free)
                    parentCol = col
                    if activeColumns[col] == commit.id {
                        activeColumns[col] = parentHash
                    }
                } else {
                    // Additional parents: open new column
                    if let freeIndex = activeColumns.firstIndex(where: { $0 == nil }) {
                        parentCol = freeIndex
                        activeColumns[freeIndex] = parentHash
                    } else {
                        parentCol = activeColumns.count
                        activeColumns.append(parentHash)
                    }
                }

                columnAssignments[parentHash] = parentCol

                let color = colorPalette[parentCol % colorPalette.count]
                edges.append(GraphEdge(fromColumn: col, toColumn: parentCol, color: color))
            }

            // Mark this commit as done in its column
            if activeColumns[col] == commit.id {
                activeColumns[col] = nil
            }

            let color = colorPalette[col % colorPalette.count]
            let node = CommitGraphNode(
                commit: commit,
                column: col,
                color: color,
                edges: edges
            )
            nodes.append(node)
        }

        return nodes
    }
}
