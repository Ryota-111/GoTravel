import SwiftUI

struct TaskListView: View {
    @StateObject private var manager = TaskManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedPriority: TaskItem.Priority? = nil
    @State private var showAddTask = false
    @State private var taskToEdit: TaskItem? = nil

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var displayedTasks: [TaskItem] { manager.tasks(for: selectedPriority) }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                priorityFilterBar

                if displayedTasks.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(displayedTasks) { task in
                                TaskRow(task: task) {
                                    manager.toggleComplete(task)
                                } onEdit: {
                                    taskToEdit = task
                                } onDelete: {
                                    manager.delete(task)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddTask = true }) {
                        ZStack {
                            Circle()
                                .fill(themeManager.currentTheme.xprimary)
                                .frame(width: 58, height: 58)
                                .shadow(color: themeManager.currentTheme.xprimary.opacity(0.45), radius: 12, x: 0, y: 5)
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("タスク")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTask) {
            TaskEditView(task: nil) { newTask in
                manager.add(newTask)
            }
        }
        .sheet(item: $taskToEdit) { task in
            TaskEditView(task: task) { updated in
                manager.update(updated)
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Priority Filter
    private var priorityFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "すべて", priority: nil)
                ForEach(TaskItem.Priority.allCases, id: \.self) { p in
                    filterChip(label: p.displayName, priority: p)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(themeManager.currentTheme.xprimary.opacity(0.05))
    }

    private func filterChip(label: String, priority: TaskItem.Priority?) -> some View {
        let isSelected = selectedPriority == priority
        let color = priority?.color ?? themeManager.currentTheme.xprimary
        return Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPriority = priority } }) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : color.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.xprimary.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.4))
            }
            VStack(spacing: 6) {
                Text("タスクがありません")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(accentColor)
                Text("「+」ボタンからタスクを追加しましょう")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Task Row
struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? task.priority.color : task.priority.color.opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(task.priority.color)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(task.isCompleted ? themeManager.currentTheme.secondaryText : accentColor)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(task.priority.displayName, systemImage: task.priority.icon)
                        .font(.caption.weight(.medium))
                        .foregroundColor(task.priority.color)

                    if let due = task.dueDate {
                        Label(dueDateText(due), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(isOverdue(due) && !task.isCompleted
                                ? themeManager.currentTheme.error
                                : themeManager.currentTheme.secondaryText)
                    }
                }
            }

            Spacer()

            Menu {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .shadow(color: task.priority.color.opacity(task.isCompleted ? 0.05 : 0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(task.priority.color.opacity(task.isCompleted ? 0.1 : 0.25), lineWidth: 1)
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }

    private func dueDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Task Edit View
struct TaskEditView: View {
    let task: TaskItem?
    let onSave: (TaskItem) -> Void

    @Environment(\.dismiss) var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var title: String
    @State private var priority: TaskItem.Priority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _priority = State(initialValue: task?.priority ?? .medium)
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? Date())
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var fieldBg: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.backgroundDark
            : themeManager.currentTheme.backgroundLight
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        titleSection
                        prioritySection
                        dueDateSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                saveButton
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [themeManager.currentTheme.backgroundDark, themeManager.currentTheme.secondaryBackgroundDark]
                : [themeManager.currentTheme.backgroundLight, themeManager.currentTheme.secondaryBackgroundLight]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(accentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
            Text(task == nil ? "タスクを追加" : "タスクを編集")
                .font(.headline)
                .foregroundColor(accentColor)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(themeManager.currentTheme.xprimary.opacity(0.08))
    }

    private var titleSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("タスク名", icon: "pencil")
                TextField("例：会議の資料を準備する", text: $title)
                    .font(.body)
                    .foregroundColor(accentColor)
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                title.isEmpty
                                    ? themeManager.currentTheme.error.opacity(0.35)
                                    : themeManager.currentTheme.xprimary.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    private var prioritySection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("優先度", icon: "flag.fill")
                HStack(spacing: 10) {
                    ForEach(TaskItem.Priority.allCases, id: \.self) { p in
                        let isSelected = priority == p
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { priority = p }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? p.color : p.color.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: p.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(isSelected ? .white : p.color)
                                }
                                Text(p.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(isSelected ? p.color : themeManager.currentTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? p.color.opacity(0.08) : Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? p.color : p.color.opacity(0.2), lineWidth: 1.5))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(isSelected ? 1.03 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
            }
        }
    }

    private var dueDateSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("期限（任意）", icon: "calendar")
                HStack {
                    Image(systemName: "calendar.circle")
                        .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.8))
                        .frame(width: 24)
                    Text("期限を設定")
                        .font(.subheadline)
                        .foregroundColor(accentColor)
                    Spacer()
                    Toggle("", isOn: $hasDueDate)
                        .labelsHidden()
                        .tint(themeManager.currentTheme.xprimary)
                }
                .padding(14)
                .background(fieldBg)
                .cornerRadius(12)

                if hasDueDate {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundColor(themeManager.currentTheme.xprimary.opacity(0.8))
                            .frame(width: 24)
                        Text("日付")
                            .font(.subheadline)
                            .foregroundColor(accentColor)
                        Spacer()
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .colorMultiply(themeManager.currentTheme.xprimary)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(14)
                    .background(fieldBg)
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasDueDate)
        }
    }

    private var saveButton: some View {
        Button(action: saveTask) {
            HStack(spacing: 6) {
                Image(systemName: task == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                Text(task == nil ? "タスクを追加" : "変更を保存")
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canSave ? themeManager.currentTheme.xprimary : themeManager.currentTheme.secondaryText)
                    .shadow(color: themeManager.currentTheme.xprimary.opacity(canSave ? 0.4 : 0), radius: 8, x: 0, y: 4)
            )
            .animation(.easeInOut(duration: 0.2), value: canSave)
        }
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    private func saveTask() {
        var item = task ?? TaskItem(title: "", priority: .medium)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.priority = priority
        item.dueDate = hasDueDate ? dueDate : nil
        onSave(item)
        dismiss()
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBg)
                    .shadow(color: themeManager.currentTheme.shadow, radius: 6, x: 0, y: 2)
            )
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.xprimary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
        }
    }
}
