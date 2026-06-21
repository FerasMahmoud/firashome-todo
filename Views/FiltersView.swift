import SwiftUI
import SwiftData

/// Filters catalog — Todoist-style smart filters (Priority 1, Overdue, Today,
/// Next 7 days, No date) plus user-defined saved filters persisted in
/// SwiftData. Tapping any row pushes a filtered list of matching tasks; the
/// built-in rows use the hard-coded `FilterKind` engine and the saved rows
/// use `FilterParser` (Todoist-style query syntax: `p1 today @work …`).
struct FiltersView: View {
    /// All open (uncompleted) tasks. Single source for count badges; the
    /// pushed result view runs its own `@Query` to pick up live edits.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    /// User-defined saved filters. Favorites surface first, then alphabetical
    /// by name. SwiftData drives the list — a new row from the "new filter"
    /// sheet shows up here as soon as `modelContext.insert` lands.
    @Query(sort: [
        SortDescriptor(\SavedFilter.isFavorite, order: .reverse),
        SortDescriptor(\SavedFilter.name)
    ])
    private var savedFilters: [SavedFilter]

    /// Used by the saved-filter swipe-to-delete action and by the editor
    /// sheet's `commit()` (passed implicitly via `@Environment`).
    @Environment(\.modelContext) private var context

    @State private var showingNewFilter = false

    var body: some View {
        NavigationStack {
            List {
                // Built-in smart filters — unchanged from v1.
                Section {
                    ForEach(FilterKind.allCases) { kind in
                        filterRow(kind)
                    }
                }

                // User-defined saved filters. Each row is a NavigationLink
                // value into `SavedFilterResultView` (see navigationDestination
                // below). The "+" in the section header opens the create sheet
                // — also reachable from the toolbar for thumb reach. The
                // section is omitted entirely when the user has no filters
                // yet, so the first launch is just the smart-filter rows.
                if !savedFilters.isEmpty {
                    Section {
                        ForEach(savedFilters) { sf in
                            NavigationLink(value: sf) {
                                savedFilterRow(sf)
                            }
                            .accessibilityIdentifier("saved-filter-\(sf.id.uuidString.prefix(8))")
                        }
                        .onDelete(perform: deleteSavedFilters)
                    } header: {
                        HStack {
                            Text("Saved")
                            Spacer()
                            Button {
                                showingNewFilter = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(TK.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("New saved filter")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowSeparator(.hidden)

            .background(TK.grouped)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewFilter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New saved filter")
                    .accessibilityIdentifier("filters-new-button")
                }
            }
            .navigationDestination(for: FilterKind.self) { kind in
                FilterResultView(kind: kind)
            }
            .navigationDestination(for: SavedFilter.self) { sf in
                SavedFilterResultView(filter: sf)
            }
            .sheet(isPresented: $showingNewFilter) {
                SavedFilterEditorSheet()
            }
        }
    }

    // MARK: - Rows

    /// One built-in filter row: leading tinted icon, title, trailing count
    /// badge. Tap pushes a `FilterResultView` for the chosen kind.
    @ViewBuilder
    private func filterRow(_ kind: FilterKind) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 14) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(kind.iconTint)
                    .frame(width: 22)
                Text(kind.title)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                Spacer(minLength: 8)
                let n = count(for: kind)
                if n > 0 {
                    Text("\(n)")
                        .font(TK.subhead)
                        .foregroundStyle(TK.secondary)
                        .monospacedDigit()
                        .accessibilityLabel("\(n) tasks")
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(kind.accessibilityID)
        .accessibilityLabel(kind.title)
    }

    /// One saved-filter row: colored dot (from `colorHex`), name, and the
    /// raw query text underneath — gives the user a glanceable hint of
    /// which parser axes are in play without re-parsing on every render.
    @ViewBuilder
    private func savedFilterRow(_ sf: SavedFilter) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: sf.colorHex))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(sf.name)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .lineLimit(1)
                Text(sf.query)
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Counts

    private func count(for kind: FilterKind) -> Int {
        switch kind {
        case .priority1: return priority1Count
        case .overdue:   return overdueCount
        case .today:     return todayCount
        case .next7Days: return next7DaysCount
        case .noDate:    return noDateCount
        }
    }

    /// Open tasks flagged with the red p1 priority.
    private var priority1Count: Int {
        openTasks.reduce(into: 0) { $0 += $1.priority == 1 ? 1 : 0 }
    }

    /// Open tasks whose due date is strictly before the start of today.
    private var overdueCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if due < startOfToday { acc += 1 }
        }
    }

    /// Open tasks due any time today.
    private var todayCount: Int {
        openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if Calendar.current.isDateInToday(due) { acc += 1 }
        }
    }

    /// Open tasks due in the next 7 days, inclusive of today.
    private var next7DaysCount: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        guard let horizon = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return 0 }
        return openTasks.reduce(into: 0) { acc, t in
            guard let due = t.dueDate else { return }
            if due >= startOfToday && due < horizon { acc += 1 }
        }
    }

    /// Open tasks with no due date set.
    private var noDateCount: Int {
        openTasks.reduce(into: 0) { $0 += $1.dueDate == nil ? 1 : 0 }
    }

    // MARK: - Actions

    /// Swipe-to-delete on a saved-filter row. Persists via
    /// `Repository.deleteSavedFilter` (which handles `context.save()` and
    /// the SwiftData delete in one call). `savedFilters` is the @Query
    /// result and reflects the new state on the next render.
    private func deleteSavedFilters(at offsets: IndexSet) {
        for index in offsets {
            Repository.deleteSavedFilter(savedFilters[index], in: context)
        }
    }
}

