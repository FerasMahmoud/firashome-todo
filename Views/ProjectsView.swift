import SwiftUI
import SwiftData

/// Projects list — the detail view shown when the sidebar's "Projects" row is selected.
/// Mirrors the Todoist projects screen: colored dot + name + open-task count,
/// with a toolbar "+" to add a new project (name + color).
struct ProjectsView: View {
    @Environment(\.modelContext) private var context

    /// All projects in manual order — drives the list.
    @Query(sort: \Project.order) private var projects: [Project]

    /// Open (uncompleted) tasks — used to compute the per-project count badge.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    @State private var showingAdd: Bool = false
    @State private var newProjectName: String = ""
    @State private var newProjectColor: String = "1F87E6"

    /// Preset color palette for new projects — the same hues Todoist offers.
    private static let palette: [String] = [
        "E53935", // red
        "F09A0E", // orange
        "F5BE0E", // yellow
        "0DA34A", // green
        "1F87E6", // blue
        "6F4FE0", // purple
        "B83FB8", // pink
        "8E8E93"  // gray
    ]

    var body: some View {
        Group {
            if projects.isEmpty {
                emptyState
            } else {
                projectList
            }
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newProjectName = ""
                    newProjectColor = Self.palette.first ?? "1F87E6"
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TK.accent)
                }
                .accessibilityLabel("Add project")
                .accessibilityIdentifier("projects-add")
            }
        }
        .sheet(isPresented: $showingAdd) {
            addProjectSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - List

    private var projectList: some View {
        List {
            ForEach(projects) { project in
                NavigationLink {
                    ProjectDetailView(projectID: project.id)
                } label: {
                    projectRow(for: project)
                }
                .accessibilityIdentifier("projects-row-\(project.id.uuidString)")
                .accessibilityLabel(project.name)
                .accessibilityValue("\(taskCount(project)) open tasks")
            }
            .onDelete(perform: deleteProjects)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func projectRow(for project: Project) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(project.color)
                .frame(width: 14, height: 14)
            Text(project.name)
                .font(TK.body)
                .foregroundStyle(TK.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            let n = taskCount(project)
            if n > 0 {
                Text("\(n)")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
            Text("No projects yet")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Tap + to create your first project")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityIdentifier("projects-empty")
    }

    // MARK: - Add sheet

    private var addProjectSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Project name", text: $newProjectName)
                    .textFieldStyle(.plain)
                    .font(TK.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(TK.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
                    .submitLabel(.done)
                    .onSubmit { commitNewProject() }
                    .accessibilityIdentifier("projects-add-name")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                    HStack(spacing: 14) {
                        ForEach(Self.palette, id: \.self) { hex in
                            Button {
                                newProjectColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                newProjectColor == hex ? TK.ink : TK.hairline,
                                                lineWidth: newProjectColor == hex ? 2 : 0.5
                                            )
                                    }
                                    .overlay {
                                        if newProjectColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                            .accessibilityIdentifier("projects-add-color-\(hex)")
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    commitNewProject()
                } label: {
                    Text("Add project")
                        .font(TK.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canAdd ? TK.accent : TK.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
                }
                .disabled(!canAdd)
                .accessibilityIdentifier("projects-add-confirm")
            }
            .padding(20)
            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingAdd = false
                    }
                    .foregroundStyle(TK.secondary)
                    .accessibilityIdentifier("projects-add-cancel")
                }
            }
        }
    }

    // MARK: - Actions

    private var canAdd: Bool {
        !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitNewProject() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (projects.map(\.order).max() ?? -1) + 1
        let project = Project(
            name: trimmed,
            colorHex: newProjectColor,
            order: nextOrder,
            isFavorite: false
        )
        context.insert(project)
        try? context.save()
        showingAdd = false
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            context.delete(projects[index])
        }
        try? context.save()
    }

    private func taskCount(_ project: Project) -> Int {
        openTasks.reduce(into: 0) { acc, task in
            if task.project?.id == project.id { acc += 1 }
        }
    }
}




