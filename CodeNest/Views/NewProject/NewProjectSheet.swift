//
//  NewProjectSheet.swift
//  CodeNest
//

import SwiftUI
import AppKit

// MARK: - Wizard step

private enum WizardStep: Int, CaseIterable {
    case framework    = 0
    case settings     = 1
    case dependencies = 2   // Spring Boot only
}

// MARK: - Metadata load state

private enum MetadataState {
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
    @State private var step: WizardStep = .framework
    @State private var metadataState: MetadataState = .loading
    @State private var depSearchText: String = ""
    @State private var isCreating: Bool = false
    @State private var creationError: String? = nil

    private var isSpringBoot: Bool { options.framework == .springBoot }

    // Steps shown for the current framework
    private var steps: [WizardStep] {
        isSpringBoot ? [.framework, .settings, .dependencies] : [.framework, .settings]
    }

    private var isLastStep: Bool { step == steps.last }

    private var canAdvance: Bool {
        switch step {
        case .framework:    return true
        case .settings:
            let nameOK = !options.name.trimmingCharacters(in: .whitespaces).isEmpty
            let locOK  = locationURL != nil
            return nameOK && locOK
        case .dependencies: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepProgress
            Divider()

            Group {
                switch step {
                case .framework:    frameworkStep
                case .settings:     settingsStep
                case .dependencies: dependenciesStep
                }
            }
            .frame(minHeight: 340)

            Divider()
            footer
        }
        .frame(width: 580)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            locationURL = workspace.rootNode?.url ?? FileManager.default.homeDirectoryForCurrentUser
            loadMetadata()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("New Project")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Step progress indicator

    private var stepProgress: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, s in
                HStack(spacing: 6) {
                    // Dot
                    ZStack {
                        Circle()
                            .fill(dotFill(for: s))
                            .frame(width: 22, height: 22)
                        if s.rawValue < step.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(s == step ? .white : .secondary)
                        }
                    }
                    Text(stepLabel(for: s))
                        .font(.system(size: 12, weight: s == step ? .semibold : .regular))
                        .foregroundStyle(s == step ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                        .frame(maxWidth: 32)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func dotFill(for s: WizardStep) -> Color {
        if s.rawValue < step.rawValue { return .green }
        if s == step { return .accentColor }
        return Color(nsColor: .separatorColor)
    }

    private func stepLabel(for s: WizardStep) -> String {
        switch s {
        case .framework:    return "Framework"
        case .settings:     return "Settings"
        case .dependencies: return "Dependencies"
        }
    }

    // MARK: - Step 1: Framework

    private var frameworkStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose a framework to scaffold your project.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                HStack(spacing: 12) {
                    ForEach(Framework.allCases) { fw in
                        FrameworkCard(framework: fw, isSelected: options.framework == fw) {
                            options.framework = fw
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - Step 2: Settings

    private var settingsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Project name
                field("Project Name") {
                    TextField("my-project", text: $options.name)
                        .textFieldStyle(.roundedBorder)
                }

                if isSpringBoot {
                    field("Group ID") {
                        TextField("com.example", text: $options.groupId)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("Build Tool") {
                        Picker("", selection: $options.buildTool) {
                            ForEach(BuildTool.allCases) { t in Text(t.rawValue).tag(t) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    versionPickersSection
                }

                if options.framework == .react {
                    Toggle(isOn: $options.useTypeScript) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use TypeScript")
                                .font(.subheadline)
                            Text("Generates .tsx files and tsconfig.json")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                Divider()

                // Location
                field("Location") {
                    HStack {
                        Text(locationURL?.path ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Change...") { pickLocation() }
                            .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1))

                    if let url = locationURL {
                        Text("Will create: \(url.appendingPathComponent(options.name.isEmpty ? "…" : options.name).path)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var versionPickersSection: some View {
        switch metadataState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Fetching versions from start.spring.io…")
                    .font(.caption).foregroundStyle(.secondary)
            }

        case .loaded(let meta):
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    field("Spring Boot") {
                        Picker("", selection: $options.springBootVersion) {
                            ForEach(meta.bootVersions) { v in Text(v.name).tag(v.id) }
                        }
                        .labelsHidden().frame(maxWidth: .infinity)
                    }
                    field("Java") {
                        Picker("", selection: $options.javaVersion) {
                            ForEach(meta.javaVersions) { v in Text(v.name).tag(v.id) }
                        }
                        .labelsHidden().frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.caption)
                    Text("Versions synced from start.spring.io").font(.caption).foregroundStyle(.secondary)
                }
            }

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash").foregroundStyle(.orange)
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") { loadMetadata(force: true) }.controlSize(.mini)
                }
                // Fallback pickers
                HStack(spacing: 16) {
                    field("Spring Boot") {
                        Picker("", selection: $options.springBootVersion) {
                            Text("3.4.4").tag("3.4.4")
                            Text("3.3.10").tag("3.3.10")
                            Text("3.2.12").tag("3.2.12")
                        }
                        .labelsHidden().frame(maxWidth: .infinity)
                    }
                    field("Java") {
                        Picker("", selection: $options.javaVersion) {
                            Text("21").tag("21"); Text("17").tag("17"); Text("11").tag("11")
                        }
                        .labelsHidden().frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Dependencies

    private var dependenciesStep: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search dependencies…", text: $depSearchText)
                    .textFieldStyle(.plain)
                if !depSearchText.isEmpty {
                    Button { depSearchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Selected chips
            if !options.selectedDependencies.isEmpty {
                selectedChips
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                Divider()
            }

            // Dependency list / loading / error
            switch metadataState {
            case .loading:
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading dependencies…").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            case .failed:
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Could not load dependencies. Check your connection and retry.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { loadMetadata(force: true) }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()

            case .loaded(let meta):
                dependencyList(meta: meta)
            }
        }
    }

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options.selectedDependencies, id: \.self) { depID in
                    HStack(spacing: 4) {
                        Text(depID)
                            .font(.system(size: 11))
                        Button {
                            options.selectedDependencies.removeAll { $0 == depID }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func dependencyList(meta: InitializrMetadata) -> some View {
        let filtered = filteredGroups(meta.dependencyGroups)
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
                Text("No dependencies match \"\(depSearchText)\"")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List {
                ForEach(filtered) { group in
                    Section(group.name) {
                        ForEach(group.dependencies) { dep in
                            DependencyRow(
                                dep: dep,
                                isSelected: options.selectedDependencies.contains(dep.id)
                            ) {
                                toggleDep(dep.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func filteredGroups(_ groups: [InitializrDependencyGroup]) -> [InitializrDependencyGroup] {
        guard !depSearchText.isEmpty else { return groups }
        let q = depSearchText.lowercased()
        return groups.compactMap { group in
            let deps = group.dependencies.filter {
                $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q) || $0.id.lowercased().contains(q)
            }
            return deps.isEmpty ? nil : InitializrDependencyGroup(id: group.id, name: group.name, dependencies: deps)
        }
    }

    private func toggleDep(_ id: String) {
        if options.selectedDependencies.contains(id) {
            options.selectedDependencies.removeAll { $0 == id }
        } else {
            options.selectedDependencies.append(id)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = creationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                // Back button (not on first step)
                if step != .framework {
                    Button("Back") { goBack() }
                        .disabled(isCreating)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isCreating)

                if isCreating {
                    ProgressView().controlSize(.small).padding(.horizontal, 4)
                }

                if isLastStep {
                    Button(isCreating ? "Creating…" : "Create Project") {
                        Task { await createProject() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance || isCreating)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") { goNext() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canAdvance)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Navigation

    private func goNext() {
        guard let idx = steps.firstIndex(of: step), idx + 1 < steps.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = steps[idx + 1] }
    }

    private func goBack() {
        guard let idx = steps.firstIndex(of: step), idx > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = steps[idx - 1] }
        creationError = nil
    }

    // MARK: - Helpers

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
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
    }

    private func loadMetadata(force: Bool = false) {
        if case .loaded = metadataState, !force { return }
        metadataState = .loading
        Task {
            do {
                let meta = try await SpringInitializrService.fetchMetadata()
                metadataState = .loaded(meta)
                if let d = meta.bootVersions.first(where: { $0.isDefault }) ?? meta.bootVersions.first {
                    options.springBootVersion = d.id
                }
                if let d = meta.javaVersions.first(where: { $0.isDefault }) ?? meta.javaVersions.first {
                    options.javaVersion = d.id
                }
            } catch {
                metadataState = .failed(error.localizedDescription)
            }
        }
    }

    private func createProject() async {
        guard let parent = locationURL else { return }
        var trimmed = options
        trimmed.name = options.name.trimmingCharacters(in: .whitespaces)

        isCreating = true
        creationError = nil

        if trimmed.framework == .springBoot {
            do {
                try await SpringInitializrService.generateProject(options: trimmed, into: parent)
                workspace.openProjectFromExtractedZip(parentURL: parent, projectName: trimmed.name)
                dismiss()
            } catch {
                creationError = error.localizedDescription
                isCreating = false
            }
        } else {
            workspace.createProject(options: trimmed, at: parent)
            dismiss()
        }
    }
}

// MARK: - Dependency row

private struct DependencyRow: View {
    let dep: InitializrDependency
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture { onToggle() }

            VStack(alignment: .leading, spacing: 2) {
                Text(dep.name)
                    .font(.system(size: 13, weight: .medium))
                if !dep.description.isEmpty {
                    Text(dep.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Framework brand colors

private extension Framework {
    var brandColor: Color {
        switch self {
        case .springBoot: return Color(red: 0.427, green: 0.702, blue: 0.247)
        case .angular:    return Color(red: 0.867, green: 0.000, blue: 0.192)
        case .react:      return Color(red: 0.380, green: 0.855, blue: 0.984)
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
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(framework.brandColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: framework.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(framework.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(isSelected ? framework.brandColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? framework.brandColor : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}
