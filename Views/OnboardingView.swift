import SwiftUI

/// First-launch walkthrough — a 4-page paged intro shown by `TodoApp` until
/// the user finishes or skips. Writes `hasOnboarded` to `UserDefaults`; once
/// set, `TodoApp` re-renders into `RootView()` and onboarding never reappears.
///
/// ponytail: ceiling — if we ever need programmatic re-entry ("Show tour
/// again" from Settings), route through a small `OnboardingCoordinator`
/// instead of swapping the root view from here.
struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var page: Int = 0

    private let pageCount = 4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Paged content sits behind the skip / continue overlays.
            TabView(selection: $page) {
                page(
                    icon: "checkmark.circle.fill",
                    tint: TK.accent,
                    title: "Welcome to Tasks",
                    body: "A focused way to capture what matters."
                )
                .tag(0)

                page(
                    icon: "tray.fill",
                    tint: Color(hex: "246FE0"),
                    title: "Inbox & projects",
                    body: "The Inbox catches everything. Projects give tasks a home."
                )
                .tag(1)

                page(
                    icon: "sun.max.fill",
                    tint: TK.priority(3),
                    title: "Today & upcoming",
                    body: "Plan your day. See what's coming next."
                )
                .tag(2)

                page(
                    icon: "sparkles",
                    tint: TK.ink,
                    title: "You're all set",
                    body: "Add your first task from the + bar at the bottom."
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }

            // Skip — always visible, top trailing.
            Button {
                hasOnboarded = true
            } label: {
                Text("Skip")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .padding(.top, 12)
            .padding(.trailing, 8)
            .accessibilityIdentifier("onboarding-skip")
            .accessibilityLabel("Skip onboarding")
        }
        .safeAreaInset(edge: .bottom) {
            // Primary CTA — last page reads "Get started" instead of "Continue".
            Button {
                if page < pageCount - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page += 1
                    }
                } else {
                    hasOnboarded = true
                    // Best-effort: prompt for notifications now that the user
                    // has finished onboarding. No-op / silent if denied.
                    NotificationManager.shared.requestPermissionIfNeeded()
                }
            } label: {
                Text(page < pageCount - 1 ? "Continue" : "Get started")
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
            .accessibilityLabel(page < pageCount - 1 ? "Continue" : "Get started")
        }
    }

    // MARK: - Page

    /// One onboarding page: hero icon, title, body copy. Padded to leave room
    /// for the system page indicator and the bottom CTA.
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
    }
}
