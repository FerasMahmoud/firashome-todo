import SwiftUI
import SwiftData

/// Activity feed — chronological list of task lifecycle events (created,
/// completed, updated). Decoupled from `TodoTask` via the denormalized
/// `taskTitle` + `projectID` on `ActivityEvent`, so the feed survives task
/// deletion (a deleted task's history is still readable here).
///
/// Newest first, grouped by day. Toolbar offers a destructive "Clear" with a
/// confirmation dialog. Light theme, `TK.*` tokens, SF Symbols only.
struct ActivityLogView: View {
    /// Every event in the store, newest first. Drives the day-grouped list.
    @Query(sort: \ActivityEvent.at, order: .reverse) private var events: [ActivityEvent]

    /// All projects, used to resolve the optional `projectID` into a name + color.
    @Query private var projects: [Project]

    @Environment(\.modelContext) private var ctx

    @State private var showingClearConfirm = false

    /// `projectID` -> `Project` lookup, rebuilt each render. Project count is
    /// small (a few dozen at most) so a dict beats scanning the array per row.
    /// `ponytail:` ceiling = O(n) on every body; upgrade to a memoized cache
    /// keyed on `projects.count` if the project list grows past ~200.
    private var projectByID: [UUID: Project] {
        Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !events.isEmpty {
                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("activity-count")
            }
            content
        }
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !events.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { showingClearConfirm = true }
                        .foregroundStyle(TK.accent)
                        .accessibilityLabel("Clear activity")
                        .accessibilityIdentifier("activity-clear")
                }
            }
        }
        .confirmationDialog(
            "Clear all activity?",
            isPresented: $showingClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear all", role: .destructive) { clearAll() }
                .accessibilityIdentifier("activity-clear-confirm")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("activity-clear-cancel")
        } message: {
            Text("This permanently removes the activity log.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if events.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(buckets) { bucket in
                Section {
                    ForEach(bucket.events) { event in
                        ActivityRow(event: event, project: projectFor(event.projectID))
                            .listRowSeparatorTint(TK.hairlineSoft)
                    }
                } header: {
                    HStack {
                        Text(bucket.label)
                            .font(TK.sectionHeader)
                            .foregroundStyle(TK.secondary)
                            .textCase(nil)
                        Spacer(minLength: 8)
                        Text("\(bucket.events.count)")
                            .font(TK.sectionHeader)
                            .foregroundStyle(TK.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("activity-day-header-\(bucket.idString)")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No activity yet")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("When you create, complete, or update a task, it'll show up here.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("activity-empty-state")
        .accessibilityLabel("No activity yet. When you create, complete, or update a task, it'll show up here.")
    }

    // MARK: - Mutate

    /// Delete every event in the store. `Repository` is intentionally not
    /// extended here (this view is the only file the agent owns); the loop is
    /// cheap because the candidate set is already in memory via `@Query`.
    private func clearAll() {
        for event in events {
            ctx.delete(event)
        }
        try? ctx.save()
    }

    // MARK: - Lookup + bucketing

    /// Resolve an optional `projectID` to its `Project` via the dict lookup.
    /// Returns `nil` when the project has been deleted (the ID still resolves
    /// gracefully — the row simply omits the project chip).
    private func projectFor(_ id: UUID?) -> Project? {
        guard let id else { return nil }
        return projectByID[id]
    }

    /// One bucket per calendar day, newest day first. Within a day, events are
    /// sorted newest first. Sorted by `Date` so the section order is stable
    /// across the `@Query` refresh.
    private var buckets: [DayBucket] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            cal.startOfDay(for: event.at)
        }
        return grouped.keys.sorted(by: >).map { day in
            let dayEvents = (grouped[day] ?? []).sorted { $0.at > $1.at }
            return DayBucket(date: day, label: Self.dayLabel(for: day), events: dayEvents)
        }
    }

    /// Section label for a day-start: "Today", "Yesterday", or "Mon 21 Jun".
    /// Mirrors `UpcomingView.dayLabel` for visual consistency.
    private static func dayLabel(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

// MARK: - Day bucket

/// A calendar-day's worth of activity events, plus the label to show in the
/// section header. `id` is the day start so re-ordering keeps the bucket
/// stable across `@Query` refreshes.
private struct DayBucket: Identifiable {
    let date: Date
    let label: String
    let events: [ActivityEvent]

    var id: Date { date }

    /// Stable string for `accessibilityIdentifier` (Date ids can't appear in
    /// identifiers directly). Same trick `UpcomingView.DayBucket` uses.
    var idString: String {
        ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Row

/// A single activity feed entry: leading action icon, task title + optional
/// project chip, trailing timestamp. Non-tappable — the log is read-only.
private struct ActivityRow: View {
    let event: ActivityEvent
    let project: Project?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.taskTitle)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let project {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(project.name)
                            .font(.system(size: 13))
                            .foregroundStyle(TK.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityLabel("in \(project.name)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(relativeLabel)
                .font(.system(size: 13))
                .foregroundStyle(TK.secondary)
                .monospacedDigit()
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("activity-row-\(event.id.uuidString.prefix(8))")
    }

    // MARK: Icon + color mapping

    /// SF Symbol for the event `kind`. The model stores `kind` as a loose
    /// `String` (per `project_activity_event_model` memory) — keep the switch
    /// exhaustive against the documented set, fall through to a neutral icon
    /// for anything new. Don't introduce an `ActivityKind` enum here.
    private var icon: String {
        switch event.kind {
        case "created":   return "plus.circle"
        case "completed": return "checkmark.circle.fill"
        case "updated":   return "pencil.circle"
        default:          return "circle"
        }
    }

    /// Single-accent rule: only "completed" uses `TK.accent` (red). Everything
    /// else is muted secondary — matches the brand restraint of one red
    /// highlight in the row.
    private var iconColor: Color {
        event.kind == "completed" ? TK.accent : TK.secondary
    }

    // MARK: Relative time

    /// Human-friendly relative timestamp. Today: "just now" / "5 min ago" /
    /// "2 hr ago". Any other day: the time-of-day (the section header above
    /// already conveys the day, so duplicating it as a weekday name would be
    /// noise).
    private var relativeLabel: String {
        let cal = Calendar.current
        let interval = Date.now.timeIntervalSince(event.at)
        if interval < 60 { return "just now" }
        if cal.isDateInToday(event.at) {
            if interval < 3600 { return "\(Int(interval / 60)) min ago" }
            return "\(Int(interval / 3600)) hr ago"
        }
        return event.at.formatted(date: .omitted, time: .shortened)
    }

    // MARK: Accessibility summary

    private var accessibilitySummary: String {
        var parts = [actionLabel, event.taskTitle]
        if let project { parts.append("in \(project.name)") }
        parts.append(relativeLabel)
        return parts.joined(separator: ", ")
    }

    private var actionLabel: String {
        switch event.kind {
        case "created":   return "Created"
        case "completed": return "Completed"
        case "updated":   return "Updated"
        default:          return event.kind.capitalized
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ActivityEvent.self,
        configurations: config
    )
    let ctx = container.mainContext
    let now = Date()
    let cal = Calendar.current
    let entries: [(kind: String, title: String, offset: TimeInterval)] = [
        ("completed", "Send weekly status report",   -60 * 12),
        ("created",   "Review Q3 drone proposal",    -60 * 60 * 4),
        ("completed", "Old draft proposal",          -60 * 60 * 26),
        ("updated",   "Qiddiya brief",               -60 * 60 * 30),
        ("created",   "Wireframe onboarding flow",   -60 * 60 * 24 * 4),
    ]
    for entry in entries {
        let e = ActivityEvent(kind: entry.kind, taskTitle: entry.title)
        e.at = cal.date(byAdding: .second, value: Int(entry.offset), to: now) ?? now
        ctx.insert(e)
    }
    return NavigationStack {
        ActivityLogView()
    }
    .modelContainer(container)
}