// MARK: - Filter kinds

/// Built-in smart filters surfaced by `FiltersView`. `Hashable` + `Identifiable`
/// so it can drive `NavigationLink(value:)` and `ForEach` directly.
enum FilterKind: String, CaseIterable, Identifiable, Hashable {
    case priority1
    case overdue
    case today
    case next7Days
    case noDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .priority1: "Priority 1"
        case .overdue:   "Overdue"
        case .today:     "Today"
        case .next7Days: "Next 7 days"
        case .noDate:    "No date"
        }
    }

    var iconName: String {
        switch self {
        case .priority1: "flag.fill"
        case .overdue:   "exclamationmark.circle"
        case .today:     "sun.max"
        case .next7Days: "calendar"
        case .noDate:    "calendar.badge.minus"
        }
    }

    var iconTint: Color {
        switch self {
        case .priority1: TK.priority(1)
        case .overdue:   TK.accent
        case .today:     TK.priority(3)   // blue — distinguishes from red Priority1/Overdue (Todoist style)
        case .next7Days: TK.ink
        case .noDate:    TK.secondary
        }
    }

    var accessibilityID: String {
        switch self {
        case .priority1: "filter-priority1"
        case .overdue:   "filter-overdue"
        case .today:     "filter-today"
        case .next7Days: "filter-next7days"
        case .noDate:    "filter-nodate"
        }
    }
}

// MARK: - Filter result

/// Pushed onto the stack when a built-in filter row is tapped. Shows every
/// open task that matches the chosen `FilterKind`, sorted by priority then
/// due date.
struct FilterResultView: View {
    let kind: FilterKind
    @Query private var tasks: [TodoTask]

    var body: some View {
        Group {
            if filtered.isEmpty {
                empty
            } else {
                TaskListView(tasks: filtered, header: nil)
            }
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.large)
    }

