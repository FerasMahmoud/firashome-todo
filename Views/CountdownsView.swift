import SwiftUI
import SwiftData

/// Countdowns screen (Life OS). Hero card with a big days-left number + ring
/// for the soonest event, then compact rows for the rest. Same TK design.
/// SF Symbols only (no emojis).
struct CountdownsView: View {
    @Query(sort: \CountdownEvent.targetDate) private var countdowns: [CountdownEvent]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    private var future: [CountdownEvent] { countdowns.filter { !$0.isPast } }
    private var past: [CountdownEvent] { countdowns.filter { $0.isPast } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Hero — soonest upcoming countdown
                    if let hero = future.first {
                        heroCard(hero)
                    }

                    // Remaining upcoming
                    if future.count > 1 {
                        VStack(spacing: 0) {
                            ForEach(future.dropFirst()) { c in
                                compactRow(c)
                                if c.id != future.last?.id { Divider() }
                            }
                        }
                        .background(TK.card)
                        .clipShape(RoundedRectangle(cornerRadius: TK.rCard))
                    }

                    // Past
                    if !past.isEmpty {
                        Text("Past")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(TK.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(past) { c in
                                compactRow(c, isPast: true)
                                if c.id != past.last?.id { Divider() }
                            }
                        }
                        .background(TK.card)
                        .clipShape(RoundedRectangle(cornerRadius: TK.rCard))
                    }

                    if countdowns.isEmpty {
                        Text("No countdowns yet. Tap + to add one.")
                            .foregroundStyle(TK.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
            .scrollContentBackground(.hidden)
            .background(TK.canvas)
            .navigationTitle("Countdowns")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add countdown")
                }
            }
            .sheet(isPresented: $showingAdd) { AddCountdownSheet() }
        }
    }

    @ViewBuilder
    private func heroCard(_ c: CountdownEvent) -> some View {
        let n = c.daysUntil
        let total = 90.0
        let progress = 1.0 - min(max(Double(n), 0), total) / total

        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(TK.hairlineSoft, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: c.colorHex), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
                Image(systemName: c.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: c.colorHex))
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(n)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(TK.ink)
                    .monospacedDigit()
                Text("day\(n == 1 ? "" : "s") to go")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                Text(c.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(TK.ink)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .padding(20)
        .background(TK.card)
        .clipShape(RoundedRectangle(cornerRadius: TK.rCard))
    }

    @ViewBuilder
    private func compactRow(_ c: CountdownEvent, isPast: Bool = false) -> some View {
        let n = abs(c.daysUntil)
        HStack(spacing: 12) {
            Image(systemName: c.icon)
                .font(.system(size: 17))
                .foregroundStyle(Color(hex: c.colorHex))
                .frame(width: 32, height: 32)
                .background(TK.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(c.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TK.ink)
                Text(c.targetDate, format: .dateTime.weekday().month().day().year())
                    .font(.system(size: 12))
                    .foregroundStyle(TK.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(n)")
                    .font(.system(size: 20, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(TK.ink)
                Text("days \(isPast ? "ago" : "left")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TK.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// Add-countdown sheet: title + date picker. SF Symbols only.
struct AddCountdownSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("e.g. Flight to Riyadh", text: $title)
                }
                Section("Date") {
                    DatePicker("Target", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        context.insert(CountdownEvent(title: trimmed, targetDate: date))
                        dismiss()
                    }
                }
            }
        }
    }
}
