//
//  NewProjectSheet.swift
//  CodeNest
//

import SwiftUI
import AppKit

// MARK: - Metadata load state

private enum MetadataState {
    case idle
    case loading
    case loaded(InitializrMetadata)
    case failed(String)
}

// MARK: - Sheet

struct NewProjectSheet: View {
    @Environment(WorkspaceState.self) var workspace
    @Environment(\.dismiss) private var dismiss

    @State private var options = ProjectOptions()
    @State private var locationURL: URL? = nil
    @State private var locationDisplayPath: String = ""

    // Spring Initializr metadata
    @State private var metadataState: MetadataState = .idle

    // Project creation state
    @State private var isCreating: Bool = false
    @State private var creationError: String? = nil

    private var isValid: Bool {
        !options.name.trimmingCharacters(in: .whitespaces).isEmpty && locationURL != nil && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("New Project")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Framework picker
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Framework", systemImage: "square.stack.3d.up")
                            .font(.headline)
                        HStack(spacing: 12) {
                            ForEach(Framework.allCases) { fw in
                                FrameworkCard(
                                    framework: fw,
                                    isSelected: options.framework == fw
                                ) {
                                    options.framework = fw
                                    if fw == .springBoot { loadMetadataIfNeeded() }
                                }
                            }
                        }
                    }

                    Divider()

                    // Project name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project Name")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("my-project", text: $options.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Spring Boot specific options
                    if options.framework == .springBoot {
                        springBootOptions
                    }

                    // React TypeScript toggle
                    if options.framework == .react {
                        Toggle(isOn: $options.useTypeScript) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use TypeScript")
                                    .font(.subheadline)
                                Text("Generates .tsx files and tsconfig.json")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    Divider()

                    // Location picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(locationDisplayPath.isEmpty ? "Choose a directory..." : locationDisplayPath)
                                .foregroundStyle(locationDisplayPath.isEmpty ? .tertiary : .primary)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Choose...") {
                                pickLocation()
                            }
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                        if let url = locationURL {
                            Text("Project will be created at: \(url.appendingPathComponent(options.name).path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    // Creation error
                    if let error = creationError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(24)
            }

            Divider()

            // Action buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isCreating)

                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 4)
                }

                Button(isCreating ? "Creating..." : "Create Project") {
                    Task { await createProject() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if options.framework == .springBoot { loadMetadataIfNeeded() }
        }
    }

    // MARK: - Spring Boot Options

    @ViewBuilder
    private var springBootOptions: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Group ID
            VStack(alignment: .leading, spacing: 6) {
                Text("Group ID")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("com.example", text: $options.groupId)
                    .textFieldStyle(.roundedBorder)
            }

            // Build Tool
            VStack(alignment: .leading, spacing: 6) {
                Text("Build Tool")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $options.buildTool) {
                    ForEach(BuildTool.allCases) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Version pickers — loaded from Spring Initializr
            switch metadataState {
            case .idle:
                EmptyView()

            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading versions from start.spring.io...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .loaded(let meta):
                versionPickers(meta: meta)

            case .failed(let msg):
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.orange)
                        Text("Could not load versions: \(msg)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { loadMetadataIfNeeded(force: true) }
                            .controlSize(.mini)
                    }
                    fallbackVersionPickers
                }
            }
        }
    }

    @ViewBuilder
    private func versionPickers(meta: InitializrMetadata) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Spring Boot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $options.springBootVersion) {
                    ForEach(meta.bootVersions) { v in
                        Text(v.name).tag(v.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Java Version")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $options.javaVersion) {
                    ForEach(meta.javaVersions) { v in
                        Text(v.name).tag(v.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }

        // Spring Initializr badge
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text("Versions synced from start.spring.io")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var fallbackVersionPickers: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Spring Boot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $options.springBootVersion) {
                    Text("3.4.4").tag("3.4.4")
                    Text("3.3.10").tag("3.3.10")
                    Text("3.2.12").tag("3.2.12")
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Java Version")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("", selection: $options.javaVersion) {
                    Text("21").tag("21")
                    Text("17").tag("17")
                    Text("11").tag("11")
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func loadMetadataIfNeeded(force: Bool = false) {
        if case .loaded = metadataState, !force { return }
        metadataState = .loading
        Task {
            do {
                let meta = try await SpringInitializrService.fetchMetadata()
                metadataState = .loaded(meta)
                // Select defaults from metadata
                if let defaultBoot = meta.bootVersions.first(where: { $0.isDefault }) {
                    options.springBootVersion = defaultBoot.id
                } else if let first = meta.bootVersions.first {
                    options.springBootVersion = first.id
                }
                if let defaultJava = meta.javaVersions.first(where: { $0.isDefault }) {
                    options.javaVersion = defaultJava.id
                } else if let first = meta.javaVersions.first {
                    options.javaVersion = first.id
                }
            } catch {
                metadataState = .failed(error.localizedDescription)
            }
        }
    }

    private func pickLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select where the project folder will be created"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        locationURL = url
        locationDisplayPath = url.path
    }

    private func createProject() async {
        guard let parent = locationURL else { return }
        var trimmed = options
        trimmed.name = options.name.trimmingCharacters(in: .whitespaces)

        isCreating = true
        creationError = nil

        if trimmed.framework == .springBoot {
            // Use Spring Initializr API
            do {
                try await SpringInitializrService.generateProject(options: trimmed, into: parent)
                workspace.openProjectFromExtractedZip(parentURL: parent, projectName: trimmed.name)
                dismiss()
            } catch {
                creationError = error.localizedDescription
                isCreating = false
            }
        } else {
            // Local scaffold for Angular / React
            workspace.createProject(options: trimmed, at: parent)
            dismiss()
        }
    }
}

// MARK: - Framework Card

private struct FrameworkCard: View {
    let framework: Framework
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: framework.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : .secondary)
                Text(framework.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
