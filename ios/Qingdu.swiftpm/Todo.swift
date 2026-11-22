import Foundation
import SwiftUI

/// 办事清单里的一条
struct Todo: Identifiable, Hashable {
    /// 什么时候要做
    enum Timing: Hashable {
        case daysBefore(Int, hour: Int, minute: Int)   // 检查前 N 天的某个时刻
        case minutesBefore(Int)                        // 检查前 N 分钟
        case onExamDay(hour: Int, minute: Int)         // 检查当天的某个时刻
    }

    enum Stage: Int, CaseIterable, Identifiable {
        case before, examDay, after, anytime
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .before: "检查前"
            case .examDay: "检查当天"
            case .after: "检查后"
            case .anytime: "其他注意事项"
            }
        }
    }

    let id: String
    let when: String          // 显示的时间说法，如「检查前 2 小时」
    let title: String         // 要做的事
    let warn: Bool            // 是否是禁止事项
    let ref: String           // 原文里的一段文字，用来跳回原句
    var negWords: [String] = []
    var timing: Timing?
    var lead = 0              // 提前多少分钟提醒
    var stage: Stage

    /// 事情的截止时刻
    func deadline(exam: Date) -> Date? {
        let calendar = Calendar.current
        switch timing {
        case .daysBefore(let days, let hour, let minute):
            guard let day = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: exam)) else { return nil }
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        case .minutesBefore(let minutes):
            return exam.addingTimeInterval(-Double(minutes) * 60)
        case .onExamDay(let hour, let minute):
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: exam)
        case nil:
            return nil
        }
    }

    /// 提醒弹出的时刻
    func reminder(exam: Date) -> Date? {
        deadline(exam: exam)?.addingTimeInterval(-Double(lead) * 60)
    }

    /// 禁止词标红加粗
    var styledTitle: AttributedString {
        var text = AttributedString(title)
        for word in negWords {
            var searchRange = text.startIndex..<text.endIndex
            while let range = text[searchRange].range(of: word) {
                text[range].foregroundColor = .red
                text[range].font = .body.weight(.bold)
                searchRange = range.upperBound..<text.endIndex
            }
        }
        return text
    }

    /// 默认检查时间：8 天后上午 9 点，这样「检查前 7 天」这类提醒都还没过
    static var defaultExamDate: Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 8, to: .now) ?? .now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// 用户填的检查时间（清单页里保存的）
    static var savedExamDate: Date {
        let stored = UserDefaults.standard.double(forKey: "examDate")
        return stored > 0 ? Date(timeIntervalSince1970: stored) : defaultExamDate
    }

    /// 清单的显示顺序：先按阶段，阶段内按提醒时刻，没有时刻的放后面
    static func ordered(_ todos: [Todo], exam: Date) -> [Todo] {
        Stage.allCases.flatMap { stage in
            todos.enumerated().filter { $0.element.stage == stage }.sorted { a, b in
                switch (a.element.reminder(exam: exam), b.element.reminder(exam: exam)) {
                case let (x?, y?): return x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }.map(\.element)
        }
    }

    /// 发给家人的一段话
    static func shareText(_ todos: [Todo], title: String, exam: Date) -> String {
        var name = title
        for suffix in ["前须知", "须知", "注意事项", "告知书"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        if name.isEmpty { name = "检查" }

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        var lines = ["我要做「\(name)」，时间是 \(formatter.string(from: exam))。须知里要注意这些，麻烦帮我一起记着："]
        let ordered = ordered(todos, exam: exam)
        for stage in Stage.allCases {
            let items = ordered.filter { $0.stage == stage }
            guard !items.isEmpty else { continue }
            lines.append("")
            lines.append("【\(stage.title)】")
            for todo in items {
                let time = todo.deadline(exam: exam).map { formatter.string(from: $0) + "｜" } ?? ""
                lines.append("\(todo.warn ? "⚠️" : "·") \(time)\(todo.when)：\(todo.title)")
            }
        }
        lines.append("")
        lines.append("—— 来自「清读」")
        return lines.joined(separator: "\n")
    }
}

// MARK: - 示例须知的要点（预设，模拟大模型改写成大白话的结果）

extension Todo {
    static let sample: [Todo] = [
        Todo(id: "anticoag", when: "检查前 7 天", title: "在吃阿司匹林等抗凝药的，先问医生；切勿自己停药",
             warn: true, ref: "检查前7天", negWords: ["切勿"], timing: .daysBefore(7, hour: 9, minute: 0), stage: .before),
        Todo(id: "diet", when: "检查前 3 天", title: "只吃白粥、面条、蒸蛋；不要吃蔬菜水果",
             warn: true, ref: "检查前3天", negWords: ["不要"], timing: .daysBefore(3, hour: 9, minute: 0), stage: .before),
        Todo(id: "fast", when: "前一天 20:00 以后", title: "禁止进食，可以喝少量清水",
             warn: true, ref: "20:00以后", negWords: ["禁止进食"], timing: .daysBefore(1, hour: 20, minute: 0), lead: 30, stage: .before),
        Todo(id: "meds", when: "当天早上", title: "糖尿病：暂停降糖药和胰岛素；降压药照吃",
             warn: true, ref: "暂停口服", negWords: ["暂停"], timing: .onExamDay(hour: 6, minute: 0), lead: 15, stage: .examDay),
        Todo(id: "laxative", when: "当天 6:00", title: "2 盒泻药兑 2000 毫升温水，每 15 分钟喝 250 毫升，2 小时内喝完",
             warn: false, ref: "6:00开始", timing: .onExamDay(hour: 6, minute: 0), lead: 10, stage: .examDay),
        Todo(id: "water", when: "检查前 2 小时", title: "禁止喝水",
             warn: true, ref: "检查前2小时", negWords: ["禁止喝水"], timing: .minutesBefore(120), stage: .examDay),
        Todo(id: "leave", when: "出门前", title: "带身份证、医保卡和以前的检查报告，提前 30 分钟到",
             warn: false, ref: "身份证", timing: .minutesBefore(60), stage: .examDay),
        Todo(id: "after", when: "检查后当天", title: "不能开车，不做高空作业，不签重要文件",
             warn: true, ref: "不能驾车", negWords: ["不能开车"], stage: .after),
    ]
}

// MARK: - 从识别结果里用规则抽取（真做）

enum TodoBuilder {
    /// sections 来自阅读器发回的摘要：[{heading, sentences: [{text, level, tags: [{kind, text}]}]}]
    static func todos(from sections: [[String: Any]]) -> [Todo] {
        var result: [Todo] = []
        for section in sections {
            for sentence in section["sentences"] as? [[String: Any]] ?? [] {
                guard let text = sentence["text"] as? String,
                      let level = sentence["level"] as? String, level != "minor" else { continue }
                let tags = sentence["tags"] as? [[String: Any]] ?? []
                let texts = { (kind: String) in tags.filter { $0["kind"] as? String == kind }.compactMap { $0["text"] as? String } }
                let times = texts("time"), negs = texts("neg")
                let isKey = level == "key"
                guard !times.isEmpty || isKey else { continue }

                let timing = parseTiming(times: times, sentence: text)
                var lead = 0
                switch timing {
                case .daysBefore(_, let hour, let minute) where hour != 9 || minute != 0: lead = 30
                case .onExamDay: lead = 10
                default: break
                }
                let stage: Todo.Stage = text.contains("检查后") ? .after : {
                    switch timing {
                    case .daysBefore: return .before
                    case .minutesBefore, .onExamDay: return .examDay
                    case nil: return .anytime
                    }
                }()
                result.append(Todo(id: "rule-\(result.count)", when: times.first ?? "注意",
                                   title: text.trimmingCharacters(in: CharacterSet(charactersIn: "。；; ")),
                                   warn: isKey, ref: String(text.prefix(12)), negWords: negs,
                                   timing: timing, lead: lead, stage: stage))
            }
        }
        return result
    }

    /// 从「检查前3天」「20:00」「检查前2小时」这类说法算出时刻
    static func parseTiming(times: [String], sentence: String) -> Todo.Timing? {
        let joined = times.joined(separator: " ")
        let clock = joined.firstMatch(of: #/(\d{1,2})[:：](\d{2})/#).flatMap { m in
            Int(m.1).flatMap { h in Int(m.2).map { (h, $0) } }
        }
        if let m = joined.firstMatch(of: #/前\s*([0-9一二两三四五六七八九十]+)\s*个?\s*[天日]/#), let days = number(String(m.1)) {
            return .daysBefore(days, hour: clock?.0 ?? 9, minute: clock?.1 ?? 0)
        }
        if let m = joined.firstMatch(of: #/前\s*([0-9一二两三四五六七八九十半]+)\s*个?\s*(小时|分钟)/#) {
            let raw = String(m.1)
            let amount = raw == "半" ? 0.5 : Double(number(raw) ?? 0)
            let minutes = m.2 == "小时" ? amount * 60 : amount
            if minutes > 0 { return .minutesBefore(Int(minutes)) }
        }
        if let (hour, minute) = clock {
            if ["前一天", "前1天", "前一日"].contains(where: sentence.contains) {
                return .daysBefore(1, hour: hour, minute: minute)
            }
            return .onExamDay(hour: hour, minute: minute)
        }
        return nil
    }

    /// 阿拉伯数字或「三」「十二」「两」这类中文数字
    static func number(_ text: String) -> Int? {
        if let n = Int(text) { return n }
        let digits: [Character: Int] = ["一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9]
        let chars = Array(text)
        switch chars.count {
        case 1: return chars[0] == "十" ? 10 : digits[chars[0]]
        case 2 where chars[0] == "十": return digits[chars[1]].map { 10 + $0 }
        case 2 where chars[1] == "十": return digits[chars[0]].map { $0 * 10 }
        case 3 where chars[1] == "十": return digits[chars[0]].flatMap { t in digits[chars[2]].map { t * 10 + $0 } }
        default: return nil
        }
    }
}
