//
//  BreadcrumbView.swift
//  CodeNest
//
//  Created by Santosh Hemashekar on 20/04/26.
//

import SwiftUI

struct BreadcrumbView: View {
    @Environment(WorkspaceState.self) var workspace

    private var segments: [String] {
        guard let fileURL = workspace.activeTab?.fileNode.url,
              let rootURL = workspace.rootNode?.url else { return [] }
        let rootPath = rootURL.path
        let filePath = fileURL.path
        guard filePath.hasPrefix(rootPath) else { return [fileURL.lastPathComponent] }
        let relative = String(filePath.dropFirst(rootPath.count + 1))
        return relative.components(separatedBy: "/")
    }

    var body: some View {
        if !segments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text(segment)
                            .font(.system(size: 11))
                            .foregroundStyle(index == segments.count - 1 ? .primary : .secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}
