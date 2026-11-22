import SwiftUI

/// 办事清单：填检查时间 → 每件事算出提醒时刻 → 一键设置提醒
struct ChecklistView: View {
    let todos: [Todo]
    let title: String
    let isSample: Bool
    var isLoading = false
    var speakingID: String?
    let onLocate: (Todo) -> Void

    @AppStorage("examDate") private var examTimestamp = Todo.defaultExamDate.timeIntervalSince1970
    @AppStorage("demoMode") private var demoMode = false
    @State private var done: Set<String> = []
    @State private var outcome: Reminders.Outcome?
    @State private var scheduling = false

    private var exam: Date { Date(timeIntervalSince1970: examTimestamp) }
    private var examBinding: Binding<Date> {
        Binding { exam } set: { examTimestamp = $0.timeIntervalSince1970; outcome = nil }
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .onChange(of: speakingID) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
        }
    }

    private var list: some View {
        List {
            Section {
                DatePicker("检查时间", selection: examBinding, displayedComponents: [.date, .hourAndMinute])
                VStack(alignment: .leading, spacing: 8) {
                    Text("已完成 \(done.count) / \(todos.count)").font(.subheadline.weight(.semibold))
                    ProgressView(value: Double(done.count), total: Double(max(todos.count, 1)))
                        .tint(.green)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("填好检查时间，清读会按须知的要求算出每件事该在什么时候做。")
            }

            ForEach(Todo.Stage.allCases) { stage in
                let items = Todo.ordered(todos, exam: exam).filter { $0.stage == stage }
                if !items.isEmpty {
                    Section(stage.title) {
                        ForEach(items) { todo in
                            row(todo)
                                .id(todo.id)
                                .listRowBackground(speakingID == todo.id
                                                   ? Color.accentColor.opacity(0.15)
                                                   : Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await setReminders() }
                } label: {
                    HStack {
                        if scheduling { ProgressView().tint(.white) }
                        Label(demoMode ? "演示：10 秒后弹出提醒" : "设置提醒", systemImage: "bell.badge.fill")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(scheduling || todos.isEmpty)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if let outcome { OutcomeLabel(outcome: outcome) }

                ShareLink(item: Todo.shareText(todos, title: title, exam: exam),
                          preview: SharePreview("\(title) · 办事清单")) {
                    Label("发给家人", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(todos.isEmpty)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Toggle("演示模式", isOn: $demoMode)
            } footer: {
                Text(isSample
                     ? "示例须知的要点是预先整理好的（模拟大模型改写）。时间和提醒是真实计算、真实设置的。"
                     : "这些事项由规则从原文里找出，文字保持原样。")
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if todos.isEmpty && isLoading {
                ProgressView("正在整理须知里的事项…")
            } else if todos.isEmpty {
                ContentUnavailableView("没有找到带时间的事项", systemImage: "checklist",
                                       description: Text("原文里没有识别出时间或禁止事项。"))
            }
        }
    }

    private func row(_ todo: Todo) -> some View {
        let isDone = done.contains(todo.id)
        return HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy) { if isDone { done.remove(todo.id) } else { done.insert(todo.id) } }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "标记为未完成" : "标记为完成")
            .sensoryFeedback(.success, trigger: isDone) { !$0 && $1 }

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.when)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(todo.warn ? Color.red : Color.secondary)
                Text(todo.styledTitle)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                if let date = todo.reminder(exam: exam) {
                    Label(date < .now ? "已过 · \(Self.format(date))" : "提醒 \(Self.format(date))",
                          systemImage: date < .now ? "bell.slash" : "bell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button { onLocate(todo) } label: {
                Image(systemName: "text.magnifyingglass").font(.body)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("在原文中查看")
        }
        .padding(.vertical, 4)
    }

    private func setReminders() async {
        scheduling = true
        outcome = await Reminders.shared.schedule(todos, exam: exam, demo: demoMode)
        scheduling = false
    }

    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

private struct OutcomeLabel: View {
    let outcome: Reminders.Outcome

    var body: some View {
        switch outcome {
        case .scheduled(let count, let first):
            Label("已设置 \(count) 条提醒" + (first.map { "，最早一条在 \(ChecklistView.format($0))" } ?? ""),
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .demo(let count):
            Label("演示模式：\(count) 条提醒将从 10 秒后依次弹出", systemImage: "timer")
                .foregroundStyle(.blue)
        case .nothingToSchedule:
            Label("没有需要提醒的事项，检查时间可能已经过去了", systemImage: "info.circle")
                .foregroundStyle(.secondary)
        case .denied:
            Label("没有通知权限，请到 设置 → 通知 → 清读 里打开", systemImage: "bell.slash.fill")
                .foregroundStyle(.red)
        }
    }
}
