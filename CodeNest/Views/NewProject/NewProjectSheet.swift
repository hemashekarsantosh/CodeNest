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

// MARK: - Project Creation Step

private enum NewProjectStep: Int, Equatable {
    case framework = 0
    case details = 1
    case bootOptions = 2
    case review = 3
}

// MARK: - Sheet

struct NewProjectSheet: View {
    @Environment(WorkspaceState.self) var workspace
    @Environment(\.dismiss) private var dismiss

    @State private var options = ProjectOptions()
    @State private var locationURL: URL? = nil
    @State private var currentStep: NewProjectStep = .framework

    private var locationDisplayPath: String {
        locationURL?.path ?? ""
    }

    // Spring Initializr metadata
    @State private var metadataState: MetadataState = .idle

    // Dependency search
    @State private var dependencySearchText: String = ""

    // Project creation state
    @State private var isCreating: Bool = false
    @State private var creationError: String? = nil

    private var isValid: Bool {
        !options.name.trimmingCharacters(in: .whitespaces).isEmpty && locationURL != nil && !isCreating
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case .framework:
            return true
        case .details:
            return !options.name.trimmingCharacters(in: .whitespaces).isEmpty && locationURL != nil
        case .bootOptions:
            return true
        case .review:
            return true
        }
    }

    private var canProceedToNext: Bool {
        isCurrentStepValid && !isCreating
    }

    private func filteredCategories(from categories: [DependencyCategory]) -> [DependencyCategory] {
        let query = dependencySearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return categories }
        return categories.compactMap { category in
            let matchingDeps = category.dependencies.filter { dep in
                dep.name.lowercased().contains(query)
                || dep.id.lowercased().contains(query)
                || dep.description.lowercased().contains(query)
            }
            guard !matchingDeps.isEmpty else { return nil }
            return DependencyCategory(
                id: category.id,
                name: category.name,
                dependencies: matchingDeps
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title + Step indicator
            VStack(alignment: .leading, spacing: 8) {
                Text("New Project")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Step \(currentStep.rawValue + 1) of 4")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Current step content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch currentStep {
                    case .framework:
                        stepFrameworkContent()
                    case .details:
                        stepDetailsContent()
                    case .bootOptions:
                        stepBootOptionsContent()
                    case .review:
                        stepReviewContent()
                    }
                }
                .padding(24)
            }
            .frame(minHeight: 300)

            Divider()

            // Navigation buttons
            HStack(spacing: 12) {
                if currentStep != .framework {
                    Button("Previous") {
                        goToPreviousStep()
                    }
                }

                Spacer()

                if currentStep == .review {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    if isCreating {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button(isCreating ? "Creating..." : "Create Project") {
                        Task { await createProject() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating)
                } else {
                    Button("Next") {
                        goToNextStep()
                    }
                    .disabled(!canProceedToNext)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            locationURL = workspace.rootNode?.url ?? FileManager.default.homeDirectoryForCurrentUser
        }
    }

    // MARK: - Step Navigation

    private func goToNextStep() {
        // Load metadata when entering boot options for Spring Boot
        if currentStep == .details && options.framework == .springBoot {
            loadMetadataIfNeeded()
        }
        if currentStep.rawValue < NewProjectStep.review.rawValue {
            currentStep = NewProjectStep(rawValue: currentStep.rawValue + 1) ?? .review
        }
    }

    private func goToPreviousStep() {
        if currentStep.rawValue > NewProjectStep.framework.rawValue {
            currentStep = NewProjectStep(rawValue: currentStep.rawValue - 1) ?? .framework
        }
    }

    // MARK: - Step Content Views

    @ViewBuilder
    private func stepFrameworkContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Select a Framework", systemImage: "square.stack.3d.up")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(Framework.allCases) { fw in
                    FrameworkCard(
                        framework: fw,
                        isSelected: options.framework == fw
                    ) {
                        options.framework = fw
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepDetailsContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project name
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("my-project", text: $options.name)
                    .textFieldStyle(.roundedBorder)
            }

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
        }
    }

    @ViewBuilder
    private func stepBootOptionsContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if options.framework == .springBoot {
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
                    dependencySection(meta: meta)

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
            } else {
                Text("No additional options for \(options.framework.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func stepReviewContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review your project settings")
                .font(.subheadline)
                .fontWeight(.medium)

            Divider()

            ReviewRow(label: "Framework", value: options.framework.rawValue)
            ReviewRow(label: "Project Name", value: options.name)
            ReviewRow(label: "Location", value: locationURL?.lastPathComponent ?? "Not selected")

            if options.framework == .springBoot {
                Divider()
                ReviewRow(label: "Build Tool", value: options.buildTool.rawValue)
                ReviewRow(label: "Spring Boot", value: options.springBootVersion)
                ReviewRow(label: "Java Version", value: options.javaVersion)

                if !options.selectedDependencies.isEmpty {
                    Divider()
                    if case .loaded(let meta) = metadataState {
                        let allDeps: [String: String] = Dictionary(
                            meta.dependencyCategories
                                .flatMap { $0.dependencies }
                                .map { ($0.id, $0.name) },
                            uniquingKeysWith: { first, _ in first }
                        )
                        let depNames = options.selectedDependencies.sorted().compactMap { allDeps[$0] }.joined(separator: ", ")
                        ReviewRow(label: "Dependencies", value: depNames)
                    }
                }
            }

            Spacer()

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
                dependencySection(meta: meta)

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
    private func dependencySection(meta: InitializrMetadata) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            // Section header
            Label("Dependencies", systemImage: "shippingbox")
                .font(.headline)

            // Selected dependency chips (shown only when something is selected)
            if !options.selectedDependencies.isEmpty {
                selectedDependencyChips(meta: meta)
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search dependencies...", text: $dependencySearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !dependencySearchText.isEmpty {
                    Button {
                        dependencySearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )

            // Dependency category list — fixed height inner scroll
            let filtered = filteredCategories(from: meta.dependencyCategories)

            if filtered.isEmpty {
                Text("No dependencies match \"\(dependencySearchText)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(filtered) { category in
                            DependencyCategorySection(
                                category: category,
                                selectedDependencies: $options.selectedDependencies
                            )
                        }
                    }
                }
                .frame(height: 260)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private func selectedDependencyChips(meta: InitializrMetadata) -> some View {
        // Build a lookup of id -> name for display
        let allDeps: [String: String] = Dictionary(
            meta.dependencyCategories
                .flatMap { $0.dependencies }
                .map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        FlowLayout(spacing: 6) {
            ForEach(options.selectedDependencies.sorted(), id: \.self) { depId in
                HStack(spacing: 4) {
                    Text(allDeps[depId] ?? depId)
                        .font(.system(size: 11, weight: .medium))
                    Button {
                        options.selectedDependencies.remove(depId)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }
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
        if force {
            options.selectedDependencies = []
        }
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

// MARK: - Framework brand colors

private extension Framework {
    var brandColor: Color {
        switch self {
        case .springBoot: return Color(red: 0.427, green: 0.702, blue: 0.247) // Spring green
        case .angular:    return Color(red: 0.867, green: 0.000, blue: 0.192) // Angular red
        case .react:      return Color(red: 0.380, green: 0.855, blue: 0.984) // React cyan
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
                // Icon badge
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
            .background(
                isSelected
                    ? framework.brandColor.opacity(0.08)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? framework.brandColor : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review Row

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dependency Views

private struct DependencyCategorySection: View {
    let category: DependencyCategory
    @Binding var selectedDependencies: Set<String>

    var body: some View {
        Section {
            ForEach(category.dependencies) { dep in
                DependencyRow(dep: dep, selectedDependencies: $selectedDependencies)
            }
        } header: {
            Text(category.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct DependencyRow: View {
    let dep: DependencyOption
    @Binding var selectedDependencies: Set<String>

    private var isSelected: Bool { selectedDependencies.contains(dep.id) }

    var body: some View {
        Button {
            if isSelected {
                selectedDependencies.remove(dep.id)
            } else {
                selectedDependencies.insert(dep.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text(dep.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    if !dep.description.isEmpty {
                        Text(dep.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += rowHeight + spacing
                currentRowWidth = 0
                rowHeight = 0
            }
            currentRowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
