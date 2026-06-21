import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// App preferences. Surfaces controls that were previously scattered or
/// unreachable: theme (also in `AccountView`), row density (only this screen
/// exposes it), notifications authorization, alternate app icon, and a set
/// of opt-in defaults the rest of the app can read from `UserDefaults`.
///
/// The default-project / priority / due preferences are written here but
/// not yet read by `QuickAddView` — that wire-up is a follow-up since
/// `QuickAddView` is not in the owned file set. Ponytail: don't pretend a
/// wire-up that doesn't exist.
struct SettingsView: View {
    // Pulled through managers so toggles stay in sync with the rest of the app.
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var density = DensityManager.shared

    @AppStorage("showCompleted") private var showCompleted = false
    @AppStorage("confirmDelete") private var confirmDelete = true
    @AppStorage("weekStart") private var weekStartRaw: Int = 1   // 1 = Sunday, 2 = Monday
    @AppStorage("defaultPriority") private var defaultPriority: Int = 4
    @AppStorage("defaultDue") private var defaultDueRaw: String = DefaultDue.none.rawValue
    @AppStorage("defaultProjectID") private var defaultProjectIDRaw: String = ""
    /// Persisted app-icon pick. Defaults to `primary`; the alternate
    /// `AppIcon-Dark` / `AppIcon-Color` entries land in the asset catalog later.
    @AppStorage("appIcon") private var appIconRaw: String = AppIconOption.primary.id

    @State private var pickingDefaultProject = false
    @State private var pickingAppIcon = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @Query(sort: \Project.order) private var projects: [Project]

