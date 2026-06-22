import SwiftUI
import SwiftData

/// A single row in any task list (Today, Upcoming, Project detail, Filters, etc.).
///
/// All visual rhythm (paddings, title line-limit, font sizes, checkbox / flag
/// sizes, corner radius) is driven by `DensityManager.shared.mode` — see
/// `Design/Density.swift`. Default `.comfortable` matches the original Todoist
/// layout exactly; `.compact` is a denser 1-line-title variant the user can
/// toggle (persisted via @AppStorage). The view observes `DM` so toggling
/// density re-renders every list in place.
///
/// The row is wrapped in a `NavigationLink` by the parent — we only own the
/// checkbox tap and the visual layout. Light theme, `TK.*` tokens, SF Symbols only.
struct TaskRowView: View {
    let task: TodoTask

    @Environment(\.modelContext) private var context
    @Environment(\.hideRedundantDue) private var hideRedundantDue
    @ObservedObject private var DM = DensityManager.shared
    @ObservedObject private var swipe = SwipeConfig.shared

    /// Short alias so the body reads `m.rowVPadding` instead of
    /// `DM.mode.metrics.rowVPadding`. Re-evaluated each render — cheap.
    private var m: DensityMetrics { DM.mode.metrics }

    var body: some View {
        HStack(alignment: .top, spacing: m.hstackSpacing) {
            checkbox
            VStack(alignment: .leading, spacing: m.titleToMeta) {
                titleLine
                if showsMeta {
                    metaLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingFlag
        }
        .padding(.vertical, m.rowVPadding)
        .padding(.horizontal, m.rowHPadding)
        .background {
            if TK.isDarkGlass {
                RoundedRectangle(cornerRadius: m.rowCorner, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: m.rowCorner, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            }
        }
        .contentShape(Rectangle())
        // Haptic on complete/undo — fires for ALL toggle paths
        // (checkbox tap, swipe-right, context menu) because they all
        // flip task.isCompleted. iOS 17+; no-op on older OS.
        .sensoryFeedback(.impact(weight: .medium), trigger: task.isCompleted)
        // Touch: user-configurable swipe. Both edges always carry a modifier
        // so the gesture is consistently attached; an edge with `.none` just
        // renders `EmptyView()` — the swipe happens, no button appears.
        // Settings in `SwipeConfig` are observed here, so a toggle re-renders
        // every visible row in place.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            swipeButton(for: swipe.trailingAction)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            swipeButton(for: swipe.leadingAction)
        }
        // PC / mouse: right-click. Touch: long-press. Same actions as swipe
        // so the row is fully usable without a swipe gesture.
        .contextMenu {
            Button {
                Repository.toggle(task, in: context)
            } label: {
                SwiftUI.Label(task.isCompleted ? "Mark incomplete" : "Mark complete",
                      systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            Button(role: .destructive) {
                Repository.delete(task, in: context)
            } label: {
                SwiftUI.Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Swipe or right-click for actions")
    }

    // MARK: - Leading checkbox

    private var checkbox: some View {
        Button {
            Repository.toggle(task, in: context)
        } label: {
            ZStack {
                if task.isCompleted {
                    Circle()
                        .fill(TK.completedFill)
                        .frame(width: m.checkboxSize, height: m.checkboxSize)
                    Image(systemName: "checkmark")
                        .font(m.checkmarkFont)
                        .foregroundStyle(.white)
                        // Apple Motion: bounce the checkmark when completion
                        // flips. On un-complete the symbol disappears with
                        // its enclosing if-branch, so the effect only fires
                        // on the visible (true) side.
                        .symbolEffect(.bounce, value: task.isCompleted)
                } else {
                    Circle()
                        .strokeBorder(TK.priority(task.priority), lineWidth: 1.8)
                        .frame(width: m.checkboxSize, height: m.checkboxSize)
                }
            }
            .frame(width: m.checkboxSize, height: m.checkboxSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-row-checkbox-\(task.id.uuidString.prefix(8))")
        .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        .padding(.top, m.checkboxTopPadding)
    }

    // MARK: - Swipe button (driven by SwipeConfig)

    /// Builds the button for one edge's configured action. `.none` returns
    /// `EmptyView()` so the row still carries the `.swipeActions` modifier
    /// (consistent gesture handling) but reveals nothing on swipe.
    @ViewBuilder
    private func swipeButton(for action: SwipeAction) -> some View {
        switch action {
        case .none:
            EmptyView()
        case .complete:
            Button {
                Repository.toggle(task, in: context)
            } label: {
                SwiftUI.Label(task.isCompleted ? "Undo" : "Complete",
                      systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
            }
            .tint(Color(red: 0.18, green: 0.69, blue: 0.34))
        case .delete:
            Button(role: .destructive) {
                Repository.delete(task, in: context)
            } label: {
                SwiftUI.Label("Delete", systemImage: "trash")
            }
            .tint(TK.accent)
        case .archive:
            Button {
                Repository.archive(task, in: context)
            } label: {
                SwiftUI.Label("Archive", systemImage: "archivebox")
            }
            // Warm amber — distinct from complete-green and delete-red so the
            // three swipe actions read at a glance on any theme.
            .tint(Color(red: 0.85, green: 0.58, blue: 0.20))
        }
    }

    // MARK: - Title

    private var titleLine: some View {
        Text(task.title)
            .font(TK.body)
            .foregroundStyle(task.isCompleted ? TK.secondary : TK.ink)
            .strikethrough(task.isCompleted, color: TK.secondary)
            .lineLimit(m.titleLineLimit)
            .lineSpacing(m.titleLineSpacing)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            // Apple Motion: crossfade title content on state flip…
            .contentTransition(.opacity)
            // …and spring the strikethrough (and any other value-driven
            // change on this Text) for a snappy but soft settle.
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: task.isCompleted)
    }

    // MARK: - Meta line (project + due)

    private var showsMeta: Bool {
        task.project != nil || task.dueDate != nil
    }

    private var metaLine: some View {
        HStack(spacing: m.metaHstackSpacing) {
            if let project = task.project {
                projectBadge(project)
            }
            if let due = dueChip, !hideRedundantDue {
                dueBadge(due)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, m.metaTopPadding)
    }

    private func projectBadge(_ project: Project) -> some View {
        HStack(spacing: m.projectBadgeSpacing) {
            Circle()
                .fill(project.color)
                .frame(width: m.projectDotSize, height: m.projectDotSize)
            Text(project.name)
                .font(m.metaFont)
                .foregroundStyle(TK.secondary)
                .lineLimit(1)
        }
        .accessibilityIdentifier("task-row-project-\(task.id.uuidString.prefix(8))")
    }

    private func dueBadge(_ chip: DueChip) -> some View {
        HStack(spacing: m.dueBadgeSpacing) {
            if chip.isOverdue {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(m.dueIconFont)
            }
            Text(chip.text)
                .font(m.metaFont)
                .foregroundStyle(chip.isOverdue ? TK.accent : TK.secondary)
        }
        .accessibilityIdentifier("task-row-due-\(task.id.uuidString.prefix(8))")
    }

    // MARK: - Trailing priority flag

    @ViewBuilder
    private var trailingFlag: some View {
        if (1...3).contains(task.priority) {
            Image(systemName: "flag.fill")
                .font(m.flagFont)
                .foregroundStyle(TK.priority(task.priority))
                .padding(.top, m.flagTopPadding)
                .accessibilityIdentifier("task-row-flag-\(task.id.uuidString.prefix(8))")
                .accessibilityLabel("Priority \(task.priority)")
        }
    }

    // MARK: - Due-chip derivation

    private struct DueChip {
        let text: String
        let isOverdue: Bool
    }

    private var dueChip: DueChip? {
        guard let due = task.dueDate else { return nil }
        let cal = Calendar.current
        let isOverdue = !task.isCompleted
            && due < Date()
            && !cal.isDateInToday(due)

        let text: String
        if cal.isDateInToday(due) {
            text = "Today"
        } else if cal.isDateInTomorrow(due) {
            text = "Tomorrow"
        } else if cal.isDateInYesterday(due) {
            text = "Yesterday"
        } else {
            // Same idea as Todoist: short weekday within a week, otherwise day + month.
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: due)).day ?? 0
            if abs(days) <= 7 {
                text = due.formatted(.dateTime.weekday(.abbreviated))
            } else {
                text = due.formatted(.dateTime.day().month(.abbreviated))
            }
        }
        return DueChip(text: text, isOverdue: isOverdue)
    }

    // MARK: - Accessibility summary

    private var accessibilityLabel: String {
        var parts: [String] = [task.title]
        if task.isCompleted { parts.append("completed") }
        if (1...3).contains(task.priority) {
            parts.append("priority \(task.priority)")
        }
        if let project = task.project { parts.append("in \(project.name)") }
        if let due = task.dueDate {
            parts.append("due \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