    /// Open tasks matching the filter, sorted priority asc then due date asc.
    private var filtered: [TodoTask] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        let horizon = cal.date(byAdding: .day, value: 7, to: startOfToday) ?? .now
        return tasks
            .filter { task in
                guard !task.isCompleted else { return false }
                switch kind {
                case .priority1: return task.priority == 1
                case .overdue:
                    guard let due = task.dueDate else { return false }
                    return due < startOfToday
                case .today:
                    guard let due = task.dueDate else { return false }
                    return cal.isDateInToday(due)
                case .next7Days:
                    guard let due = task.dueDate else { return false }
                    return due >= startOfToday && due < horizon
                case .noDate:
                    return task.dueDate == nil
                }
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(TK.secondary)
            Text(emptyTitle)
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text(emptySubtitle)
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
    }

    private var emptyTitle: String {
        switch kind {
        case .priority1: "No priority 1 tasks"
        case .overdue:   "Nothing overdue"
        case .today:     "No tasks due today"
        case .next7Days: "Nothing in the next 7 days"
        case .noDate:    "Everything has a date"
        }
    }

    private var emptySubtitle: String {
        switch kind {
        case .priority1: "Tasks with the red flag will show up here."
        case .overdue:   "You're all caught up."
        case .today:     "Plan your day by adding a task with today's date."
        case .next7Days: "No tasks scheduled for the coming week."
        case .noDate:    "Tasks without a due date will show up here."
        }
    }
}

// MARK: - Saved filters

/// Pushed onto the stack when a saved filter row is tapped. Runs
/// `FilterParser.parse` on the saved query, then `FilterParser.apply` over
/// the live `@Query` of `TodoTask`, and renders matches in a `List` of
/// `TaskRowView`. Toolbar menu exposes Edit (re-opens the editor sheet
/// for the same model) and Delete (with confirmation). When the user
/// deletes, the view pops itself off the stack.
struct SavedFilterResultView: View {
    @Bindable var filter: SavedFilter

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var tasks: [TodoTask]

    @State private var showingEditor: Bool = false
    @State private var showingDeleteConfirm: Bool = false

    /// Tasks matching the parsed query, sorted priority asc then due date
    /// asc — matches the sort in `FilterResultView` so the two screens
    /// feel consistent. Recomputed on every body invalidation; the
    /// candidate set is small and the parser is a linear scan.
    private var filtered: [TodoTask] {
        let parsed = FilterParser.parse(filter.query)
        return FilterParser.apply(parsed, to: tasks)
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                empty
            } else {
                List {
                    ForEach(filtered) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            TaskRowView(task: task)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(TK.grouped)
            }
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle(filter.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit filter", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("savedfilter-result-edit")
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete filter", systemImage: "trash")
                    }
                    .accessibilityIdentifier("savedfilter-result-delete")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(TK.secondary)
                }
                .accessibilityLabel("Filter actions")
                .accessibilityIdentifier("savedfilter-result-menu")
            }
        }
        .sheet(isPresented: $showingEditor) {
            SavedFilterEditorSheet(existing: filter)
        }
        .confirmationDialog(
            "Delete this filter?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete filter", role: .destructive) {
                Repository.deleteSavedFilter(filter, in: context)
                dismiss()
            }
            .accessibilityIdentifier("savedfilter-result-delete-confirm")
            Button("Cancel", role: .cancel) { }
                .accessibilityIdentifier("savedfilter-result-delete-cancel")
        } message: {
            Text("\u{201C}\(filter.name)\u{201D} will be removed. Tasks are not affected.")
        }
    }

    @ViewBuilder
    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.isFavorite ? "star.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(filter.color)
            Text("Nothing matches this filter")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            if filter.query.isEmpty {
                Text("Add a query in Edit to see matching tasks.")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Try editing the query to widen the match.")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityIdentifier("savedfilter-result-empty")
    }
}

