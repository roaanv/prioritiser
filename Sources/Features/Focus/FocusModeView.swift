// FocusModeView.swift
// The slim "Today" focus mode: a single, distraction-free list of today's and
// overdue tasks as collapsible cards. Only the title and description are editable
// (plus checking a task off, and a minimal due-today quick-add). Toggled from the
// full app via the toolbar or ⌘⇧F; the chosen mode persists across launches.

import SwiftUI

struct FocusModeView: View {
    @Environment(AppModel.self) private var model
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            addField
            Divider().opacity(0.5)
            content
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today").font(.system(size: 22, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.isFocusMode = false } label: {
                Label("Full View", systemImage: "rectangle.3.group")
            }
            .help("Exit Focus mode (⌘⇧F)")
        }
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 14)
    }

    private var subtitle: String {
        let count = model.focusTasks.count
        let date = Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(date) · \(count) \(count == 1 ? "task" : "tasks")"
    }

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 13)).foregroundStyle(.secondary).frame(width: 20)
            TextField("Add a task for today…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit {
                    model.createTodayTask(title: newTitle)
                    newTitle = ""
                }
        }
        .padding(.horizontal, 22).padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if model.focusTasks.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28)).foregroundStyle(.green)
                Text("Nothing due today").font(.system(size: 15, weight: .semibold))
                Text("You're caught up. Add a task above, or switch to the full view.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.focusTasks) { task in
                        FocusTaskCard(task: task).id(task.id)
                    }
                }
                .padding(20)
            }
        }
    }
}

/// One collapsible task card: completion toggle + editable title, with an
/// expandable editable description. Edits persist as you type (like the detail pane).
private struct FocusTaskCard: View {
    @Environment(AppModel.self) private var model
    let task: TaskItem

    @State private var titleDraft = ""
    @State private var notesDraft = ""
    @State private var expanded = true

    private var overdue: Bool { (model.clock.daysUntil(task.due) ?? 0) < 0 }

    /// Read-only attribute guidance — the priority score (the ranking signal) plus
    /// impact / priority / effort, so it's clear what to tackle first.
    private var metrics: some View {
        HStack(spacing: 14) {
            metric("Score", "\(model.score(for: task))", emphasized: true)
            metric("Impact", task.impact.label)
            metric("Priority", task.priority.label)
            if let effort = Formatting.effort(task.effortMinutes) {
                metric("Effort", effort)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 28) // align under the title, past the checkbox
    }

    private func metric(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold)).kerning(0.4)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11.5, weight: emphasized ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(emphasized ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                CompletionToggle(task: task) { model.toggleDone(task) }
                TextField("Task title", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .onChange(of: titleDraft) { _, new in
                        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty, trimmed != task.title {
                            setField { $0.title = trimmed }
                        }
                    }
                if overdue, let due = task.due {
                    Label(due.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.red.opacity(0.85), in: Capsule())
                        .help("Was due \(due.formatted(.dateTime.weekday(.wide).month().day()))")
                }
                Button {
                    withAnimation(.easeOut(duration: 0.12)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse description" : "Expand description")
            }
            metrics
            if expanded {
                MarkdownNotesEditor(text: $notesDraft, placeholder: "Add a description…", minHeight: 44, fontSize: 12.5)
                    .frame(minHeight: 44)
                    .onChange(of: notesDraft) { _, new in
                        setField { $0.notes = new.isEmpty ? nil : new }
                    }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .onAppear {
            titleDraft = task.title
            notesDraft = task.notes ?? ""
        }
    }

    private func setField(_ mutate: (inout TaskItem) -> Void) {
        var next = task
        mutate(&next)
        model.update(next)
    }
}
