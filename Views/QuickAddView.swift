import SwiftUI
import SwiftData

/// Quick-add bottom sheet for creating a TodoTask with minimal friction.
/// Natural-language title field plus compact pickers for project / date / priority.
///
/// Live NL parse preview: as the user types, a compact row under the title
/// field summarizes what `NLParser` detected (date / priority / project /
/// labels / reminder / recurrence). On Add, the typed hints fill any field
/// the user didn't explicitly set via the chips, then any unhandled bits
/// (project, labels, recurrence rule, reminder) are taken straight from the
/// parse result.
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.order) private var projects: [Project]
    @Query private var allLabels: [Label]

    @State private var title: String = ""
    @State private var selectedProject: Project?
    @State private var dueDate: Date?
    @State private var priority: Int = 4
    /// Recurrence raw value (matches `RecurrenceKind.storageValue`). `nil`
    /// means the task is a one-off — no repeat.
    @State private var recurrence: String? = nil
    @FocusState private var titleFocused: Bool

    /// Live parse of the title field. `nil` until the user types something.
    private var parsed: ParsedTask? {
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return NLParser.parse(raw, projects: projects, labels: allLabels)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                handle

                titleField

                parsePreview
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                controls
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 16)
            }
            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
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
                title = "Review drone brief p1 tomorrow #FITech !1h every week"
                priority = 1
                dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                selectedProject = projects.first(where: { $0.name == "FITech" }) ?? projects.first
                recurrence = "weekly"
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
            "e.g., Review drone brief tomorrow p1 #FITech !1h",
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

    /// Compact summary of what the NL parser extracted from `title`. Hidden
    /// when the title is empty or the parser found nothing interesting. Chips
    /// use TK.secondary text at 13pt to read as a quiet hint, not a primary
    /// control.
    @ViewBuilder
    private var parsePreview: some View {
        if let p = parsed {
            let bits = parseSummary(for: p)
            if !bits.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                    summaryFlow(bits: bits)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(TK.secondary)
                .accessibilityIdentifier("quick-add-parse-preview")
            }
        }
    }

    /// Build the ordered list of human-readable summary chips for the parse
    /// preview. Order = date, priority, project, labels, reminder, recurrence
    /// — the same order the user typically reads left-to-right.
    private func parseSummary(for p: ParsedTask) -> [String] {
        var bits: [String] = []
        if let d = p.dueDate {
            bits.append("due \(Self.relativeDayLabel(d))")
        }
        if p.priority < 4 {
            bits.append("P\(p.priority)")
        }
        if let proj = p.project {
            bits.append("#\(proj.name)")
        }
        if !p.labels.isEmpty {
            bits.append(p.labels.map { "@\($0.name)" }.joined(separator: " "))
        }
        if let _ = p.reminderDate {
            bits.append("reminder set")
        }
        if let r = p.recurrenceRule {
            bits.append(r)
        }
        return bits
    }

    /// Wrap summary chips onto multiple lines when the title carries a lot
    /// of recognized tokens. InlineFlow is a tiny HStack-of-HStacks packer.
    @ViewBuilder
    private func summaryFlow(bits: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(splitForFlow(bits).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 6) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, chip in
                        Text(chip)
                    }
                }
            }
        }
    }

    /// Greedy line-packer: each chip joins the current line if it fits under
    /// ~48 chars, otherwise starts a new line. No measurement needed at
    /// this size — character count is a fine proxy.
    private func splitForFlow(_ chips: [String]) -> [[String]] {
        var lines: [[String]] = [[]]
        var current = 0
        for chip in chips {
            let candidate = lines[current] + [chip]
            let joined = candidate.joined(separator: " · ")
            if joined.count > 48, !lines[current].isEmpty {
                lines.append([chip])
                current += 1
            } else {
                lines[current].append(chip)
            }
        }
        return lines
    }

    /// "today" / "tomorrow" / "Mon, Jun 23" — the same vocabulary the date
    /// chip uses, so the preview and the chip never disagree.
    private static func relativeDayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "today" }
        if cal.isDateInTomorrow(d) { return "tomorrow" }
        let start = cal.startOfDay(for: .now)
        let diff = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: d)).day ?? 0
        if diff > 0 && diff <= 7 {
            return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }

    private var controls: some View {
        HStack(spacing: 8) {
            projectMenu
            dateMenu
            priorityMenu
            recurrenceMenu
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

    private var recurrenceMenu: some View {
        Menu {
            Button {
                recurrence = nil
            } label: {
                HStack {
                    if recurrence == nil { Image(systemName: "checkmark") }
                    Text("No repeat")
                }
            }
            Divider()
            ForEach(RecurrenceKind.allCases) { kind in
                Button {
                    recurrence = kind.storageValue
                } label: {
                    HStack {
                        if recurrence == kind.storageValue { Image(systemName: "checkmark") }
                        Image(systemName: kind.icon)
                        Text(kind.label)
                    }
                }
            }
        } label: {
            chipLabel(
                text: recurrenceLabel,
                leading: {
                    Image(systemName: recurrence == nil ? "arrow.clockwise" : "arrow.clockwise.circle.fill")
                        .foregroundStyle(recurrence == nil ? TK.secondary : TK.accent)
                }
            )
        }
        .accessibilityIdentifier("quick-add-recurrence")
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

    /// Compact label for the repeat chip. "No repeat" when unset, otherwise
    /// the kind's own label (Daily / Weekly / Monthly / Yearly).
    private var recurrenceLabel: String {
        guard let r = recurrence, let kind = RecurrenceKind(rawValue: r) else { return "Repeat" }
        return kind.label
    }

    private func addTask() {
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        // Re-parse at the moment of save so the preview can't drift from the
        // stored state (e.g. projects list changed while the sheet was open).
        let parsed = NLParser.parse(raw, projects: projects, labels: allLabels)
        // Chip wins over typed hint ONLY when the user actually changed the
        // chip from its default. Default priority is 4 (none) and default
        // dueDate is nil — the typed hint fills either of those. Recurrence
        // chip is set explicitly by tapping, so `nil` means "not chosen" and
        // the typed hint can fill it.
        let finalDue = dueDate ?? parsed.dueDate
        let finalPriority = (priority == 4) ? parsed.priority : priority
        let finalRecurrence = recurrence ?? parsed.recurrenceRule
        // Project / labels: the chip only sets project. The typed hint is the
        // only way to get labels on a quick-add — accept whatever the parser
        // found, dedup'd against whatever the chip already has.
        let finalProject = selectedProject ?? parsed.project
        let finalLabels = parsed.labels

        let task = Repository.add(
            parsed.cleanTitle,
            project: finalProject,
            due: finalDue,
            priority: finalPriority,
            recurrence: finalRecurrence,
            labels: finalLabels,
            in: context
        )

        // Reminder is a side-channel SwiftData model attached to the task.
        // Only one quick-add reminder is possible per task — if the user typed
        // multiple `!` shortcuts, the parser's first-match-wins keeps the
        // earliest one, matching what the preview shows.
        if let reminder = parsed.reminderDate {
            let r = Reminder(date: reminder)
            r.task = task
            context.insert(r)
            task.reminders.append(r)
            try? context.save()
        }
        dismiss()
    }
}
