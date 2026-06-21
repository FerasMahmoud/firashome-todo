import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import UIKit

/// A Todoist-style task detail / editor view. Presented as the destination of
/// any task row tap. Edits title, note, project, due date, and priority
/// inline (autosave on every change), with a destructive Delete action at
/// the bottom. A toolbar toggle marks the task complete / incomplete without
/// leaving the screen.
///
/// Light theme, `TK.*` tokens, SF Symbols only. Targets iOS 17 (SwiftData).
/// When run on iOS 26+, the toolbar toggle wears a Liquid Glass background.
struct TaskDetailView: View {
    let task: TodoTask

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Project.order) private var projects: [Project]

    /// Mirrors `task.dueDate != nil` and feeds the optional due-date card.
    /// Stored as `@State` (not derived) so the toggle can set/clear the
    /// date in a single coordinated write.
    @State private var hasDueDate: Bool
    /// Mirrors `task.dueTime != nil` and feeds the optional reminder-time
    /// row. Stored as `@State` (not derived) so the toggle can set/clear
    /// the time in a single coordinated write.
    @State private var hasDueTime: Bool
    @State private var showDeleteConfirm: Bool = false
    @State private var newSubtask: String = ""
    /// Default time pre-selected in the add-reminder DatePicker — tomorrow
    /// 9:00am. The binding's `set` resets back to this after each add so a
    /// single picker can stamp multiple reminders in succession.
    @State private var newReminderDate: Date = TaskDetailView.defaultNewReminderDate

    // MARK: - Media (attachments + voice notes)
    // Attachment image files and voice-note audio files live on disk under
    // the app's Documents directory at `Documents/<taskID>/attachments/` and
    // `Documents/<taskID>/voice/` respectively. The view loads the directory
    // listing on appear and after every add/delete. Files survive app
    // restarts; deleting the task removes the parent folder in `Repository`.
    //
    // Info.plist requirements (must be set in the host app target):
    //   NSPhotoLibraryUsageDescription  — "Attach photos to a task"
    //   NSSMicrophoneUsageDescription   — "Record voice notes for a task"
    @State private var attachments: [URL] = []
    @State private var voiceNotes: [URL] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isRecording: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var currentPlayer: AVAudioPlayer?
    @State private var playingURL: URL?
    @State private var showMicDenied: Bool = false

    init(task: TodoTask) {
        self.task = task
        self._hasDueDate = State(initialValue: task.dueDate != nil)
        self._hasDueTime = State(initialValue: task.dueTime != nil)
    }

    /// Tomorrow 9:00am — the default offset for the add-reminder DatePicker.
    private static var defaultNewReminderDate: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? .now
    }

    var body: some View {
        @Bindable var task = task

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                titleCard(task: task)
                noteCard(task: task)
                subtasksCard(task: task)
                projectCard(task: task)
                dueCard(task: task)
                remindersCard(task: task)
                priorityCard(task: task)
                recurrenceCard(task: task)
                attachmentsCard(task: task)
                voiceNotesCard(task: task)
                metaFooter
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(TK.canvas.ignoresSafeArea())
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toggleCompletionButton
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Repository.delete(task, in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear(perform: loadMedia)
        .onDisappear {
            // Release audio resources so a swiped-away task doesn't keep
            // recording or playing in the background.
            if isRecording {
                audioRecorder?.stop()
                audioRecorder = nil
                isRecording = false
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            currentPlayer?.stop()
            currentPlayer = nil
            playingURL = nil
        }
        .alert("Microphone access denied", isPresented: $showMicDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable Microphone in Settings to record voice notes.")
        }
        .onChange(of: photoItems) { _, items in
            handlePickedPhotos(items)
        }
        .onChange(of: task.title) { _, _ in persist() }
        .onChange(of: task.note) { _, _ in persist() }
        .onChange(of: task.priority) { _, _ in persist() }
        .onChange(of: task.recurrence) { _, _ in persist() }
        .onChange(of: task.dueDate) { _, _ in reschedule() }
        .onChange(of: task.dueTime) { _, _ in reschedule() }
        .onChange(of: task.project) { _, _ in reschedule() }
        .onChange(of: hasDueDate) { _, newValue in
            if newValue {
                if task.dueDate == nil {
                    task.dueDate = Calendar.current.startOfDay(for: .now)
                }
            } else {
                task.dueDate = nil
                // Clearing the date also clears the time (no day → no reminder).
                if hasDueTime {
                    hasDueTime = false
                    task.dueTime = nil
                }
            }
            reschedule()
        }
        .onChange(of: hasDueTime) { _, newValue in
            if newValue {
                if task.dueTime == nil {
                    // Default reminder time: 9:00am on the current day.
                    let cal = Calendar.current
                    let base = task.dueDate ?? .now
                    let dayStart = cal.startOfDay(for: base)
                    task.dueTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart)
                }
            } else {
                task.dueTime = nil
            }
            reschedule()
        }
    }

    // MARK: - Toolbar toggle

    @ViewBuilder
    private var toggleCompletionButton: some View {
        let isDone = task.isCompleted
        let button = Button {
            Repository.toggle(task, in: context)
        } label: {
            Image(systemName: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(isDone ? TK.accent : TK.ink)
        }
        .accessibilityIdentifier(isDone ? "task-detail-reopen" : "task-detail-complete")
        .accessibilityLabel(isDone ? "Mark incomplete" : "Mark complete")

        // Liquid Glass (iOS 26) not available in this SDK — plain button.
        button
    }

    // MARK: - Title

    private func titleCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Task")
            TextField("Task name", text: $task.title, axis: .vertical)
                .font(TK.title)
                .foregroundStyle(TK.ink)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("task-detail-title")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Note

    private func noteCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Note")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $task.note)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .accessibilityIdentifier("task-detail-note")
                if task.note.isEmpty {
                    Text("Description")
                        .font(TK.body)
                        .foregroundStyle(TK.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Subtasks (checklist)

    private func subtasksCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                sectionLabel("Subtasks")
                Spacer()
                let total = task.subtasks.count
                if total > 0 {
                    let done = task.subtasks.filter(\.isDone).count
                    Text("\(done)/\(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TK.secondary)
                }
            }

            ForEach(task.subtasks.sorted(by: { $0.order < $1.order })) { st in
                HStack(spacing: 10) {
                    Button {
                        st.isDone.toggle()
                        try? context.save()
                    } label: {
                        Image(systemName: st.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(st.isDone ? TK.accent : TK.secondary)
                    }
                    .buttonStyle(.plain)
                    Text(st.title)
                        .font(TK.body)
                        .foregroundStyle(st.isDone ? TK.secondary : TK.ink)
                        .strikethrough(st.isDone, color: TK.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(TK.secondary)
                TextField("Add a step", text: $newSubtask)
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = newSubtask.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        let order = (task.subtasks.map(\.order).max() ?? -1) + 1
                        let st = Subtask(title: trimmed, order: order)
                        st.task = task
                        context.insert(st)
                        try? context.save()
                        newSubtask = ""
                    }
            }
            .padding(.vertical, 6)
        }
        .padding(14)
        .liquidGlass(cornerRadius: TK.rCard)
    }

    // MARK: - Project

    private func projectCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Project")
            Menu {
                Button {
                    task.project = nil
                    persist()
                } label: {
                    HStack(spacing: 6) { Image(systemName: "tray"); Text("Inbox") }
                }
                if !projects.isEmpty {
                    Divider()
                    ForEach(projects) { project in
                        Button {
                            task.project = project
                            persist()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 10, height: 10)
                                Text(project.name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if let project = task.project {
                        Circle()
                            .fill(project.color)
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .font(TK.body)
                            .foregroundStyle(TK.ink)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "tray")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TK.secondary)
                        Text("Inbox")
                            .font(TK.body)
                            .foregroundStyle(TK.ink)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("task-detail-project")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Due date

    private func dueCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Due date")
            HStack {
                Toggle(isOn: $hasDueDate) {
                    HStack(spacing: 8) {
                        Image(systemName: hasDueDate ? "calendar.badge.clock" : "calendar.badge.minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hasDueDate ? TK.accent : TK.secondary)
                        Text(hasDueDate ? "Set" : "No date")
                            .font(TK.body)
                            .foregroundStyle(hasDueDate ? TK.ink : TK.secondary)
                    }
                }
                .tint(TK.accent)
                .accessibilityIdentifier("task-detail-due-toggle")
            }

            if hasDueDate {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { task.dueDate ?? .now },
                        set: { task.dueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(TK.accent)
                .accessibilityIdentifier("task-detail-due-date")

                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Toggle(isOn: $hasDueTime) {
                        HStack(spacing: 8) {
                            Image(systemName: hasDueTime ? "bell.fill" : "bell.slash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(hasDueTime ? TK.accent : TK.secondary)
                            Text(hasDueTime ? notifyLabel : "Notify me")
                                .font(TK.body)
                                .foregroundStyle(hasDueTime ? TK.ink : TK.secondary)
                        }
                    }
                    .tint(TK.accent)
                    .accessibilityIdentifier("task-detail-notify-toggle")
                }

                if hasDueTime {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { task.dueTime ?? defaultNotifyTime(on: task.dueDate) },
                            set: { task.dueTime = $0 }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .tint(TK.accent)
                    .accessibilityIdentifier("task-detail-notify-time")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Reminders

    /// Reminders card — multiple date-stamped bells on the task, distinct
    /// from the single `dueTime` notify-toggle in the due card above. Each
    /// existing reminder renders as a swipe-to-reveal row (left-swipe →
    /// red "Delete" button, like iOS Mail). The footer row is a DatePicker
    /// bound to a custom Binding whose `set` appends a new Reminder and
    /// resets the picker back to tomorrow 9:00am so the user can stamp
    /// several in a row.
    private func remindersCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                sectionLabel("Reminders")
                Spacer()
                let n = task.reminders.count
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TK.secondary)
                        .monospacedDigit()
                        .accessibilityLabel("\(n) reminders")
                }
            }

            if task.reminders.isEmpty {
                Text("No reminders yet")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("task-detail-reminders-empty")
            } else {
                VStack(spacing: 6) {
                    ForEach(task.reminders.sorted(by: { $0.date < $1.date })) { reminder in
                        ReminderRow(reminder: reminder) {
                            deleteReminder(reminder)
                        }
                    }
                }
            }

            addReminderRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
        .accessibilityIdentifier("task-detail-reminders-card")
    }

    /// Footer row of the reminders card. The DatePicker's selection is
    /// wrapped in a Binding whose `set` performs the append + reset, so
    /// every distinct user pick = exactly one new Reminder with no extra
    /// confirm button.
    private var addReminderRow: some View {
        let addBinding = Binding<Date>(
            get: { newReminderDate },
            set: { newDate in
                addReminder(at: newDate)
                // Reset the picker back to the default so the next pick
                // registers as a fresh change (avoids duplicate fires).
                newReminderDate = TaskDetailView.defaultNewReminderDate
            }
        )
        return HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TK.accent)
                .accessibilityHidden(true)
            DatePicker(
                "Add reminder",
                selection: addBinding,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(TK.accent)
            .accessibilityIdentifier("task-detail-add-reminder")
        }
        .padding(.top, 4)
    }

    private func addReminder(at date: Date) {
        let reminder = Reminder(date: date)
        reminder.task = task
        task.reminders.append(reminder)
        context.insert(reminder)
        try? context.save()
    }

    private func deleteReminder(_ reminder: Reminder) {
        task.reminders.removeAll { $0.id == reminder.id }
        context.delete(reminder)
        try? context.save()
    }

// MARK: - Priority

    private func priorityCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Priority")
            Picker("Priority", selection: $task.priority) {
                ForEach(1...4, id: \.self) { p in
                    HStack(spacing: 6) {
                        Image(systemName: p < 4 ? "flag.fill" : "flag")
                            .foregroundStyle(TK.priority(p))
                        Text(priorityLabel(p))
                    }
                    .tag(p)
                }
            }
            .pickerStyle(.menu)
            .tint(TK.priority(task.priority))
            .accessibilityIdentifier("task-detail-priority")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Recurrence

    private func recurrenceCard(task: TodoTask) -> some View {
        @Bindable var task = task
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Repeat")
            Menu {
                Button {
                    task.recurrence = nil
                } label: {
                    HStack {
                        if task.recurrence == nil { Image(systemName: "checkmark") }
                        Text("No repeat")
                    }
                }
                Divider()
                ForEach(RecurrenceKind.allCases) { kind in
                    Button {
                        task.recurrence = kind.storageValue
                    } label: {
                        HStack {
                            if task.recurrence == kind.storageValue { Image(systemName: "checkmark") }
                            Image(systemName: kind.icon)
                            Text(kind.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.recurrence == nil ? "arrow.clockwise" : "arrow.clockwise.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(task.recurrence == nil ? TK.secondary : TK.accent)
                    Text(recurrenceLabel(task.recurrence))
                        .font(TK.body)
                        .foregroundStyle(task.recurrence == nil ? TK.secondary : TK.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TK.secondary)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("task-detail-recurrence")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
    }

    private func recurrenceLabel(_ raw: String?) -> String {
        guard let raw, let kind = RecurrenceKind(rawValue: raw) else { return "No repeat" }
        return kind.label
    }

    // MARK: - Attachments (images)

    private func attachmentsCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                sectionLabel("Attachments")
                Spacer()
                let n = attachments.count
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TK.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(n) attachments")
                }
            }

            PhotosPicker(
                selection: $photoItems,
                maxSelectionCount: nil,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TK.accent)
                    Text(attachments.isEmpty ? "Add a photo" : "Add more")
                        .font(TK.body)
                        .foregroundStyle(TK.ink)
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("task-detail-attachments-add")

            if attachments.isEmpty {
                Text("No attachments yet")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("task-detail-attachments-empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments, id: \.self) { url in
                            AttachmentThumb(url: url) {
                                deleteAttachment(url)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: attachments)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
        .accessibilityIdentifier("task-detail-attachments-card")
    }

    // MARK: - Voice notes

    private func voiceNotesCard(task: TodoTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mic")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                sectionLabel("Voice notes")
                Spacer()
                let n = voiceNotes.count
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TK.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(n) voice notes")
                }
            }

            recordButton

            if voiceNotes.isEmpty {
                Text("No recordings yet")
                    .font(TK.subhead)
                    .foregroundStyle(TK.secondary)
                    .padding(.vertical, 2)
                    .accessibilityIdentifier("task-detail-voice-empty")
            } else {
                VStack(spacing: 6) {
                    ForEach(voiceNotes, id: \.self) { url in
                        VoiceNoteRow(
                            url: url,
                            isPlaying: playingURL == url,
                            onPlay: { togglePlayback(url) },
                            onDelete: { deleteVoiceNote(url) }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: voiceNotes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(TK.card, in: RoundedRectangle(cornerRadius: TK.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TK.rCard, style: .continuous)
                .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
        )
        .accessibilityIdentifier("task-detail-voice-card")
    }

    /// Tap-to-toggle record button. Mirrors the rest of the detail view's
    /// plain-button style; the mic/stop glyph pulses while recording and a
    /// small REC chip sits on the trailing edge.
    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isRecording ? TK.accent : TK.ink)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRecording)
                Text(isRecording ? "Stop recording" : "Record a voice note")
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                Spacer()
                if isRecording {
                    Text("REC")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TK.accent, in: Capsule())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .scaleEffect(isRecording ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isRecording ? "task-detail-voice-stop" : "task-detail-voice-record")
        .accessibilityLabel(isRecording ? "Stop recording" : "Record a voice note")
    }

    // MARK: - Media helpers

    /// Per-task root folder inside the app's Documents directory.
    private var mediaRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = docs.appendingPathComponent(task.id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var attachmentsDir: URL {
        ensure(mediaRoot.appendingPathComponent("attachments", isDirectory: true))
    }

    private var voiceDir: URL {
        ensure(mediaRoot.appendingPathComponent("voice", isDirectory: true))
    }

    private func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func loadMedia() {
        let fm = FileManager.default
        attachments = ((try? fm.contentsOfDirectory(at: attachmentsDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        voiceNotes = ((try? fm.contentsOfDirectory(at: voiceDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Convert a batch of `PhotosPickerItem`s into JPEG files on disk. The
    /// picker hands us raw `Data`; we decode, recompress, and write under
    /// `attachmentsDir/`. Failures are silent — a corrupt item is dropped.
    private func handlePickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let name = "img-\(UUID().uuidString.prefix(8))"
                if let img = UIImage(data: data),
                   let jpeg = img.jpegData(compressionQuality: 0.85) {
                    try? jpeg.write(to: attachmentsDir.appendingPathComponent("\(name).jpg"))
                } else {
                    try? data.write(to: attachmentsDir.appendingPathComponent("\(name).png"))
                }
            }
            await MainActor.run {
                photoItems = []
                loadMedia()
            }
        }
    }

    private func deleteAttachment(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            attachments.removeAll { $0 == url }
        }
    }

    private func toggleRecording() {
        if isRecording {
            audioRecorder?.stop()
            audioRecorder = nil
            isRecording = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            loadMedia()
            return
        }
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                if granted {
                    self.startRecording()
                } else {
                    self.showMicDenied = true
                }
            }
        }
    }

    private func startRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let url = voiceDir.appendingPathComponent("rec-\(Int(Date().timeIntervalSince1970)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.prepareToRecord()
            rec.record()
            audioRecorder = rec
            isRecording = true
        } catch {
            // Recording unavailable (e.g. simulator without mic) — silently no-op.
            isRecording = false
        }
    }

    private func togglePlayback(_ url: URL) {
        if playingURL == url {
            currentPlayer?.stop()
            currentPlayer = nil
            playingURL = nil
            return
        }
        currentPlayer?.stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            currentPlayer = player
            playingURL = url
            // Auto-clear `playingURL` once the recording's natural duration
            // elapses (plus a 100ms grace). We poll by sleep rather than
            // wiring an AVAudioPlayerDelegate so the view stays plain SwiftUI.
            let duration = max(player.duration, 0.1)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 100_000_000)
                if playingURL == url {
                    playingURL = nil
                    currentPlayer = nil
                }
            }
        } catch {
            playingURL = nil
        }
    }

    private func deleteVoiceNote(_ url: URL) {
        if playingURL == url {
            currentPlayer?.stop()
            currentPlayer = nil
            playingURL = nil
        }
        try? FileManager.default.removeItem(at: url)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            voiceNotes.removeAll { $0 == url }
        }
    }

    // MARK: - Meta footer

    private var metaFooter: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(TK.secondary)
                    .accessibilityHidden(true)
                Text("Created ")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                + Text(task.createdAt, format: .dateTime.day().month().year())
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("task-detail-created")

            Spacer()

            subtaskProgressChip
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    /// Tiny progress bar + "n/m" count for the task's subtasks. Renders nothing
    /// when there are no subtasks.
    @ViewBuilder
    private var subtaskProgressChip: some View {
        let subtasks = task.subtasks
        let total = subtasks.count
        if total > 0 {
            let done = subtasks.filter(\.isDone).count
            HStack(spacing: 6) {
                ProgressView(value: Double(done), total: Double(total))
                    .progressViewStyle(.linear)
                    .tint(TK.accent)
                    .frame(width: 44, height: 4)
                Text("\(done)/\(total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TK.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(done) of \(total) subtasks done")
            .accessibilityIdentifier("task-detail-subtask-progress")
        }
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("Delete task")
                    .font(TK.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
                    .fill(TK.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-detail-delete")
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(TK.sectionHeader)
            .foregroundStyle(TK.secondary)
            .textCase(nil)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 1: return "Priority 1"
        case 2: return "Priority 2"
        case 3: return "Priority 3"
        default: return "Priority 4"
        }
    }

    private func persist() {
        try? context.save()
    }

    /// Persist + reschedule the local notification for this task. Centralized
    /// here so every onChange (date, time, project, completion-related flips)
    /// keeps the reminder in sync with the current model state.
    private func reschedule() {
        Repository.reschedule(task, in: context)
    }

    /// Default reminder moment: 9:00am on the due date (or today).
    private func defaultNotifyTime(on day: Date?) -> Date {
        let cal = Calendar.current
        let base = day ?? .now
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.startOfDay(for: base)) ?? .now
    }

    /// Short label for the notify row when a time is set, e.g. "Notify at 9:00 AM".
    private var notifyLabel: String {
        guard let time = task.dueTime else { return "Notify me" }
        return "Notify at " + time.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Preview


// MARK: - ReminderRow

/// One reminder row inside the reminders card. The visible row is offset on
/// the X axis by a DragGesture; pulling it past ~44pt reveals a red "Delete"
/// affordance behind it. Releases past the threshold snap fully open, releases
/// short snap closed. A tap on an open row closes it. Vertical drags are
/// ignored so the parent ScrollView keeps scrolling.
private struct ReminderRow: View {
    let reminder: Reminder
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    private static let openX: CGFloat = -88
    private static let threshold: CGFloat = -44

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteButton
            rowContent
        }
        .frame(minHeight: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var deleteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onDelete() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                Text("Delete")
                    .font(TK.sectionHeader)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(TK.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete reminder")
        .accessibilityIdentifier("reminder-delete")
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TK.accent)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(reminder.date.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                .font(TK.body)
                .foregroundStyle(TK.ink)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TK.card)
        .contentShape(Rectangle())
        .offset(x: offset)
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    // Only react when horizontal motion dominates — keeps
                    // vertical scrolling inside the parent ScrollView snappy.
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                    let proposed = dragStart + value.translation.width
                    offset = min(0, max(Self.openX, proposed))
                }
                .onEnded { value in
                    let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.4
                    guard horizontal else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = offset < Self.threshold ? Self.openX : 0
                        dragStart = offset
                    }
                }
        )
        .onTapGesture {
            // Tap on an open row closes it. Taps on a closed row are
            // ignored here so other gestures (DatePicker focus, etc.)
            // remain unaffected.
            guard offset < 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = 0
                dragStart = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reminder at \(reminder.date.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))")
        .accessibilityHint("Swipe left to delete")
        .accessibilityIdentifier("reminder-row")
    }
}

// MARK: - Attachment thumbnail

/// One image thumbnail in the attachments card's horizontal scroller. The
/// image is loaded lazily from disk via `.task(id:)`, so off-screen thumbs
/// don't pay decode cost. Tapping the small `x` button in the top-right
/// corner deletes the underlying file.
private struct AttachmentThumb: View {
    let url: URL
    let onDelete: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.15)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundStyle(TK.secondary)
                        )
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
            )

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
            .accessibilityIdentifier("task-detail-attachment-remove")
        }
        .task(id: url) {
            let loaded = UIImage(contentsOfFile: url.path)
            await MainActor.run { self.image = loaded }
        }
    }
}