/// Modal sheet for creating OR editing a `SavedFilter`. Pass `existing` to
/// edit in place (Save commits edits to the live model); pass `nil` to
/// create (Save inserts a new row). Presents name + query (with a live
/// match-count preview) + color palette + favorite toggle. The query is
/// allowed to be empty (a blank filter matches every open task) — the
/// name is the only required field.
struct SavedFilterEditorSheet: View {
    let existing: SavedFilter?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Open tasks — used to compute the live "N tasks match" preview under
    /// the query field so the user can see whether their filter has bite
    /// before they save.
    @Query(filter: #Predicate<TodoTask> { $0.completedAt == nil })
    private var openTasks: [TodoTask]

    @State private var name: String
    @State private var query: String
    @State private var colorHex: String
    @State private var isFavorite: Bool

    /// Color palette — same 8 hues the Projects screen offers, kept in sync
    /// for visual consistency. Gray (`8E8E93`) is the default selection.
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

    init(existing: SavedFilter? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _query = State(initialValue: existing?.query ?? "")
        _colorHex = State(
            initialValue: existing?.colorHex
                ?? (SavedFilterEditorSheet.palette.last ?? "8E8E93")
        )
        _isFavorite = State(initialValue: existing?.isFavorite ?? false)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                nameField
                queryField
                colorPicker
                favoriteToggle
                Spacer(minLength: 0)
                saveButton
            }
            .padding(20)
            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
            .navigationTitle(existing == nil ? "New filter" : "Edit filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TK.secondary)
                        .accessibilityIdentifier("savedfilter-editor-cancel")
                }
            }
        }
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
            TextField("e.g. Work tasks", text: $name)
                .textFieldStyle(.plain)
                .font(TK.body)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(TK.grouped)
                .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
                .submitLabel(.next)
                .accessibilityIdentifier("savedfilter-editor-name")
        }
    }

    private var queryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Query")
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
            TextField("e.g. p1 today @work", text: $query)
                .textFieldStyle(.plain)
                .font(TK.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(TK.grouped)
                .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
                .accessibilityIdentifier("savedfilter-editor-query")
            Text(previewText)
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .accessibilityIdentifier("savedfilter-editor-preview")
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(TK.sectionHeader)
                .foregroundStyle(TK.secondary)
            HStack(spacing: 14) {
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .stroke(
                                        colorHex == hex ? TK.ink : TK.hairline,
                                        lineWidth: colorHex == hex ? 2 : 0.5
                                    )
                            }
                            .overlay {
                                if colorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                    .accessibilityIdentifier("savedfilter-editor-color-\(hex)")
                }
            }
        }
    }

    private var favoriteToggle: some View {
        Button {
            isFavorite.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isFavorite ? TK.priority(2) : TK.secondary)
                    .frame(width: 22)
                Text("Show in favorites")
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                Spacer(minLength: 8)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(TK.grouped)
            .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("savedfilter-editor-favorite")
    }

    private var saveButton: some View {
        Button {
            commit()
        } label: {
            Text(existing == nil ? "Add filter" : "Save")
                .font(TK.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? TK.accent : TK.secondary)
                .clipShape(RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
        }
        .disabled(!canSave)
        .accessibilityIdentifier("savedfilter-editor-save")
    }

    // MARK: - Preview

    /// Human-readable line under the query field. For an empty query,
    /// prompts the user to add one. For a parsed query, shows the count of
    /// open tasks that would match — live, so the user can see whether
    /// their filter is too narrow or too wide before they commit.
    private var previewText: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Leave blank to match all open tasks." }
        let parsed = FilterParser.parse(trimmed)
        if parsed.isEmpty { return "Matches every open task." }
        let count = FilterParser.apply(parsed, to: openTasks).count
        if count == 0 { return "0 open tasks match this query." }
        return "\(count) open task\(count == 1 ? "" : "s") match this query."
    }

    // MARK: - Save gate

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.name = trimmedName
            existing.query = trimmedQuery
            existing.colorHex = colorHex
            existing.isFavorite = isFavorite
            try? context.save()
        } else {
            Repository.addSavedFilter(
                name: trimmedName,
                query: trimmedQuery,
                colorHex: colorHex,
                isFavorite: isFavorite,
                in: context
            )
        }
        dismiss()
    }
}
