import SwiftUI
import SwiftData

/// Browse, create, and delete labels. Todoist-style: "#" prefix, colored dot, name, task count.
/// Lives inside the NavigationSplitView detail pane; navigation chrome comes from the system.
struct LabelsView: View {
    @Query(sort: \Label.name) private var labels: [Label]
    @Environment(\.modelContext) private var context

    @State private var showingAddSheet = false
    @State private var newLabelName = ""
    @State private var newLabelColor: String = LabelPalette.defaultHex

    var body: some View {
        Group {
            if labels.isEmpty {
                emptyState
            } else {
                labelsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
        .navigationTitle("Labels")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newLabelName = ""
                    newLabelColor = LabelPalette.defaultHex
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TK.accent)
                }
                .accessibilityLabel("New label")
                .accessibilityIdentifier("labels-add-button")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addLabelSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - List

    private var labelsList: some View {
        List {
            Section {
                ForEach(labels) { label in
                    LabelRow(label: label)
                }
                .onDelete(perform: deleteLabels)
            } header: {
                Text("All labels")
                    .font(TK.sectionHeader)
                    .foregroundStyle(TK.secondary)
                    .textCase(nil)
            }
            .listRowBackground(TK.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tag")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)
            Text("No labels yet")
                .font(TK.title)
                .foregroundStyle(TK.ink)
            Text("Labels help you group tasks across projects.\nTap + to create your first label.")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TK.canvas)
    }

    // MARK: - Add sheet

    private var addLabelSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label name", text: $newLabelName)
                        .font(TK.body)
                        .accessibilityIdentifier("label-add-name-field")
                } header: {
                    Text("Name")
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                }
                .listRowBackground(TK.card)

                Section {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
                        spacing: 12
                    ) {
                        ForEach(LabelPalette.choices, id: \.self) { hex in
                            colorSwatch(hex: hex)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                        .font(TK.sectionHeader)
                        .foregroundStyle(TK.secondary)
                        .textCase(nil)
                }
                .listRowBackground(TK.card)
            }
            .scrollContentBackground(.hidden)
            .background(TK.grouped)
            .navigationTitle("New label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                    .foregroundStyle(TK.secondary)
                    .accessibilityIdentifier("label-add-cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        saveLabel()
                    }
                    .fontWeight(.semibold)
                    .disabled(newLabelName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("label-add-save")
                }
            }
        }
    }

    private func colorSwatch(hex: String) -> some View {
        let isSelected = newLabelColor == hex
        return Button {
            newLabelColor = hex
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 32, height: 32)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(TK.ink.opacity(isSelected ? 0.15 : 0), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)")
        .accessibilityIdentifier("label-color-\(hex)")
    }

    // MARK: - Mutations

    private func saveLabel() {
        let trimmed = newLabelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let label = Label(name: trimmed, colorHex: newLabelColor)
        context.insert(label)
        try? context.save()
        newLabelName = ""
        newLabelColor = LabelPalette.defaultHex
        showingAddSheet = false
    }

    private func deleteLabels(at offsets: IndexSet) {
        for index in offsets {
            context.delete(labels[index])
        }
        try? context.save()
    }
}

// MARK: - Row

private struct LabelRow: View {
    let label: Label

    var body: some View {
        HStack(spacing: 12) {
            Text("#")
                .font(TK.body)
                .foregroundStyle(TK.secondary)
                .accessibilityHidden(true)

            Circle()
                .fill(label.color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .strokeBorder(TK.hairlineSoft, lineWidth: 0.5)
                )
                .accessibilityHidden(true)

            Text(label.name)
                .font(TK.body)
                .foregroundStyle(TK.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(label.tasks.count)")
                .font(TK.subhead)
                .foregroundStyle(TK.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Label \(label.name), \(label.tasks.count) \(label.tasks.count == 1 ? "task" : "tasks")")
        .accessibilityIdentifier("label-row-\(label.id.uuidString)")
    }
}

// MARK: - Palette

private enum LabelPalette {
    static let defaultHex = "8E8E93"

    static let choices: [String] = [
        "E53935", // red
        "F57C00", // orange
        "FBC02D", // yellow
        "7CB342", // green
        "039BE5", // blue
        "5E35B1", // purple
        "D81B60", // pink
        "00ACC1", // cyan
        "43A047", // emerald
        "6D4C41", // brown
        "546E7A", // blue gray
        "8E8E93"  // gray
    ]
}

// MARK: - Preview

#Preview {
    LabelsView()
        .modelContainer(for: [TodoTask.self, Project.self, Label.self], inMemory: true)
}