import UserNotifications

/// 本地通知：按检查时间设置提醒
@MainActor
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Reminders()

    enum Outcome {
        case scheduled(count: Int, first: Date?)
        case demo(count: Int)
        case nothingToSchedule
        case denied
    }

    private let center = UNUserNotificationCenter.current()
    private let prefix = "qingdu."

    /// App 启动时调用，让 App 在前台时也能弹出提醒
    func activate() {
        center.delegate = self
    }

    /// 设置提醒。演示模式下不按真实时间，而是 10 秒后起每隔 10 秒弹一条禁止事项。
    func schedule(_ todos: [Todo], exam: Date, demo: Bool) async -> Outcome {
        guard await requestAuthorization() else { return .denied }

        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        if demo {
            let picks = todos.filter { $0.warn && $0.timing != nil }.prefix(3)
            for (i, todo) in picks.enumerated() {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(10 * (i + 1)), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: prefix + todo.id, content: content(for: todo), trigger: trigger))
            }
            return picks.isEmpty ? .nothingToSchedule : .demo(count: picks.count)
        }

        var dates: [Date] = []
        for todo in todos {
            guard let date = todo.reminder(exam: exam), date > .now else { continue }
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + todo.id, content: content(for: todo), trigger: trigger))
            dates.append(date)
        }
        return dates.isEmpty ? .nothingToSchedule : .scheduled(count: dates.count, first: dates.min())
    }

    /// 申请通知权限；已经允许或拒绝过的不会再弹对话框
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private func content(for todo: Todo) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = todo.warn ? "⚠️ \(todo.when)" : todo.when
        content.body = todo.title
        content.sound = .default
        content.threadIdentifier = "qingdu"
        return content
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
