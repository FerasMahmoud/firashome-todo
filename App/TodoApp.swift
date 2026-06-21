import SwiftUI
import SwiftData

@main
struct TodoApp: App {
    let container: ModelContainer
    @AppStorage("onboarded") private var onboarded = false

    /// When true, the app shows a lock overlay until `BiometricLock.shared`
    /// reports `isLocked == false`. Source of truth lives here in `TodoApp`;
    /// `SettingsView` writes it through its biometric toggle and mirrors it
    /// into the singleton via `BiometricLock.shared.enable()` / `disable()`.
    @AppStorage("biometricLock") private var biometricLock = false

    /// Observed so the overlay appears / disappears the moment the singleton
    /// flips `isLocked` (after a successful `authenticate()` call).
    @ObservedObject private var bioLock = BiometricLock.shared

    /// Drives the auto-lock-on-background behaviour. `.background` is the only
    /// phase we react to — `.inactive` fires every time Control Center is
    /// pulled down, which would be over-aggressive.
    @Environment(\.scenePhase) private var scenePhase

    /// Theme + density observation lets the gate view animate the cascade
    /// when the user toggles either from Settings.
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var density = DensityManager.shared

    init() {
        let schema = Schema([TodoTask.self, Project.self, Label.self, Subtask.self, SavedFilter.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback: in-memory so the app never hard-crashes on a bad store.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }

        // Seed demo data for screenshots / first launch.
        if CommandLine.arguments.contains("--seed-demo") || ProcessInfo.processInfo.arguments.contains("--seed-demo") {
            Seed.wipeAndSeed(context: container.mainContext)
        } else {
            Seed.seedIfEmpty(context: container.mainContext)
        }

        // Notification permission is requested AFTER onboarding completes
        // (see `OnboardingView.task(id: onboarded)`). Asking at launch would
        // pop the system prompt before the user knows what the app does,
        // so we defer until the tour is done.
    }

    var body: some Scene {
        WindowGroup {
            gatedContent
                .environmentObject(AuthManager())
                .onChange(of: scenePhase) { _, newPhase in
                    // Re-engage the lock every time the user leaves the app.
                    // `BiometricLock.lock()` is a no-op when the feature is
                    // disabled, so this is safe even with the toggle off.
                    if newPhase == .background {
                        BiometricLock.shared.lock()
                    }
                }
        }
        .modelContainer(container)
    }

    /// Onboarding → lock overlay → main app. The lock overlay carries a
    /// spring transition (opacity + scale) so the gate feels deliberate
    /// rather than abrupt.
    @ViewBuilder
    private var gatedContent: some View {
        Group {
            if !onboarded {
                OnboardingView()
            } else if biometricLock && bioLock.isLocked {
                LockOverlayView()
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
            } else {
                RootView()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: bioLock.isLocked)
        // Cascade theme / density changes through the scene so the colours
        // and metrics slide instead of jumping.
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: theme.raw)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: density.mode.rawValue)
    }
}

// MARK: - Lock overlay

/// Full-screen view shown when `AppStorage("biometricLock")` is on and the
/// `BiometricLock` singleton reports `isLocked == true`. Calls
/// `BiometricLock.shared.authenticate()` on appear, then again on every
/// `Unlock` tap if the system prompt was cancelled or failed.
///
/// Reads `availability.biometryType` to swap the SF Symbol between Face ID,
/// Touch ID, and Optic ID — pure presentation, no biometric logic here.
struct LockOverlayView: View {
    @ObservedObject private var bioLock = BiometricLock.shared
    @State private var errorMessage: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            TK.canvas.ignoresSafeArea()

            VStack(spacing: 22) {
                Image(systemName: lockIcon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(TK.accent)
                    .symbolEffect(.pulse, options: .repeat(.continuous))
                    .accessibilityHidden(true)

                Text("Locked")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TK.ink)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(TK.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                }

                Button {
                    Task { await authenticate() }
                } label: {
                    Text(isAuthenticating ? "Authenticating…" : "Unlock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TK.canvas)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(TK.accent)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .accessibilityIdentifier("lock-overlay-unlock")
            }
            .padding(40)
        }
        .task {
            await authenticate()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: errorMessage)
    }

    /// Resolves the per-biometry SF Symbol — falls back to a generic lock
    /// when the device hasn't reported its kind yet.
    private var lockIcon: String {
        guard let type = bioLock.availability.biometryType else { return "lock.fill" }
        switch type {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default:       return "lock.fill"
        }
    }

    /// Prompts the system biometric sheet. Success clears the lock and the
    /// parent gate swaps in `RootView`; failure shows the localised error
    /// under the icon so the user can decide between retrying and
    /// disabling the lock from iOS Settings.
    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await bioLock.authenticate()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}