    var body: some View {
        Form {
            appearanceSection
            notificationsSection
            appIconSection
            tasksSection
            generalSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background { if TK.isDarkGlass { PlanetLayer() } else { TK.canvas } }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("settings-screen")
        .task { await refreshNotificationStatus() }
        .sheet(isPresented: $pickingDefaultProject) {
            defaultProjectPicker
        }
        .sheet(isPresented: $pickingAppIcon) {
            appIconPicker
        }
    }

    // MARK: - Sections

    /// Theme + density. Theme binds directly to the manager; density is a
    /// computed binding so the segmented control reflects the live value.
    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $theme.raw) {
                ForEach(AppTheme.allCases, id: \.rawValue) { t in
                    Text(t.label).tag(t.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-theme")

            Picker("Row density", selection: densityBinding) {
                ForEach(DensityMode.allCases, id: \.rawValue) { m in
                    Text(m.label).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-density")
        }
    }

    /// Notifications authorization. The system status is read directly from
    /// `UNUserNotificationCenter` so the row always reflects reality; the
    /// actual `requestAuthorization` call lives behind a `#if` guard until
    /// `Services/Notifications.swift` lands (owned by another task).
    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            LabeledContent("Status") {
                Text(notificationStatus.label)
                    .foregroundStyle(TK.secondary)
            }
            .accessibilityIdentifier("settings-notification-status")

            #if false
            // Flip to `#if true` when Services/Notifications.swift lands. The
            // button is intentionally inert until then — calling into a type
            // that doesn't exist would fail to compile.
            Button("Allow notifications") {
                Task {
                    await AppNotifications.requestAuthorization()
                    await refreshNotificationStatus()
                }
            }
            .disabled(notificationStatus == .authorized || notificationStatus == .provisional)
            .accessibilityIdentifier("settings-allow-notifications")
            #endif
        }
    }

    /// Alternate app-icon picker. `UIApplication.supportsAlternateIcons`
    /// returns false until `CFBundleIcons` is declared in `Info.plist` and
    /// the alt-icon assets are in the bundle — the row degrades gracefully
    /// when no alt icons are configured.
    @ViewBuilder
    private var appIconSection: some View {
        Section("App Icon") {
            Button {
                pickingAppIcon = true
            } label: {
                HStack {
                    Text("Icon")
                        .foregroundStyle(TK.ink)
                    Spacer(minLength: 8)
                    Text(currentAppIconName)
                        .foregroundStyle(TK.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                        .opacity(0.6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!UIApplication.shared.supportsAlternateIcons)
            .accessibilityIdentifier("settings-app-icon")
            .accessibilityLabel("App icon, currently \(currentAppIconName)")

            if !UIApplication.shared.supportsAlternateIcons {
                Text("No alternate icons are bundled with this build.")
                    .font(.footnote)
                    .foregroundStyle(TK.secondary)
            }
        }
    }

    /// Default quick-add values. The picker rows write to `UserDefaults`;
    /// nothing else in the app reads them yet.
    @ViewBuilder
    private var tasksSection: some View {
        Section("Tasks") {
            Button {
                pickingDefaultProject = true
            } label: {
                HStack {
                    Text("Default project")
                        .foregroundStyle(TK.ink)
                    Spacer(minLength: 8)
                    Text(defaultProjectName)
                        .foregroundStyle(TK.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                        .opacity(0.6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-default-project")
            .accessibilityLabel("Default project, currently \(defaultProjectName)")

            Picker("Default priority", selection: $defaultPriority) {
                Text("P1").tag(1)
                Text("P2").tag(2)
                Text("P3").tag(3)
                Text("P4").tag(4)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-default-priority")

            Picker("Default due date", selection: $defaultDueRaw) {
                ForEach(DefaultDue.allCases, id: \.rawValue) { d in
                    Text(d.label).tag(d.rawValue)
                }
            }
            .accessibilityIdentifier("settings-default-due")
        }
    }

    /// Toggles that are stored but not yet read by the rest of the app —
    /// they're honest controls the next iteration of `TaskRowView` and
    /// `Repository.delete` can opt into.
    @ViewBuilder
    private var generalSection: some View {
        Section("General") {
            Toggle("Show completed in lists", isOn: $showCompleted)
                .accessibilityIdentifier("settings-show-completed")

            Toggle("Confirm before delete", isOn: $confirmDelete)
                .accessibilityIdentifier("settings-confirm-delete")

            Picker("Week starts on", selection: $weekStartRaw) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
            }
            .accessibilityIdentifier("settings-week-start")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
                .accessibilityIdentifier("settings-version")

            Link(destination: URL(string: "https://firashome.uk")!) {
                HStack {
                    Text("Firashome")
                        .foregroundStyle(TK.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(TK.secondary)
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("settings-firashome")
        }
    }

    // MARK: - Default project picker

    /// Sheet that lists every project + a "None" row. Picking writes the
    /// project's UUID to `defaultProjectID`; "None" clears it.
    @ViewBuilder
    private var defaultProjectPicker: some View {
        NavigationStack {
            List {
                Button {
                    defaultProjectIDRaw = ""
                    pickingDefaultProject = false
                } label: {
                    HStack {
                        Text("None")
                            .foregroundStyle(TK.ink)
                        Spacer(minLength: 8)
                        if defaultProjectIDRaw.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(TK.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ForEach(projects) { project in
                    Button {
                        defaultProjectIDRaw = project.id.uuidString
                        pickingDefaultProject = false
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(project.color)
                                .frame(width: 12, height: 12)
                            Text(project.name)
                                .foregroundStyle(TK.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if defaultProjectIDRaw == project.id.uuidString {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(TK.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Default project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { pickingDefaultProject = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - App-icon picker

    /// Lists the primary icon + every declared alternate. Tapping a row
    /// calls `setAlternateIconName`; the system handles the home-screen
    /// transition animation. Only reachable when the bundle declares alt
    /// icons in `CFBundleIcons` (see `appIconSection`).
    @ViewBuilder
    private var appIconPicker: some View {
        NavigationStack {
            List {
                ForEach(AppIconOption.all) { option in
                    Button {
                        setAppIcon(option.name)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(TK.ink)
                                .frame(width: 22)
                            Text(option.label)
                                .foregroundStyle(TK.ink)
                            Spacer(minLength: 8)
                            if currentIconKey == option.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(TK.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("App Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { pickingAppIcon = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Bindings & derived values

    /// Density is stored as an Int in `UserDefaults`; this binding round-trips
    /// through the manager so the segmented control reads / writes the same
    /// source of truth `TaskRowView` observes.
    private var densityBinding: Binding<Int> {
        Binding(
            get: { density.mode.rawValue },
            set: { density.mode = DensityMode(rawValue: $0) ?? .comfortable }
        )
    }

    /// Resolved name for the currently selected default project, or "None".
    private var defaultProjectName: String {
        guard let uuid = UUID(uuidString: defaultProjectIDRaw) else { return "None" }
        return projects.first(where: { $0.id == uuid })?.name ?? "None"
    }

    /// `CFBundleShortVersionString` · build number. Empty string when the
    /// key isn't present (e.g. UITest target).
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? "—"
        return "\(v) · \(b)"
    }

    // MARK: - Notifications helpers

    /// Pull the live authorization status so the row reflects what the
    /// system shows in Settings.app. Read on appear and after every
    /// `requestAuthorization` round-trip.
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    // MARK: - App-icon helpers

    /// Stable id for the icon currently in use. Source of truth is
    /// `@AppStorage("appIcon")` — we mirror it to iOS via `setAlternateIconName`
    /// but read back from `UserDefaults` so the picker matches what was picked
    /// even if iOS hasn't finished swapping the home-screen badge yet.
    private var currentIconKey: String {
        appIconRaw
    }

    /// User-facing label for the currently selected icon.
    private var currentAppIconName: String {
        AppIconOption.all.first(where: { $0.id == currentIconKey })?.label ?? AppIconOption.primary.label
    }

    /// Apply the chosen alternate icon. Writes the pick to `appIconRaw`
    /// first so the UI stays in sync, then forwards to iOS. The completion
    /// handler is left at its default (`nil`) — the only failure mode is
    /// "icon name not in Info.plist", which we control, and `simulator`
    /// never advertises support so the guard short-circuits cleanly.
    private func setAppIcon(_ name: String?) {
        appIconRaw = name ?? AppIconOption.primary.id
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(name)
    }
}

// MARK: - Default due

/// Stored as a raw string under `defaultDue`. The QuickAdd read-side is
/// out of scope; this enum is the contract the follow-up will use.
private enum DefaultDue: String, CaseIterable, Identifiable {
    case none
    case today
    case tomorrow
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none:     "None"
        case .today:    "Today"
        case .tomorrow: "Tomorrow"
        }
    }
}

// MARK: - Notifications status

private extension UNAuthorizationStatus {
    /// Short user-facing label for the row in Settings.
    var label: String {
        switch self {
        case .notDetermined: "Not requested"
        case .denied:        "Turned off in Settings"
        case .authorized:    "Allowed"
        case .provisional:   "Provisional"
        case .ephemeral:     "Ephemeral"
        @unknown default:    "Unknown"
        }
    }
}

// MARK: - App icon options

/// Catalog of icons the user can pick. The primary icon has no name
/// (`setAlternateIconName(nil)`); alternates carry the name declared in
/// `CFBundleIcons.CFBundleAlternateIcons`. Extend `alternates` once alt
/// icons are added to the asset catalog and Info.plist.
private struct AppIconOption: Identifiable {
    let id: String           // matches `UIApplication.alternateIconName` or "primary"
    let label: String        // shown in the picker
    let symbol: String       // SF Symbol used in the row
    let name: String?        // value passed to `setAlternateIconName`

    static let primary = AppIconOption(
        id: "primary",
        label: "Default",
        symbol: "app",
        name: nil
    )

    /// ponytail: ceiling — when more alt icons ship, add one entry here per icon.
    /// The picker auto-renders whatever's in this list; nothing else moves.
    /// The `AppIcon-Dark` / `AppIcon-Color` assets land in a follow-up Xcode task —
    /// `setAlternateIconName` already routes by these names.
    static let alternates: [AppIconOption] = [
        AppIconOption(id: "AppIcon-Dark",  label: "Dark",  symbol: "moon.fill",         name: "AppIcon-Dark"),
        AppIconOption(id: "AppIcon-Color", label: "Color", symbol: "paintpalette.fill", name: "AppIcon-Color"),
    ]

    static var all: [AppIconOption] { [primary] + alternates }
}
