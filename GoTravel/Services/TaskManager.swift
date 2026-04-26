import Foundation
import Combine

class TaskManager: ObservableObject {
    static let shared = TaskManager()

    @Published var tasks: [TaskItem] = []

    private let key = "SavedTaskItems"

    private init() { load() }

    // MARK: - CRUD

    func add(_ task: TaskItem) {
        tasks.append(task)
        save()
        NotificationService.shared.scheduleTaskNotifications(for: task)
    }

    func update(_ task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i] = task
            save()
            if task.isCompleted {
                NotificationService.shared.cancelTaskNotifications(for: task.id)
            } else {
                NotificationService.shared.scheduleTaskNotifications(for: task)
            }
        }
    }

    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
        NotificationService.shared.cancelTaskNotifications(for: task.id)
    }

    func toggleComplete(_ task: TaskItem) {
        var t = task
        t.isCompleted.toggle()
        update(t)
    }

    // MARK: - Filtered

    func tasks(for priority: TaskItem.Priority?) -> [TaskItem] {
        let base = priority == nil ? tasks : tasks.filter { $0.priority == priority }
        return base.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.priority.sortOrder != $1.priority.sortOrder { return $0.priority.sortOrder < $1.priority.sortOrder }
            if let d0 = $0.dueDate, let d1 = $1.dueDate { return d0 < d1 }
            if $0.dueDate != nil { return true }
            if $1.dueDate != nil { return false }
            return $0.createdAt < $1.createdAt
        }
    }

    var pendingCount: Int { tasks.filter { !$0.isCompleted }.count }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
    }
}
