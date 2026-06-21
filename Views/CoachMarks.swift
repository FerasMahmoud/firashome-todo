import SwiftUI
import TipKit

/// Tier-2 coach marks — TipKit-driven onboarding overlay that walks the
/// user through the three core flows (add task, swipe, quick add). Each
/// `Tip` is its own struct so its presentation + dismissal state is held
/// independently by TipKit's `Tips` datastore and survives across launches.
///
/// ponytail: ceiling — if the tour grows past ~5 tips, swap the manual
/// `step` paging here for a `TipKit.Tips.Configuration` + `.tipKit`-driven
/// orchestrated flow. Three tips and a manual pager is the simplest thing
/// that meets the brief.

// MARK: - Tip definitions
//
// Each tip conforms to `Tip` (iOS 17+). `title` and `message` drive the
// `TipView` body; `image` supplies the SF Symbol shown beside the title.

struct AddTaskTip: Tip {
    var title: Text { Text("Add a task") }
    var message: Text? {
        Text("Tap the + bar at the bottom of any list to create a task in this project.")
    }
    var image: Image? { Image(systemName: "plus.circle.fill") }
}

struct SwipeTip: Tip {
    var title: Text { Text("Swipe to act") }
    var message: Text? {
        Text("Swipe right to complete. Swipe left to schedule, move, or delete.")
    }
    var image: Image? { Image(systemName: "hand.draw.fill") }
}

struct QuickAddTip: Tip {
    var title: Text { Text("Quick add") }
    var message: Text? {
        Text("Press and hold the + bar to open Quick Add with natural-language parsing.")
    }
    var image: Image? { Image(systemName: "bolt.fill") }
}

// MARK: - Overlay

/// Three-step coach mark overlay. Shown on top of any host view, advances
/// step-by-step, and dismisses either by tapping the dim backdrop or by
/// finishing the last step. Each step renders its `Tip` through `TipView`
/// for the platform-native coaching-card styling.
struct CoachMarksView: View {
    /// Fired when the user finishes the tour or taps out. Caller is
    /// expected to flip its `isPresented` binding to `false`.
    let onFinish: () -> Void

    @State private var step: Int = 0

    /// Static catalog of tips walked in order. Held as `any Tip` so we can
    /// hand each one to `TipView` without per-step overloads.
    private static let tips: [any Tip] = [
        AddTaskTip(),
        SwipeTip(),
        QuickAddTip()
    ]

    var body: some View {
        // TipKit, `symbolEffect(value:)`, and `TipView` are iOS 17+. The
        // app's deployment target is 17.0 already, but the gate is here as
        // a safety net if this view is ever reused in a lower-target host.
        if #available(iOS 17.0, *) {
            overlay
                .transition(.opacity)
        } else {
            EmptyView()
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private var overlay: some View {
        ZStack {
            // Dim backdrop. Tapping anywhere outside the card finishes
            // the tour — the canonical "dismiss flow" escape hatch.
            TK.ink
                .opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.25)) {
                        onFinish()
                    }
                }

            VStack(spacing: 16) {
                if step < Self.tips.count {
                    TipView(Self.tips[step])
                        .padding(16)
                        .background(
                            TK.card,
                            in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                                .stroke(TK.hairlineSoft, lineWidth: 0.5)
                        )
                        .shadow(color: TK.ink.opacity(0.12), radius: 18, x: 0, y: 8)
                }

                controls
            }
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("coach-marks-overlay")
        .accessibilityAddTraits(.isModal)
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            // Page dots — accent for current step, faded secondary for the rest.
            HStack(spacing: 6) {
                ForEach(0..<Self.tips.count, id: \.self) { i in
                    Circle()
                        .fill(i == step ? TK.accent : TK.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)

            Spacer()

            // Spring-driven symbol effect: each tap on the button both
            // advances `step` and re-fires the bounce, which is itself a
            // spring animation on the SF Symbol.
            Button {
                advance()
            } label: {
                Image(systemName: step < Self.tips.count - 1
                      ? "arrow.right.circle.fill"
                      : "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(TK.accent)
                    .symbolEffect(.bounce, value: step)
                    .accessibilityLabel(step < Self.tips.count - 1 ? "Next" : "Done")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("coach-marks-next")
        }
        .padding(.horizontal, 4)
    }

    private func advance() {
        if step < Self.tips.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                step += 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                onFinish()
            }
        }
    }
}

// MARK: - Modifier

/// Attaches a coach mark overlay to the modified view. The overlay is
/// inserted while `isPresented` is `true` and removed when it flips back.
struct CoachMarksModifier: ViewModifier {
    let isPresented: Bool
    let onFinish: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                CoachMarksView(onFinish: onFinish)
            }
        }
        // Drives the `.transition(.opacity)` on `CoachMarksView.body`.
        .animation(.easeInOut(duration: 0.25), value: isPresented)
    }
}

extension View {
    /// Appends a `CoachMarksView` overlay on top of `self`. Pair with a
    /// `@State private var showTour = false` (or `@AppStorage`) and flip it
    /// from `onFinish` to dismiss.
    func coachMarks(
        isPresented: Bool,
        onFinish: @escaping () -> Void = {}
    ) -> some View {
        modifier(CoachMarksModifier(isPresented: isPresented, onFinish: onFinish))
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        VStack(spacing: 12) {
            Text("Behind the overlay")
                .font(TK.title)
                .foregroundStyle(TK.ink)
            Text("Coach marks: Add · Swipe · Quick add")
                .font(TK.body)
                .foregroundStyle(TK.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .coachMarks(isPresented: .constant(true))
    } else {
        Text("Coach marks require iOS 17+")
    }
}