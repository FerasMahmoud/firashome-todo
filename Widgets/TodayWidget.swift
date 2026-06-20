import WidgetKit
import SwiftUI

/// Home-screen widget. Three families. Light Todoist-style.
struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    TK.canvas
                }
        }
        .configurationDisplayName("Today")
        .description("Your tasks due today, at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: WidgetSnapshot(todayCount: 5, overdueCount: 2, nextTaskTitle: "Review drone survey brief", updatedAt: .now))
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: SnapshotStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: .now, snapshot: SnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .systemSmall:  small
        case .systemMedium: medium
        default:            large
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(entry.snapshot.todayCount)")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(TK.accent)
            Text("due today")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TK.secondary)
            Spacer()
            if entry.snapshot.overdueCount > 0 {
                HStack { Image(systemName: "exclamationmark.circle"); Text("\(entry.snapshot.overdueCount) overdue") }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TK.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(4)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.snapshot.todayCount)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(TK.accent)
                Text("today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TK.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("UP NEXT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                    .tracking(0.5)
                if let next = entry.snapshot.nextTaskTitle {
                    Text(next)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TK.ink)
                        .lineLimit(2)
                } else {
                    Text("You're all clear")
                        .font(.system(size: 15))
                        .foregroundStyle(TK.secondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(entry.snapshot.todayCount)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(TK.accent)
                Text("tasks today")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TK.secondary)
            }
            Divider()
            if let next = entry.snapshot.nextTaskTitle {
                HStack { Image(systemName: "circle"); Text(next) }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TK.ink)
                    .lineLimit(2)
            }
            if entry.snapshot.overdueCount > 0 {
                HStack { Image(systemName: "exclamationmark.triangle.fill"); Text("\(entry.snapshot.overdueCount) overdue") }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TK.accent)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(4)
    }
}
