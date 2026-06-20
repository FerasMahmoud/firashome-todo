import Foundation
import SwiftUI
import SwiftData

/// Holds auth state + drives sync. Token/email/baseURL persist in @AppStorage.
final class AuthManager: ObservableObject {
    @AppStorage("api_base_url") var baseURL: String = SyncClient.defaultBaseURL
    @AppStorage("api_token") private var token: String?
    @AppStorage("api_email") var email: String?

    @Published var status: String = ""
    @Published var isBusy: Bool = false

    var isLoggedIn: Bool { token != nil }

    func login(email: String, password: String) async -> Bool {
        isBusy = true; defer { isBusy = false }
        do {
            let r = try await SyncClient(baseURL: baseURL).login(email: email, password: password)
            self.token = r.access_token; self.email = r.user.email
            status = "Signed in as \(r.user.email)"
            return true
        } catch { status = error.localizedDescription; return false }
    }

    func register(email: String, password: String, name: String) async -> Bool {
        isBusy = true; defer { isBusy = false }
        do {
            let r = try await SyncClient(baseURL: baseURL).register(email: email, password: password, name: name)
            self.token = r.access_token; self.email = r.user.email
            status = "Account created: \(r.user.email)"
            return true
        } catch { status = error.localizedDescription; return false }
    }

    func logout() { token = nil; email = nil; status = "" }

    /// Push all local tasks/projects/labels, then pull server state into the store.
    func syncNow(context: ModelContext) async {
        guard let token else { status = "Not signed in"; return }
        isBusy = true; defer { isBusy = false }
        let client = SyncClient(baseURL: baseURL, token: token)
        do {
            let tasks = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
            let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
            let labels = (try? context.fetch(FetchDescriptor<Label>())) ?? []
            let pushTasks = tasks.map { SyncClient.TaskDTO(
                id: $0.id.uuidString, title: $0.title, note: $0.note, priority: $0.priority,
                order: $0.order, due_date: iso($0.dueDate), completed_at: iso($0.completedAt),
                project_id: $0.project?.id.uuidString, label_ids: $0.labels.map(\.id.uuidString)) }
            let pushProjects = projects.map { SyncClient.ProjectDTO(
                id: $0.id.uuidString, name: $0.name, color_hex: $0.colorHex, order: $0.order, is_favorite: $0.isFavorite) }
            let pushLabels = labels.map { SyncClient.LabelDTO(id: $0.id.uuidString, name: $0.name, color_hex: $0.colorHex) }
            let resp = try await client.push(tasks: pushTasks, projects: pushProjects, labels: pushLabels)
            // Pull: upsert remote tasks into local store by id.
            let local = (try? context.fetch(FetchDescriptor<TodoTask>())) ?? []
            let localIds = Set(local.map(\.id.uuidString))
            for rt in resp.tasks where !localIds.contains(rt.id) {
                let t = TodoTask(title: rt.title, note: rt.note ?? "", priority: rt.priority, order: rt.order)
                t.id = UUID(uuidString: rt.id) ?? t.id
                context.insert(t)
            }
            try? context.save()
            status = "Synced \(resp.tasks.count) tasks at \(Date().formatted(.dateTime.hour().minute()))"
        } catch { status = "Sync failed: \(error.localizedDescription)" }
    }

    private func iso(_ d: Date?) -> String? {
        guard let d else { return nil }
        return ISO8601DateFormatter().string(from: d)
    }
}
