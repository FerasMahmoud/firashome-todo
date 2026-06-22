import Foundation
import LocalAuthentication
import SwiftUI

/// Manages Face ID / Touch ID / Optic ID lock for the app's private content.
///
/// Singleton (`BiometricLock.shared`) — the lock state is process-global, not
/// per-view, so it survives view re-creation and `@EnvironmentObject` rebuilds.
///
/// Wiring expectations (intentionally NOT done in this file — see READ-ONLY note):
///   1. `Info.plist` MUST contain `NSFaceIDUsageDescription`. Touch ID / Optic ID
///      do not strictly need it, but the OS hard-crashes on the first
///      `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` call for
///      Face ID if the key is missing. A short string like "Unlock your tasks"
///      is enough.
///   2. `project.yml` must list `Services` under the `Todo` target's `sources`
///      so XcodeGen picks the file up on the next `refresh.sh` run.
///   3. From `RootView`, observe `\.scenePhase` and call `lock()` on
///      `.background` / `.inactive`; render a full-screen lock overlay while
///      `isLocked && isEnabled`; on tap, `await authenticate()`.
///
/// Persistence:
///   - The user's opt-in (`isEnabled`) is stored via `@AppStorage` under the
///     key `biometric_lock_enabled`. Lightweight, per-device, no Keychain —
///     the lock is a UX gate, not a secret boundary (the store is already
///     protected by the iOS data-protection class set in the entitlements).
///   - Hardware availability is re-queried every time `refreshAvailability()`
///     is called, so enrolment changes in iOS Settings take effect on the
///     next foreground transition without a relaunch.
@MainActor
final class BiometricLock: ObservableObject {
    static let shared = BiometricLock()

    // MARK: - Published state

    /// User opt-in. Persisted. When false, `isLocked` is forced to false and
    /// `authenticate()` short-circuits to success.
    @AppStorage("biometric_lock_enabled") var isEnabled: Bool = false

    /// True whenever the app should be hidden behind the lock overlay.
    /// Set by `lock()` (e.g. on scene-becomes-inactive) and cleared by a
    /// successful `authenticate()`.
    @Published private(set) var isLocked: Bool = true

    /// Hardware + enrolment state. Cached — call `refreshAvailability()` to
    /// re-query (do this on foreground and before toggling `isEnabled`).
    @Published private(set) var availability: Availability = .unknown

    // MARK: - Types

    enum Availability: Equatable {
        case unknown
        case available(LABiometryType)
        case notEnrolled
        case notAvailable(String)

        /// The concrete biometry kind, if any. Convenient for UI that wants to
        /// show a per-kind icon or label without pattern-matching twice.
        var biometryType: LABiometryType? {
            if case .available(let t) = self { return t } else { return nil }
        }

        /// Short, user-visible reason string for Settings rows / alerts.
        var label: String {
            switch self {
            case .unknown:                  return "Checking…"
            case .available(let t):         return BiometricLock.displayName(for: t)
            case .notEnrolled:              return "Set up in iOS Settings"
            case .notAvailable(let reason): return reason
            }
        }

        /// True iff the device can actually run a biometric prompt right now.
        var canEvaluate: Bool {
            if case .available = self { return true } else { return false }
        }
    }

    /// User-facing failure modes from `authenticate()`. Mapped from `LAError`
    /// so call-sites get clean switch coverage without importing the LA layer.
    enum LockError: LocalizedError {
        case notAvailable(String)
        case cancelled
        case denied
        case lockedOut
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable(let r): return r
            case .cancelled:           return "Authentication cancelled."
            case .denied:              return "Authentication failed."
            case .lockedOut:           return "Too many failed attempts. Use your device passcode, then try again."
            case .failed(let m):       return m
            }
        }
    }

    // MARK: - Init

    private init() {
        refreshAvailability()
    }

    // MARK: - Public API

    /// Re-query hardware + enrolment state. Cheap — just an `LAContext`
    /// capability probe. Safe to call on every scene-becomes-active.
    func refreshAvailability() {
        let ctx = LAContext()
        var probeError: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &probeError) {
            availability = .available(ctx.biometryType)
            return
        }
        guard let laErr = probeError as? LAError else {
            availability = .notAvailable(probeError?.localizedDescription ?? "Biometrics unavailable")
            return
        }
        switch laErr.code {
        case .biometryNotEnrolled:
            availability = .notEnrolled
        case .biometryNotAvailable, .passcodeNotSet:
            availability = .notAvailable(laErr.localizedDescription)
        default:
            availability = .notAvailable(laErr.localizedDescription)
        }
    }

    /// Turn the lock on. Throws if the device can't actually evaluate
    /// biometrics — caller should disable the toggle in that case rather
    /// than pretending the lock is armed.
    @discardableResult
    func enable() throws -> Bool {
        refreshAvailability()
        guard availability.canEvaluate else {
            throw LockError.notAvailable(availability.label)
        }
        isEnabled = true
        // Freshly enabling implies a fresh lock — never inherit stale unlock.
        isLocked = true
        return true
    }

    func disable() {
        isEnabled = false
        isLocked = false
    }

    /// Re-lock immediately. No-op when the lock is disabled.
    func lock() {
        guard isEnabled else {
            isLocked = false
            return
        }
        isLocked = true
    }

    /// Prompt the system biometric sheet. On success, clears `isLocked`.
    ///
    /// Uses `.deviceOwnerAuthenticationWithBiometrics` (biometrics only) and
    /// intentionally blanks `localizedFallbackTitle` so the system does NOT
    /// offer a "Enter Passcode" escape hatch — passcode bypass would defeat
    /// the lock. A passcode-only fallback can be added in a future tier if
    /// the user explicitly opts in.
    ///
    /// Throws `LockError` on any failure; never returns `false`.
    @discardableResult
    func authenticate(reason: String = "Unlock Tasks") async throws -> Bool {
        guard isEnabled else {
            // Lock isn't armed — auth is a no-op success.
            isLocked = false
            return true
        }
        refreshAvailability()
        guard availability.canEvaluate else {
            throw LockError.notAvailable(availability.label)
        }

        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""

        do {
            let ok = try await ctx.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            isLocked = !ok
            return ok
        } catch let laErr as LAError {
            throw Self.map(laErr)
        } catch {
            throw LockError.failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private static func map(_ err: LAError) -> LockError {
        switch err.code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return .cancelled
        case .biometryLockout:
            return .lockedOut
        case .authenticationFailed:
            return .denied
        default:
            return .failed(err.localizedDescription)
        }
    }

    nonisolated private static func displayName(for type: LABiometryType) -> String {
        switch type {
        case .faceID:        return "Face ID"
        case .touchID:       return "Touch ID"
        case .opticID:       return "Optic ID"
        case .none:          return "Biometrics"
        @unknown default:    return "Biometrics"
        }
    }
}