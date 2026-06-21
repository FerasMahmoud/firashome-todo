import SwiftUI

enum DensityMode: Int, CaseIterable {
    case compact
    case comfortable
    var label: String { self == .compact ? "Compact" : "Comfortable" }
}

/// Global row-density state. Root view observes it so toggling re-renders every list.
final class DensityManager: ObservableObject {
    static let shared = DensityManager()
    @AppStorage("density") private var raw: Int = 1   // 0 = compact, 1 = comfortable (default)
    private init() {}

    var mode: DensityMode {
        get { raw == 0 ? .compact : .comfortable }
        set { raw = newValue == .compact ? 0 : 1 }
    }
}

// MARK: - Row metrics

extension DensityMode {
    /// Row-density metrics for this mode. Single source of truth for visual
    /// rhythm — the row view reads from this rather than hard-coding pixels,
    /// so changing density is a one-file edit.
    var metrics: DensityMetrics {
        switch self {
        case .compact:     return .compact
        case .comfortable: return .comfortable
        }
    }
}

/// All numeric knobs a row reads from `DensityMode.metrics`.
///
/// ponytail: ceiling — if cards / pickers / sheet detents ever need their
/// own metrics, widen this struct and group by purpose rather than nesting
/// into nested structs. The goal is "one mode, one metrics struct" per
/// visual region.
struct DensityMetrics {
    // Row chrome
    let rowVPadding: CGFloat
    let rowHPadding: CGFloat
    let rowCorner: CGFloat
    let hstackSpacing: CGFloat          // checkbox <-> title <-> flag

    // Title
    let titleLineLimit: Int
    let titleLineSpacing: CGFloat
    let titleToMeta: CGFloat            // VStack(spacing:)

    // Meta (project / due)
    let metaTopPadding: CGFloat
    let metaHstackSpacing: CGFloat
    let metaFont: Font
    let projectDotSize: CGFloat
    let projectBadgeSpacing: CGFloat
    let dueBadgeSpacing: CGFloat
    let dueIconFont: Font

    // Checkbox + flag
    let checkboxSize: CGFloat
    let checkboxTopPadding: CGFloat
    let checkmarkFont: Font
    let flagFont: Font
    let flagTopPadding: CGFloat
}

extension DensityMetrics {
    /// Default — matches the pre-density row exactly.
    static let comfortable = DensityMetrics(
        rowVPadding: 14, rowHPadding: 14, rowCorner: 14, hstackSpacing: 12,
        titleLineLimit: 2, titleLineSpacing: 2, titleToMeta: 4,
        metaTopPadding: 1, metaHstackSpacing: 10,
        metaFont: .system(size: 13),
        projectDotSize: 7, projectBadgeSpacing: 5,
        dueBadgeSpacing: 4, dueIconFont: .system(size: 12, weight: .medium),
        checkboxSize: 20, checkboxTopPadding: 2,
        checkmarkFont: .system(size: 11, weight: .bold),
        flagFont: .system(size: 13, weight: .semibold),
        flagTopPadding: 3
    )

    /// Todoist "compact" mode — 1-line title, smaller meta, tighter padding.
    static let compact = DensityMetrics(
        rowVPadding: 8, rowHPadding: 10, rowCorner: 12, hstackSpacing: 10,
        titleLineLimit: 1, titleLineSpacing: 1, titleToMeta: 2,
        metaTopPadding: 0, metaHstackSpacing: 8,
        metaFont: .system(size: 12),
        projectDotSize: 6, projectBadgeSpacing: 4,
        dueBadgeSpacing: 3, dueIconFont: .system(size: 11, weight: .medium),
        checkboxSize: 18, checkboxTopPadding: 1,
        checkmarkFont: .system(size: 10, weight: .bold),
        flagFont: .system(size: 12, weight: .semibold),
        flagTopPadding: 2
    )
}