import Foundation
import SwiftData

/// Demo data so screenshots look alive and first launch isn't empty.
enum Seed {
    static func seedIfEmpty(context: ModelContext) {
        let descriptor = FetchDescriptor<TodoTask>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        wipeAndSeed(context: context)
    }

    static func wipeAndSeed(context: ModelContext) {
        // Clear
        for t in (try? context.fetch(FetchDescriptor<TodoTask>())) ?? [] { context.delete(t) }
        for p in (try? context.fetch(FetchDescriptor<Project>())) ?? [] { context.delete(p) }
        for l in (try? context.fetch(FetchDescriptor<Label>())) ?? [] { context.delete(l) }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let inThreeDays = cal.date(byAdding: .day, value: 3, to: today)!
        let nextWeek = cal.date(byAdding: .day, value: 7, to: today)!

        // Labels
        let urgent = Label(name: "Urgent", colorHex: "E53935")
        let work = Label(name: "Work", colorHex: "4072D4")
        let home = Label(name: "Home", colorHex: "2E7D32")
        let errands = Label(name: "Errands", colorHex: "F99B17")

        // Projects
        let inbox = Project(name: "Inbox", colorHex: "246FE0", order: 0, isFavorite: true)
        let fittech = Project(name: "FITech", colorHex: "1B8B6A", order: 1, isFavorite: true)
        let personal = Project(name: "Personal", colorHex: "9C27B0", order: 2)
        let shopping = Project(name: "Shopping", colorHex: "F99B17", order: 3)

        func task(_ title: String, note: String = "", due: Date? = nil, priority: Int = 4, order: Int, project: Project?, labels: [Label] = []) {
            let t = TodoTask(title: title, note: note, dueDate: due, priority: priority, order: order, project: project, labels: labels)
            context.insert(t)
        }

        // Today
        task("Review Qiddiya drone survey brief", note: "Section 3 — flight plan coverage", due: today, priority: 1, order: 0, project: fittech, labels: [urgent, work])
        task("Call Bullivant HSE contact", due: today, priority: 2, order: 1, project: fittech, labels: [work])
        task("Reply to investor email", due: today, priority: 3, order: 2, project: inbox, labels: [urgent])
        task("Gym — leg day", due: today, order: 3, project: personal, labels: [home])
        task("Buy coffee beans", due: today, order: 4, project: shopping, labels: [errands])

        // Upcoming
        task("SAM3 defect model — bake-off notes", note: "Compare YOLO26-L vs SAM3 on crack set", due: tomorrow, priority: 2, order: 0, project: fittech, labels: [work])
        task("ViewKeeper landing hero video review", due: tomorrow, order: 1, project: fittech)
        task("Renew domain portfolio", due: inThreeDays, order: 2, project: personal)
        task("Plan weekend trip to Riyadh", due: nextWeek, order: 3, project: personal, labels: [home])

        // No date / later
        task("Read Elite CV engineer techniques", priority: 4, order: 0, project: fittech)
        task("Organize Cloudflare DNS records", order: 1, project: personal)

        // Inbox — tasks with NO project (true Todoist Inbox bucket)
        task("Brainstorm Q3 growth experiments", due: today, priority: 2, order: 6, project: nil, labels: [work])
        task("Reply to the WhatsApp group about weekend", due: tomorrow, order: 7, project: nil)
        task("Renew Notion subscription", priority: 3, order: 8, project: nil)

        [urgent, work, home, errands].forEach { context.insert($0) }

        // Demo subtasks on the first today task (shows the checklist feature).
        let demoTask = ((try? context.fetch(FetchDescriptor<TodoTask>())) ?? [])
            .first { $0.title == "Review Qiddiya drone survey brief" }
        if let demoTask {
            let steps = ["Confirm drone flight clearance", "Prepare camera payload", "Draft coverage map"]
            for (i, s) in steps.enumerated() {
                let st = Subtask(title: s, order: i); st.task = demoTask; context.insert(st)
                if i == 0 { st.isDone = true }
            }
        }

        [inbox, fittech, personal, shopping].forEach { context.insert($0) }

        try? context.save()
    }
}
