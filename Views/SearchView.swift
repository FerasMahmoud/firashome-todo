import SwiftUI
import SwiftData

/// Global search across every task (open + completed) — matches against the
/// task's title and note (case- and diacritic-insensitive via
/// `localizedStandardContains`). Results are ranked: title matches first, then
/// note matches; open tasks before completed; earlier `order` breaks ties.
///
/// Reached from the sidebar's "Search" row. Renders a SwiftUI `.searchable`
/// bar in the navigation chrome; when the query is empty, shows a small
/// instruction state instead of the full task list.
struct SearchView: View {
    /// Every task in the store (open + completed). We filter in memory
    /// because the predicate macro can't compose `localizedStandardContains`
    /// (Foundation-only) and the candidate set is small.
    @Query(sort: \TodoTask.order) private var allTasks: [TodoTask]

    @State private var query: String = ""

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                promptState
            } else {
                resultsList
            }
        }
        .background(TK.canvas)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search tasks"
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }

    // MARK: - States

    private var promptState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("Search across all tasks")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Find by title or note. Both open and completed tasks are searched.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search-prompt")
    }

    private var resultsList: some View {
        let results = matchingTasks(query: query)
        return Group {
            if results.isEmpty {
                noResultsState
            } else {
                List {
                    Section {
                        ForEach(results) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
                                TaskRowView(task: task)
                            }
                            .accessibilityIdentifier("search-result-\(task.id.uuidString.prefix(8))")
                        }
                    } header: {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                            .font(TK.sectionHeader)
                            .foregroundStyle(TK.secondary)
                            .textCase(nil)
                            .accessibilityIdentifier("search-results-count")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowSeparator(.hidden)
                .background(TK.canvas)
            }
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No matches for \u{201C}\(query)\u{201D}")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
                .multilineTextAlignment(.center)
            Text("Try a shorter or different word.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search-no-results")
    }

    // MARK: - Filter

    /// Returns tasks whose title or note contains `query` (case + diacritic
    /// insensitive), ranked by relevance:
    /// 1. Title hits outrank note-only hits.
    /// 2. Open tasks outrank completed tasks.
    /// 3. Earlier `order` wins.
    private func matchingTasks(query: String) -> [TodoTask] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return allTasks
            .compactMap { task -> (TodoTask, Int)? in
                let titleHit = task.title.localizedStandardContains(needle)
                let noteHit = !titleHit && task.note.localizedStandardContains(needle)
                guard titleHit || noteHit else { return nil }
                // Lower score = higher rank. titleHit=0, noteHit=1; add 2 if completed.
                var score = titleHit ? 0 : 1
                if task.isCompleted { score += 2 }
                return (task, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.order < rhs.0.order
            }
            .map { $0.0 }
    }
}
