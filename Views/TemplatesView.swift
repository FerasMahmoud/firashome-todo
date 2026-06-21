import SwiftUI
import SwiftData

/// Templates — saved task blueprints (e.g. "Weekly review", "Workout").
/// Tap a row to instantly spawn a new TodoTask from the template (title +
/// note + priority pre-filled, project nil, due nil). A "+" toolbar opens
/// a sheet that captures a new template's name, title, and priority.
///
/// Light theme, `TK.*` tokens, SF Symbols only. Targets iOS 17 (SwiftData).
struct TemplatesView: View {
    @Environment(\.modelContext) private var context

    /// Every persisted template, alphabetical by display name. Drives the
    /// list and the empty state.
    @Query(sort: \TaskTemplate.name) private var templates: [TaskTemplate]

    @State private var showingNew: Bool = false
    @State private var newName: String = ""
    @State private var newTitle: String = ""
    @State private var newPriority: Int = 4

    var body: some View {
        Group {
            if templates.isEmpty {
                emptyState
            } else {
                templateList
            }
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = ""
                    newTitle = ""
                    newPriority = 4
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TK.accent)
                }
                .accessibilityLabel("New template")
                .accessibilityIdentifier("templates-new")
            }
        }
        .sheet(isPresented: $showingNew) {
            newTemplateSheet
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No templates yet")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Templates are reusable task blueprints. Tap the + above to create your first one.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("templates-empty")
    }

    // MARK: - List

    private var templateList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(templates) { template in
                    templateRow(template)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func templateRow(_ template: TaskTemplate) -> some View {
        Button {
            spawnFromTemplate(template)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(TK.accent)
                    .frame(width: 32, height: 32)
                    .background(TK.accent.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(TK.headline)
                        .foregroundStyle(TK.ink)
                        .lineLimit(1)
                    Text(template.title)
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: template.priority < 4 ? "flag.fill" : "flag")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TK.priority(template.priority))
                    .accessibilityLabel(priorityLabel(template.priority))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                    .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Create task from \(template.name)")
        .accessibilityIdentifier("template-row-\(template.name)")
    }

    // MARK: - New template sheet

    private var newTemplateSheet: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name (e.g. Weekly review)", text: $newName)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("new-template-name")
                    TextField("Task title", text: $newTitle)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("new-template-title")
                }
                Section("Priority") {
                    Picker("Priority", selection: $newPriority) {
                        ForEach(1...4, id: \.self) { p in
                            HStack(spacing: 6) {
                                Image(systemName: p < 4 ? "flag.fill" : "flag")
                                    .foregroundStyle(TK.priority(p))
                                Text(priorityLabel(p))
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(TK.priority(newPriority))
                    .accessibilityIdentifier("new-template-priority")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TK.canvas)
            .navigationTitle("New template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingNew = false }
                        .accessibilityIdentifier("new-template-cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { commitNewTemplate() }
                        .disabled(!isNewTemplateValid)
                        .accessibilityIdentifier("new-template-save")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Save button is enabled only when both name and title have content.
    private var isNewTemplateValid: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
            && !newTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func commitNewTemplate() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !title.isEmpty else { return }
        let template = TaskTemplate(name: name, title: title, priority: newPriority)
        context.insert(template)
        try? context.save()
        showingNew = false
    }

    // MARK: - Spawn

    /// One-tap task creation from a template. Creates the task via
    /// `Repository.add` (which inserts, persists, and schedules the
    /// notification) with the template's title, nil project, nil due, and
    /// the template's priority. The template's note is then attached to
    /// the freshly-spawned task in a follow-up save.
    private func spawnFromTemplate(_ template: TaskTemplate) {
        let task = Repository.add(
            template.title,
            project: nil,
            due: nil,
            priority: template.priority,
            in: context
        )
        if !template.note.isEmpty {
            task.note = template.note
            try? context.save()
        }
    }

    // MARK: - Helpers

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Priority 1"
        case 2: return "Priority 2"
        case 3: return "Priority 3"
        default: return "Priority 4"
        }
    }
}