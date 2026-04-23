import SwiftUI

struct GitGraphView: View {
    let nodes: [CommitGraphNode]
    let currentBranch: String?

    private let columnWidth: CGFloat = 12
    private let rowHeight: CGFloat = 28
    private let circleRadius: CGFloat = 4
    private let graphPadding: CGFloat = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(nodes.enumerated()), id: \.element.commit.id) { index, node in
                    HStack(alignment: .top, spacing: 8) {
                        // Graph section
                        Canvas { context, size in
                            drawGraphRow(
                                node: node,
                                isLastRow: index == nodes.count - 1,
                                context: &context,
                                size: size
                            )
                        }
                        .frame(width: graphWidth, height: rowHeight)
                        .background(.clear)

                        // Commit info section
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(node.commit.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                if !node.commit.refs.isEmpty {
                                    ForEach(node.commit.refs, id: \.self) { ref in
                                        RefBadge(ref: ref, currentBranch: currentBranch)
                                    }
                                }
                            }

                            Text(node.commit.message)
                                .font(.caption)
                                .lineLimit(1)

                            Text("\(node.commit.author) · \(node.commit.date)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxHeight: rowHeight, alignment: .top)

                        Spacer()
                    }
                    .padding(.horizontal, graphPadding)
                    .padding(.vertical, 2)
                    .frame(height: rowHeight)

                    if index < nodes.count - 1 {
                        Divider().padding(.leading, graphPadding + graphWidth)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var graphWidth: CGFloat {
        if nodes.isEmpty { return columnWidth }
        let maxCol = nodes.map(\.column).max() ?? 0
        return CGFloat(maxCol + 1) * columnWidth
    }

    private func drawGraphRow(
        node: CommitGraphNode,
        isLastRow: Bool,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let centerX = CGFloat(node.column) * columnWidth + columnWidth / 2
        let centerY = rowHeight / 2

        // Draw edges (lines to parents)
        for edge in node.edges {
            let fromX = CGFloat(edge.fromColumn) * columnWidth + columnWidth / 2
            let toX = CGFloat(edge.toColumn) * columnWidth + columnWidth / 2

            if edge.isDiagonal {
                // Diagonal line to merge point
                var path = Path()
                path.move(to: CGPoint(x: fromX, y: centerY))
                path.addLine(to: CGPoint(x: toX, y: rowHeight - 2))
                context.stroke(
                    path,
                    with: .color(edge.color.opacity(0.6)),
                    lineWidth: 1.5
                )
            } else {
                // Straight vertical line
                var path = Path()
                path.move(to: CGPoint(x: fromX, y: centerY))
                path.addLine(to: CGPoint(x: fromX, y: rowHeight - 2))
                context.stroke(
                    path,
                    with: .color(edge.color.opacity(0.6)),
                    lineWidth: 1.5
                )
            }
        }

        // Draw circle at commit position
        let circlePath = Path(
            ellipseIn: CGRect(
                x: centerX - circleRadius,
                y: centerY - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
        )
        context.fill(circlePath, with: .color(node.color))

        // Draw ring if this is current branch HEAD
        if node.commit.refs.contains(where: { $0.hasPrefix("HEAD") }) {
            let ringPath = Path(
                ellipseIn: CGRect(
                    x: centerX - circleRadius - 2,
                    y: centerY - circleRadius - 2,
                    width: (circleRadius + 2) * 2,
                    height: (circleRadius + 2) * 2
                )
            )
            context.stroke(ringPath, with: .color(node.color), lineWidth: 1)
        }
    }
}

struct RefBadge: View {
    let ref: String
    let currentBranch: String?

    private var isCurrentBranch: Bool {
        ref.contains("HEAD")
    }

    private var displayLabel: String {
        // Parse ref: "HEAD -> main" or "origin/main" etc
        if ref.contains("HEAD -> ") {
            let parts = ref.split(separator: " -> ")
            return parts.count > 1 ? String(parts[1]) : ref
        }
        return ref
    }

    var body: some View {
        Text(displayLabel)
            .font(.caption2)
            .foregroundStyle(isCurrentBranch ? .white : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isCurrentBranch ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
            .cornerRadius(3)
    }
}

#Preview {
    let sampleCommits = [
        GitCommit(
            id: "abc1234",
            message: "Add feature X",
            author: "Alice",
            date: "2026-04-23",
            parents: ["def5678"],
            refs: ["HEAD -> main"]
        ),
        GitCommit(
            id: "def5678",
            message: "Fix bug Y",
            author: "Bob",
            date: "2026-04-22",
            parents: ["ghi9012"],
            refs: ["origin/main"]
        ),
        GitCommit(
            id: "ghi9012",
            message: "Initial commit",
            author: "Charlie",
            date: "2026-04-21",
            parents: [],
            refs: []
        ),
    ]

    let nodes = CommitGraphLayout.compute(sampleCommits)
    GitGraphView(nodes: nodes, currentBranch: "main")
}
