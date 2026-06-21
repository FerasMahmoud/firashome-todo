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
        // Touch: swipe-left → Delete, swipe-right → Complete/Undo.
        // Applied on the row itself so EVERY list using TaskRowView (Inbox,
        // Today, Upcoming, Filters, Project detail, TaskListView) gets the
        // same actions — single source of truth.
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Repository.delete(task, in: context)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(TK.accent)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Repository.toggle(task, in: context)
            } label: {
                Label(task.isCompleted ? "Undo" : "Complete",
                      systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
            }
            .tint(Color(red: 0.18, green: 0.69, blue: 0.34))
        }
        // PC / mouse: right-click. Touch: long-press. Same actions as swipe
        // so the row is fully usable without a swipe gesture.
        .contextMenu {
            Button {
                Repository.toggle(task, in: context)
            } label: {
                Label(task.isCompleted ? "Mark incomplete" : "Mark complete",
                      systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            Button(role: .destructive) {
                Repository.delete(task, in: context)
            } label: {
                Label("Delete", systemImage: "trash")
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

