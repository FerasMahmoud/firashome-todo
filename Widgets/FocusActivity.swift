import ActivityKit
import WidgetKit
import SwiftUI

/// Dynamic Island Live Activity — a "focus" session on the current task.
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Hashable, Codable {
        var taskTitle: String
        var elapsedSeconds: Int
    }
}

@available(iOS 16.1, *)
struct FocusActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(TK.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focusing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                    Text(context.state.taskTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TK.ink)
                        .lineLimit(1)
                }
                Spacer()
                Text(timeString(context.state.elapsedSeconds))
                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(TK.accent)
            }
            .padding(16)
            .activityBackgroundTint(Color(white: 0.97))
            .activitySystemActionForegroundColor(TK.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack { Image(systemName: "checklist"); Text("Focus") }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timeString(context.state.elapsedSeconds))
                        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(TK.accent)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.taskTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TK.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "checklist")
                    .foregroundStyle(TK.accent)
            } compactTrailing: {
                Text(timeString(context.state.elapsedSeconds))
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(TK.ink)
            } minimal: {
                Image(systemName: "checklist")
                    .foregroundStyle(TK.accent)
            }
            .keylineTint(TK.accent)
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