// MARK: - Voice note row

/// One recorded voice note in the voice-notes card. Mirrors the ReminderRow
/// swipe-to-reveal delete affordance: drag left past ~44pt to expose a red
/// "Delete" button, tap an open row to close it. The leading play button
/// toggles AVAudioPlayer via the parent; its glyph swaps to `stop.fill`
/// while the audio is playing.
private struct VoiceNoteRow: View {
    let url: URL
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat = 0
    private static let openX: CGFloat = -88
    private static let threshold: CGFloat = -44

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteButton
            rowContent
        }
        .frame(minHeight: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var deleteButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onDelete() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                Text("Delete")
                    .font(TK.sectionHeader)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(TK.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete voice note")
        .accessibilityIdentifier("voice-delete")
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { onPlay() }
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isPlaying ? TK.accent : TK.ink))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop playback" : "Play recording")
            .accessibilityIdentifier("voice-play")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(TK.body)
                    .foregroundStyle(TK.ink)
                    .lineLimit(1)
                Text(secondaryLabel)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(TK.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TK.card)
        .contentShape(Rectangle())
        .offset(x: offset)
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    // Only react when horizontal motion dominates — keeps
                    // vertical scrolling inside the parent ScrollView snappy.
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                    let proposed = dragStart + value.translation.width
                    offset = min(0, max(Self.openX, proposed))
                }
                .onEnded { value in
                    let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.4
                    guard horizontal else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = offset < Self.threshold ? Self.openX : 0
                        dragStart = offset
                    }
                }
        )
        .onTapGesture {
            // Tap on an open row closes it. Taps on a closed row are
            // ignored here so other gestures (DatePicker focus, etc.)
            // remain unaffected.
            guard offset < 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = 0
                dragStart = 0
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName), \(secondaryLabel)")
        .accessibilityHint("Swipe left to delete")
        .accessibilityIdentifier("voice-row")
    }

    /// Friendly label derived from the file's `rec-<unix>` filename: shows
    /// the recording's wall-clock time so users can scan a list quickly.
    private var displayName: String {
        let stamp = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "rec-", with: "")
        if let secs = TimeInterval(stamp) {
            let date = Date(timeIntervalSince1970: secs)
            return "Recording " + date.formatted(date: .abbreviated, time: .shortened)
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private var secondaryLabel: String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let sizeStr = formatBytes(bytes)
        return isPlaying ? "Playing · \(sizeStr)" : sizeStr
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024.0)
    }
}


