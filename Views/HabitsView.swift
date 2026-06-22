import SwiftUI
import SwiftData

/// Habits screen (Life OS). Glass-card rows with colored SF Symbol icon,
/// name, a 7-day done-dot row, streak (flame), and a today-check circle.
/// Tap toggles today. Same TK design system as the rest of the app.
/// SF Symbols only (no emojis).
struct HabitsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    private var doneToday: Int { habits.filter { $0.isDoneToday }.count }

    var body: some View {
        NavigationStack {
            List {
                if !habits.isEmpty {
                    Section {
                        ProgressRing(done: doneToday, total: habits.count)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        ForEach(habits) { habit in
                            habitRow(habit)
                                .onTapGesture {
                                    habit.toggleToday()
                                    try? context.save()
                                }
                        }
                    } header: {
                        Text("Daily")
                    }
                } else {
                    Section {
                        Text("No habits yet. Tap + to add one.")
                            .foregroundStyle(TK.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TK.canvas)
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showingAdd) { AddHabitSheet() }
        }
    }

    @ViewBuilder
    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            // Colored icon
            Image(systemName: habit.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: habit.colorHex))
                .frame(width: 34, height: 34)
                .background(TK.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)

                // 7-day dot row
                HStack(spacing: 5) {
                    ForEach(habit.weekStatus, id: \.date) { entry in
                        Circle()
                            .fill(entry.done ? TK.accent : TK.hairlineSoft)
                            .frame(width: 10, height: 10)
                    }
                }

                Text("\(habit.currentStreak)-day streak")
                    .font(.system(size: 11))
                    .foregroundStyle(TK.secondary)
            }

            Spacer()

            // Streak flame
            if habit.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                    Text("\(habit.currentStreak)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color(hex: "F99B17"))
            }

            // Today check circle
            Image(systemName: habit.isDoneToday ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 26))
                .foregroundStyle(habit.isDoneToday ? Color(hex: "1f9d5e") : TK.hairlineSoft)
        }
        .padding(.vertical, 4)
    }
}

/// Add-habit sheet: name + color picker. Matches the app's add-project pattern.
struct AddHabitSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = "1B8B6A"

    private let colors: [(String, String)] = [
        ("DC4C4E", "Red"), ("9C27B0", "Berry"), ("F99B17", "Orange"),
        ("1B8B6A", "Green"), ("246FE0", "Blue"), ("8E8E93", "Grey")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Meditate", text: $name)
                }
                Section("Color") {
                    HStack {
                        ForEach(colors, id: \.0) { c in
                            Circle()
                                .fill(Color(hex: c.0))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(.white, lineWidth: colorHex == c.0 ? 3 : 0))
                                .onTapGesture { colorHex = c.0 }
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        context.insert(Habit(name: trimmed, colorHex: colorHex))
                        dismiss()
                    }
                }
            }
        }
    }
}
