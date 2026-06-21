import SwiftUI

/// First-launch walkthrough — a 3-page paged intro shown by `TodoApp` until
/// the user taps Continue on the last page. Writes `onboarded` to
/// `UserDefaults`; once set, `TodoApp` re-renders into `RootView()` and
/// onboarding never reappears.
///
/// ponytail: ceiling — if we ever need programmatic re-entry ("Show tour
/// again" from Settings), route through a small `OnboardingCoordinator`
/// instead of swapping the root view from here.
struct OnboardingView: View {
    @AppStorage("onboarded") private var onboarded = false
    @State private var page: Int = 0

    private let pageCount = 3

    var body: some View {
        TabView(selection: $page) {
            page(
                icon: "checkmark.circle.fill",
                tint: TK.accent,
                title: "Welcome",
                body: "A focused way to capture what matters."
            )
            .tag(0)

            page(
                icon: "calendar",
                tint: TK.priority(3),
                title: "Organize your day",
                body: "Today, upcoming, and projects — all at a glance."
            )
            .tag(1)

            page(
                icon: "sparkles",
                tint: TK.ink,
                title: "Get started",
                body: "Tap + to add your first task."
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .safeAreaInset(edge: .bottom) {
            // Primary CTA — advances on early pages, finishes on last.
            Button {
                if page < pageCount - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page += 1
                    }
                } else {
                    onboarded = true
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TK.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background { if TK.isDarkGlass { Color.clear } else { TK.canvas } }
            .accessibilityIdentifier("onboarding-continue")
            .accessibilityLabel("Continue")
        }
        .task(id: onboarded) {
            // Ask for notification permission only after the user finishes
            // onboarding. Popping the system prompt before they know what
            // the app does is bad UX — the gate in `TodoApp` already defers
            // first-launch work to here.
            if onboarded {
                NotificationManager.shared.requestPermissionIfNeeded()
            }
        }
    }

    // MARK: - Page

    /// One onboarding page: hero icon, title, body copy. Reserves space at
    /// the bottom so content doesn't sit under the page dots / CTA.
    @ViewBuilder
    private func page(icon: String,
                      tint: Color,
                      title: String,
                      body: String) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.system(size: 84, weight: .regular))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(TK.ink)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(TK.body)
                    .foregroundStyle(TK.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
            // Reserve space so content doesn't sit under the page dots / CTA.
            Color.clear.frame(height: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
    }
}

#Preview {
    OnboardingView()
}
