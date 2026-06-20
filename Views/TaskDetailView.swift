import SwiftUI
import SwiftData

/// A Todoist-style task detail / editor view. Presented as the destination of
/// any task row tap. Edits title, note, project, due date, and priority
/// inline (autosave on every change), with a destructive Delete action at
/// the bottom. A toolbar toggle marks the task complete / incomplete without
/// leaving the screen.
///
/// Light theme, `TK.*` tokens, SF Symbols only. Targets iOS 17 (SwiftData).
/// When run on iOS 26+, the toolbar toggle wears a Liquid Glass background.
struct TaskDetailView: View {
    let task: TodoTask

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.order) private var projects: [Project]

    /// Mirrors `task.dueDate != nil` and feeds the optional due-date card.
    /// Stored as `@State` (not derived) so the toggle can set/clear the
    /// date in a single coordinated write.
    @State private var hasDueDate: Bool
    @State private var showDeleteConfirm: Bool = false
    @State private var newSubtask: String = ""

    init(task: TodoTask) {
        self.task = task
        self._hasDueDate = State(initialValue: task.dueDate != nil)
    }

    var body: some View {
        @Bindable var task = task

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                titleCard(task: task)
                noteCard(task: task)
                subtasksCard(task: task)
                projectCard(task: task)
                dueCard(task: task)
                priorityCard(task: task)
                metaFooter
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(TK.canvas.ignoresSafeArea())
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toggleCompletionButton
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Repository.delete(task, in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onChange(of: task.title) { _, _ in persist() }
        .onChange(of: task.note) { _, _ in persist() }
        .onChange(of: task.priority) { _, _ in persist() }
        .onChange(of: task.dueDate) { _, _ in persist() }
        .onChange(of: task.project) { _, _ in persist() }
        .onChange(of: hasDueDate) { _, newValue in
            if newValue {
                if task.dueDate == nil {
                    task.dueDate = Calendar.current.startOfDay(for: .now)
                }
            } else {
                task.dueDate = nil
            }
            persist()
        }
    }

    // MARK: - Toolbar toggle

    @ViewBuilder
    private var toggleCompletionButton: some View {
        let isDone = task.isCompleted
        let button = Button {
            Repository.toggle(task, in: context)
        } label: {
            Image(systemName: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(isDone ? TK.accent : TK.ink)
        }
        .accessibilityIdentifier(isDone ? "task-detail-reopen" : "task-detail-complete")
        .accessibilityLabel(isDone ? "Mark incomplete" : "Mark complete")

        // Liquid Glass (iOS 26) not available in this SDK — plain button.
        button
    }

    // MARK: - Title

    private func titleCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Task")
            TextField("Task name", text: $task.title, axis: .vertical)
                .font(TK.title)
                .foregroundStyle(TK.ink)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("task-detail-title")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Note

    private func noteCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Note")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $task.note)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .accessibilityIdentifier("task-detail-note")
                if task.note.isEmpty {
                    Text("Description")
                        .font(TK.body)
                        .foregroundStyle(TK.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Subtasks (checklist)

    private func subtasksCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                sectionLabel("Subtasks")
                Spacer()
                let total = task.subtasks.count
                if total > 0 {
                    let done = task.subtasks.filter(\.isDone).count
                    Text("\(done)/\(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TK.secondary)
                }
            }

            ForEach(task.subtasks.sorted(by: { $0.order < $1.order })) { st in
                HStack(spacing: 10) {
                    Button {
                        st.isDone.toggle()
                        try? context.save()
                    } label: {
                        Image(systemName: st.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(st.isDone ? TK.accent : TK.secondary)
                    }
                    .buttonStyle(.plain)
                    Text(st.title)
                        .font(TK.body)
                        .foregroundStyle(st.isDone ? TK.secondary : TK.ink)
                        .strikethrough(st.isDone, color: TK.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(TK.secondary)
                TextField("Add a step", text: $newSubtask)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = newSubtask.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let order = (task.subtasks.map(\.order).max() ?? -1) + 1
                        let st = Subtask(title: trimmed, order: order)
                        st.task = task
                        context.insert(st)
                        try? context.save()
                        newSubtask = ""
                    }
            }
            .padding(.vertical, 6)
        }
        .padding(14)
        .liquidGlass(cornerRadius: TK.rCard)
    }

    // MARK: - Project

    private func projectCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Project")
            Menu {
                Button {
                    task.project = nil
                    persist()
                } label: {
                    HStack(spacing: 6) { Image(systemName: "tray"); Text("Inbox") }
                }
                if !projects.isEmpty {
                    Divider()
                    ForEach(projects) { project in
                        Button {
                            task.project = project
                            persist()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 10, height: 10)
                                Text(project.name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if let project = task.project {
                        Circle()
                            .fill(project.color)
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .font(TK.body)
                            .foregroundStyle(TK.ink)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "tray")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TK.secondary)
                        Text("Inbox")
                            .font(TK.body)
                            .foregroundStyle(TK.ink)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("task-detail-project")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Due date

    private func dueCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Due date")
            HStack {
                Toggle(isOn: $hasDueDate) {
                    HStack(spacing: 8) {
                        Image(systemName: hasDueDate ? "calendar.badge.clock" : "calendar.badge.minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hasDueDate ? TK.accent : TK.secondary)
                        Text(hasDueDate ? "Set" : "No date")
                            .font(TK.body)
                            .foregroundStyle(hasDueDate ? TK.ink : TK.secondary)
                    }
                }
                .tint(TK.accent)
                .accessibilityIdentifier("task-detail-due-toggle")
            }

            if hasDueDate {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { task.dueDate ?? .now },
                        set: { task.dueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(TK.accent)
                .accessibilityIdentifier("task-detail-due-date")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Priority

    private func priorityCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Priority")
            Picker("Priority", selection: $task.priority) {
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
            .tint(TK.priority(task.priority))
            .accessibilityIdentifier("task-detail-priority")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Meta footer

    private var metaFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("Created ")
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
            + Text(task.createdAt, format: .dateTime.day().month().year())
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("task-detail-created")
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("Delete task")
                    .font(TK.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
                    .fill(TK.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-detail-delete")
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(TK.sectionHeader)
            .foregroundStyle(TK.secondary)
            .textCase(nil)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Priority 1"
        case 2: return "Priority 2"
        case 3: return "Priority 3"
        default: return "Priority 4"
        }
    }

    private func persist() {
        try? context.save()
    }
}

// MARK: - Preview


