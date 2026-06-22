import SwiftUI
import SwiftData

/// Routine Board (Life OS). Kanban columns: Morning / Afternoon / Evening.
/// Each habit card shows today's completion; tap to toggle. Tap the arrow
/// to move the habit to the next time slot. Same TK design. SF Symbols only.
struct RoutineBoardView: View {
    @Query private var habits: [Habit]
    @Environment(\.modelContext) private var context

    private let slots = ["morning", "afternoon", "evening"]

    private var doneToday: Int { habits.filter { $0.isDoneToday }.count }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(slots, id: \.self) { slot in
                        columnView(slot)
                            .frame(width: 240)
                    }
                }
                .padding(14)
            }
            .scrollContentBackground(.hidden)
            .background(TK.canvas)
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func columnView(_ slot: String) -> some View {
        let ch = habits.filter { ($0.timeOfDay.isEmpty ? "morning" : $0.timeOfDay) == slot }
        let done = ch.filter { $0.isDoneToday }.count

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.capitalized)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TK.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(done)/\(ch.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TK.secondary)
            }

            ForEach(ch) { h in
                habitCard(h)
            }
            if ch.isEmpty {
                Text("No habits")
                    .font(.system(size: 12))
                    .foregroundStyle(TK.secondary)
                    .italic()
                    .padding(.top, 6)
            }
        }
        .padding(12)
        .background(TK.card)
        .clipShape(RoundedRectangle(cornerRadius: TK.rCard))
    }

    @ViewBuilder
    private func habitCard(_ h: Habit) -> some View {
        let idx = slots.firstIndex(of: h.timeOfDay.isEmpty ? "morning" : h.timeOfDay) ?? 0
        HStack(spacing: 9) {
            Image(systemName: h.icon)
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: h.colorHex))
                .frame(width: 28, height: 28)
                .background(TK.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(h.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(h.isDoneToday ? TK.secondary : TK.ink)
                .strikethrough(h.isDoneToday)
                .lineLimit(2)

            Spacer()

            Image(systemName: h.isDoneToday ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(h.isDoneToday ? Color(hex: "1f9d5e") : TK.hairlineSoft)

            Button {
                let next = slots[(idx + 1) % 3]
                h.timeOfDay = next
                try? context.save()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(TK.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(TK.grouped.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(hex: h.colorHex)).frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .onTapGesture {
            h.toggleToday()
            try? context.save()
        }
        .opacity(h.isDoneToday ? 0.6 : 1)
    }
}
