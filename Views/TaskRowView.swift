import SwiftUI
import SwiftData

/// A single row in any task list (Today, Upcoming, Project detail, Filters, etc.).
///
/// Matches Todoist's row layout exactly:
///   [○ checkbox]  Title (2-line, strikethrough if done)
///                  · project · Today
///                                            [⚑]
///
/// The row is wrapped in a `NavigationLink` by the parent — we only own the
/// checkbox tap and the visual layout. Light theme, `TK.*` tokens, SF Symbols only.
struct TaskRowView: View {
    let task: TodoTask

    @Environment(\.modelContext) private var context
    @Environment(\.hideRedundantDue) private var hideRedundantDue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkbox
            VStack(alignment: .leading, spacing: 4) {
                titleLine
                if showsMeta {
                    metaLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingFlag
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens task details")
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
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .strokeBorder(TK.priority(task.priority), lineWidth: 1.8)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-row-checkbox-\(task.id.uuidString.prefix(8))")
        .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
        .padding(.top, 2)
    }

    // MARK: - Title

    private var titleLine: some View {
        Text(task.title)
            .font(TK.body)
            .foregroundStyle(task.isCompleted ? TK.secondary : TK.ink)
            .strikethrough(task.isCompleted, color: TK.secondary)
            .lineLimit(2)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Meta line (project + due)

    private var showsMeta: Bool {
        task.project != nil || task.dueDate != nil
    }

    private var metaLine: some View {
        HStack(spacing: 10) {
            if let project = task.project {
                projectBadge(project)
            }
            if let due = dueChip, !hideRedundantDue {
                dueBadge(due)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 1)
    }

    private func projectBadge(_ project: Project) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(project.color)
                .frame(width: 7, height: 7)
            Text(project.name)
                .font(.system(size: 13))
                .foregroundStyle(TK.secondary)
                .lineLimit(1)
        }
        .accessibilityIdentifier("task-row-project-\(task.id.uuidString.prefix(8))")
    }

    private func dueBadge(_ chip: DueChip) -> some View {
        HStack(spacing: 4) {
            if chip.isOverdue {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 12, weight: .medium))
            }
            Text(chip.text)
                .font(.system(size: 13))
                .foregroundStyle(chip.isOverdue ? TK.accent : TK.secondary)
        }
        .accessibilityIdentifier("task-row-due-\(task.id.uuidString.prefix(8))")
    }

    // MARK: - Trailing priority flag

    @ViewBuilder
    private var trailingFlag: some View {
        if (1...3).contains(task.priority) {
            Image(systemName: "flag.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TK.priority(task.priority))
                .padding(.top, 3)
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

