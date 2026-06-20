import SwiftUI

/// Glassy "today progress" chip: a ring + "X / Y done".
struct ProgressRing: View {
    let done: Int
    let total: Int

    private var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(TK.hairlineSoft, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(TK.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TK.ink)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(done) of \(total) done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TK.ink)
                Text(total == 0 ? "Nothing due today" : (done == total ? "All clear 🎉" : "Keep going"))
                    .font(.system(size: 13))
                    .foregroundStyle(TK.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(cornerRadius: 20)
    }
}
