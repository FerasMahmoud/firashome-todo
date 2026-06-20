import SwiftUI
import SwiftData

/// Quick-add bottom sheet for creating a TodoTask with minimal friction.
/// Natural-language title field plus compact pickers for project / date / priority.
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.order) private var projects: [Project]

    @State private var title: String = ""
    @State private var selectedProject: Project?
    @State private var dueDate: Date?
    @State private var priority: Int = 4
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                handle

                titleField

                controls
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 16)
            }
            .background { GlassPlanetBg() }
            .toolbar {
                // Todoist quick-add chrome: Cancel (left), Add task (right, red).
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TK.secondary)
                        .accessibilityIdentifier("quick-add-cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: addTask) {
                        Text("Add task")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canAdd ? TK.accent : TK.secondary)
                    }
                    .disabled(!canAdd)
                    .accessibilityIdentifier("quick-add-add")
                }
            }
        }
        .background(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            // Screenshot mode: pre-fill a realistic entry so the sheet looks active
            // (red Add button, filled chips) instead of empty/gray.
            if ProcessInfo.processInfo.arguments.contains("--screen=quickadd") {
                title = "Review drone brief p1"
                priority = 1
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                selectedProject = projects.first(where: { $0.name == "FITech" }) ?? projects.first
            }
            // Skip auto-focus in screenshot mode so the keyboard doesn't cover the sheet.
            if !ProcessInfo.processInfo.arguments.contains("--no-focus") {
                titleFocused = true
            }
        }
    }

    // MARK: - Sections

    private var handle: some View {
        Capsule()
            .fill(TK.hairline)
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .accessibilityHidden(true)
    }

    private var titleField: some View {
        TextField(
            "e.g., Review drone brief @urgent #FITech",
            text: $title,
            axis: .vertical
        )
        .font(TK.body)
        .foregroundStyle(TK.ink)
        .focused($titleFocused)
        .lineLimit(1...4)
        .tint(TK.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            TK.card,
            in: RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
                .stroke(TK.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .accessibilityIdentifier("quick-add-title")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            projectMenu
            dateMenu
            priorityMenu
            Spacer(minLength: 0)
        }
    }

    // MARK: - Menus

    private var projectMenu: some View {
        Menu {
            Button {
                selectedProject = nil
            } label: {
                HStack {
                    if selectedProject == nil {
                        Image(systemName: "checkmark")
                    }
                    Image(systemName: "tray")
                    Text("Inbox")
                }
            }
            if !projects.isEmpty {
                Divider()
                ForEach(projects) { project in
                    Button {
                        selectedProject = project
                    } label: {
                        HStack {
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                            }
                            Circle()
                                .fill(project.color)
                                .frame(width: 10, height: 10)
                            Text(project.name)
                        }
                    }
                }
            }
        } label: {
            chipLabel(
                text: selectedProject?.name ?? "Inbox",
                leading: {
                    if let p = selectedProject {
                        Circle()
                            .fill(p.color)
                            .frame(width: 8, height: 8)
                    } else {
                        Image(systemName: "tray")
                    }
                }
            )
        }
        .accessibilityIdentifier("quick-add-project")
    }

    private var dateMenu: some View {
        Menu {
            Button {
                dueDate = startOfToday
            } label: {
                HStack {
                    if isToday { Image(systemName: "checkmark") }
                    Text("Today")
                }
            }
            Button {
                dueDate = startOfTomorrow
            } label: {
                HStack {
                    if isTomorrow { Image(systemName: "checkmark") }
                    Text("Tomorrow")
                }
            }
            Button {
                dueDate = nextWeekStart
            } label: {
                HStack {
                    if isNextWeek { Image(systemName: "checkmark") }
                    Text("Next week")
                }
            }
            Divider()
            Button(role: .destructive) {
                dueDate = nil
            } label: {
                HStack {
                    if dueDate == nil { Image(systemName: "checkmark") }
                    Text("No date")
                }
            }
        } label: {
            chipLabel(
                text: dueLabel,
                leading: {
                    Image(systemName: dueDate == nil ? "calendar" : "calendar.badge.checkmark")
                }
            )
        }
        .accessibilityIdentifier("quick-add-date")
    }

    private var priorityMenu: some View {
        Menu {
            ForEach(1...4, id: \.self) { p in
                Button {
                    priority = p
                } label: {
                    HStack {
                        if priority == p {
                            Image(systemName: "checkmark")
                        }
                        Image(systemName: "flag.fill")
                            .foregroundStyle(TK.priority(p))
                        Text(priorityTitle(p))
                    }
                }
            }
        } label: {
            chipLabel(
                text: "P\(priority)",
                leading: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(priority == 4 ? TK.secondary : TK.priority(priority))
                }
            )
        }
        .accessibilityIdentifier("quick-add-priority")
    }

    @ViewBuilder
    private func chipLabel<L: View>(text: String, @ViewBuilder leading: () -> L) -> some View {
        HStack(spacing: 6) {
            leading()
            Text(text)
                .font(TK.subhead)
                .foregroundStyle(TK.ink)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(TK.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(TK.card, in: Capsule())
        .overlay(
            Capsule().stroke(TK.hairline, lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var startOfTomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    private var nextWeekStart: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
    }

    private var isToday: Bool {
        guard let d = dueDate else { return false }
        return Calendar.current.isDateInToday(d)
    }

    private var isTomorrow: Bool {
        guard let d = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(d)
    }

    private var isNextWeek: Bool {
        guard let d = dueDate else { return false }
        return Calendar.current.isDate(d, inSameDayAs: nextWeekStart)
    }

    private var dueLabel: String {
        guard let d = dueDate else { return "Date" }
        if isToday { return "Today" }
        if isTomorrow { return "Tomorrow" }
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: startOfToday, to: cal.startOfDay(for: d)).day ?? 0
        if diff > 0 && diff <= 7 {
            return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
        return d.formatted(.dateTime.day().month(.abbreviated))
    }

    private func priorityTitle(_ p: Int) -> String {
        switch p {
        case 1: return "Priority 1"
        case 2: return "Priority 2"
        case 3: return "Priority 3"
        default: return "Priority 4"
        }
    }

    private func addTask() {
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        // Natural-language parsing: typed hints (today/tomorrow/mon/p1) fill any
        // field the user didn't explicitly set via the pickers.
        let parsed = NLParser.parse(raw)
        let finalDue = dueDate ?? parsed.dueDate
        let finalPriority = (priority == 4) ? parsed.priority : priority
        Repository.add(parsed.cleanTitle, project: selectedProject, due: finalDue, priority: finalPriority, in: context)
        dismiss()
    }
}

