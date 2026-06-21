import SwiftUI

/// What the user has assigned to a single row-swipe edge.
///
/// `SwipeConfig` persists one of these per edge (`leading`, `trailing`) in
/// UserDefaults via @AppStorage. `TaskRowView` reads the current choices and
/// renders (or hides) the corresponding `swipeActions` button for each edge.
///
/// `rawValue` is the persisted string — never rename a case; old UserDefaults
/// values would silently fall back to the default instead.
enum SwipeAction: String, CaseIterable, Identifiable {
    case none
    case complete
    case delete
    case archive

    var id: String { rawValue }

    /// Human-readable name. Used in any future settings UI that lets the
    /// user pick an action per edge.
    var label: String {
        switch self {
        case .none:     return "None"
        case .complete: return "Complete"
        case .delete:   return "Delete"
        case .archive:  return "Archive"
        }
    }

    /// Default SF Symbol for the action's swipe button. The `complete` row
    /// flips to the Undo symbol at render time based on `task.isCompleted`
    /// (see `TaskRowView.swipeButton`).
    var symbol: String {
        switch self {
        case .none:     return "minus.circle"
        case .complete: return "checkmark.circle.fill"
        case .delete:   return "trash"
        case .archive:  return "archivebox"
        }
    }
}

/// Tier-2: user picks what each swipe edge of a task row does. Defaults
/// match the original Todoist behaviour — leading edge completes the task,
/// trailing edge deletes it. Persisted via @AppStorage; observed by every
/// `TaskRowView` instance so a settings change re-renders all visible rows
/// in place.
///
/// `static let shared` is the only instance — same shape as
/// `DensityManager.shared` and `ThemeManager.shared`. Property initializers
/// on the view read it via `@ObservedObject private var swipe = SwipeConfig.shared`.
///
/// ponytail: ceiling — if the user ever wants per-edge multi-button stacks
/// (e.g. Delete + Archive on the same edge), widen `SwipeAction` into a set
/// or list rather than introducing a parallel config. The current
/// 1-action-per-edge shape covers Todoist's choices and matches iOS'
/// single-gesture-per-edge swipe model.
final class SwipeConfig: ObservableObject {
    static let shared = SwipeConfig()

    @AppStorage("swipe-leading")  private var leadingRaw:  String = SwipeAction.complete.rawValue
    @AppStorage("swipe-trailing") private var trailingRaw: String = SwipeAction.delete.rawValue

    private init() {}

    var leadingAction: SwipeAction {
        get { SwipeAction(rawValue: leadingRaw) ?? .complete }
        set { leadingRaw = newValue.rawValue }
    }

    var trailingAction: SwipeAction {
        get { SwipeAction(rawValue: trailingRaw) ?? .delete }
        set { trailingRaw = newValue.rawValue }
    }
}
