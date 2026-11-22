import SwiftUI

/// 阅读页的状态：识别进度、滑块位置、识别结果
@MainActor
@Observable
final class ReaderModel {
    enum Phase: Equatable {
        case recognizing                  // Vision 正在识别文字
        case understanding                // 网页正在打标、播放扫光
        case done(neg: Int, time: Int)    // 刚完成，显示结果几秒
        case idle
        case empty                        // 没识别到文字
    }

    var phase: Phase = .idle
    var t: Double = 0
    var title = "须知"
    var todos: [Todo] = []
    /// 朗读原文时要读的句子（不含次要句）：(网页里的句子编号, 文字)
    @ObservationIgnored private var sentences: [(index: Int, text: String)] = []
    let speaker = Speaker()

    let source: ReaderSource
    @ObservationIgnored let bridge = ReaderBridge()

    var isAnalyzing: Bool { phase == .recognizing || phase == .understanding }
    var isSample: Bool { source == .sample }

    init(source: ReaderSource) {
        self.source = source
        bridge.onMessage = { [weak self] in self?.handle($0) }
        speaker.onStart = { [weak self] id in
            // 原文的句子 id 是 s0、s1…，读到哪句就让网页高亮哪句
            if id.hasPrefix("s"), let index = Int(id.dropFirst()) { self?.bridge.call("qingdu.highlight(\(index))") }
        }
    }

    /// 朗读当前页：原文读非次要句，清单按显示顺序读
    func toggleSpeech(tab: Int) {
        if speaker.isSpeaking {
            stopSpeech()
            return
        }
        if tab == 0 {
            speaker.speak([("title", title)] + sentences.map { ("s\($0.index)", $0.text) })
        } else {
            speaker.speak(Todo.ordered(todos, exam: Todo.savedExamDate).map { ($0.id, "\($0.when)，\($0.title)") })
        }
    }

    /// 把滑块平滑地拉到某个位置（录制演示视频时用）
    func animateT(to target: Double) async {
        let start = t
        for i in 1...36 {
            try? await Task.sleep(for: .milliseconds(16))
            let p = Double(i) / 36
            t = start + (target - start) * (p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2)
        }
    }

    func stopSpeech() {
        speaker.stop()
        bridge.call("qingdu.highlight(-1)")
    }

    func start() async {
        switch source {
        case .sample:
            phase = .understanding
            bridge.call("qingdu.loadSample({animate: true})")
        case .scan(let batch):
            phase = .recognizing
            let paragraphs = (try? await TextRecognizer.paragraphs(from: batch.images)) ?? []
            if paragraphs.isEmpty {
                phase = .empty
                return
            }
            phase = .understanding
            bridge.load(paragraphs: paragraphs, animate: true)
        }
    }

    func send(t: Double) {
        bridge.call("qingdu.setT(\(t))")
    }

    /// 在原文里找到这句话，滚动过去并闪一下
    func locate(_ text: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: text, options: .fragmentsAllowed),
              let json = String(data: data, encoding: .utf8) else { return }
        bridge.call("qingdu.locate(\(json))")
    }

    private func handle(_ message: [String: Any]) {
        guard message["type"] as? String == "analyzed" else { return }
        if message["empty"] as? Bool == true {
            phase = .empty
            return
        }
        if let title = message["title"] as? String, !title.isEmpty { self.title = title }
        let sections = message["sections"] as? [[String: Any]] ?? []
        todos = isSample ? Todo.sample : TodoBuilder.todos(from: sections)
        sentences = sections.flatMap { $0["sentences"] as? [[String: Any]] ?? [] }.compactMap { s in
            guard s["level"] as? String != "minor", let index = s["i"] as? Int, let text = s["text"] as? String else { return nil }
            return (index, text)
        }
        phase = .done(neg: message["neg"] as? Int ?? 0, time: message["time"] as? Int ?? 0)
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if case .done = phase { phase = .idle }
        }
    }
}

struct ReaderScreen: View {
    @State private var model: ReaderModel
    @State private var tab = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPad 横屏等宽屏：原文和清单左右并排，不用切换
    private var isWide: Bool { sizeClass == .regular }
    private var showsDocument: Bool { isWide || tab == 0 }

    init(source: ReaderSource) {
        _model = State(initialValue: ReaderModel(source: source))
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                // 网页一直保留，切到清单时只是隐藏，回来时排版状态不变
                ReaderWebView(bridge: model.bridge)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        LevelBar(t: $model.t)
                    }
                    .opacity(showsDocument ? 1 : 0)
                    .allowsHitTesting(showsDocument)
                if !isWide && tab == 1 {
                    checklist.transition(.opacity)
                }
            }
            // 状态提示只浮在原文这一栏上，iPad 上不挡住右边的清单
            .overlay(alignment: .top) {
                StatusCapsule(phase: model.phase)
                    .padding(.top, 8)
            }
            if isWide {
                Divider().ignoresSafeArea(edges: .bottom)
                checklist
                    .frame(width: 400)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: tab)
        .toolbar {
            if !isWide {
                ToolbarItem(placement: .principal) {
                    Picker("显示", selection: $tab) {
                        Text("原文").tag(0)
                        Text("办事清单").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.toggleSpeech(tab: isWide ? 0 : tab) } label: {
                    Image(systemName: model.speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(model.speaker.isSpeaking ? "停止朗读" : "朗读")
                .disabled(model.isAnalyzing)
            }
        }
        .onChange(of: tab) { _, _ in model.stopSpeech() }
        .onDisappear { model.stopSpeech() }
        .overlay {
            if model.isAnalyzing {
                IntelligenceGlow().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.isAnalyzing)
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.start()
            if ProcessInfo.processInfo.arguments.contains("-demoTour") { await runTour() }
        }
        .onChange(of: model.t) { _, t in model.send(t: t) }
        .alert("没有识别到文字", isPresented: .constant(model.phase == .empty)) {
            Button("返回") { dismiss() }
        } message: {
            Text("请把须知放平、光线充足后重试，或者先看示例。")
        }
    }

    /// 录制演示视频用：带 -demoTour 启动时自动走一遍完整流程
    private func runTour() async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        _ = await Reminders.shared.requestAuthorization()   // 第一次录制前需要手动点「允许」
        while model.todos.isEmpty { await wait(0.3) }
        await wait(3)
        for target in [0.25, 0.5, 0.75, 1.0] {
            await model.animateT(to: target)
            await wait(2.4)
        }
        model.bridge.call("window.scrollTo({top: 560, behavior: 'smooth'})")
        await wait(3.5)
        model.bridge.call("window.scrollTo({top: 0, behavior: 'smooth'})")
        await wait(1.5)
        tab = 1
        await wait(3)
        _ = await Reminders.shared.schedule(model.todos, exam: Todo.savedExamDate, demo: true)
        await wait(4)
        tab = 0
        model.locate("检查前2小时")
        await wait(5)
        tab = 1
    }

    private var checklist: some View {
        ChecklistView(todos: model.todos, title: model.title, isSample: model.isSample,
                      isLoading: model.isAnalyzing, speakingID: model.speaker.speakingID) { todo in
            tab = 0
            model.locate(todo.ref)
        }
    }
}

/// 识别进度提示
private struct StatusCapsule: View {
    let phase: ReaderModel.Phase

    var body: some View {
        Group {
            switch phase {
            case .recognizing:
                content(title: "正在识别文字", subtitle: "读取纸上的内容") { ProgressView() }
            case .understanding:
                content(title: "正在理解内容", subtitle: "找出禁止事项和时间") {
                    Image(systemName: "sparkles").foregroundStyle(IntelligenceGlow.gradient)
                }
            case .done(let neg, let time):
                content(title: "找到 \(neg) 项禁止事项", subtitle: "\(time) 个时间点 · 拖动下方滑块查看") {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            case .idle, .empty:
                EmptyView()
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.25), value: phase)
    }

    private func content(title: String, subtitle: String, @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 12) {
            icon().font(.title2).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 22)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

/// 底部的阅读辅助滑块
private struct LevelBar: View {
    @Binding var t: Double
    @State private var animation: Task<Void, Never>?

    private static let stages: [(at: Double, name: String)] = [
        (0, "原样"), (0.001, "放大 · 加宽行距"), (0.25, "换成黑体"), (0.5, "一句一行 · 分出主次"), (0.75, "标出重点"),
    ]
    private var stageIndex: Int { Self.stages.lastIndex { t >= $0.at } ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if stageIndex == Self.stages.count - 1 {
                    Label(Self.stages[stageIndex].name, systemImage: "sparkles")
                        .foregroundStyle(IntelligenceGlow.gradient)
                } else {
                    Text(Self.stages[stageIndex].name)
                }
                Spacer()
                Text("字号 \(Int((13 + 7 * t).rounded()))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))

            HStack(spacing: 14) {
                Button { step(-1) } label: { Image(systemName: "textformat.size.smaller") }
                    .accessibilityLabel("减少辅助")
                Slider(value: $t, in: 0...1)
                    .accessibilityLabel("阅读辅助强度")
                Button { step(1) } label: { Image(systemName: "textformat.size.larger").font(.title3) }
                    .accessibilityLabel("增加辅助")
            }
            .buttonStyle(.borderless)
            .tint(.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
        .frame(maxWidth: 560)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: stageIndex)
    }

    /// 跳到上一层或下一层（0、0.25、0.5、0.75、1），带缓动动画
    private func step(_ direction: Int) {
        let target = min(1, max(0, ((t * 4).rounded() + Double(direction)) / 4))
        let start = t
        animation?.cancel()
        animation = Task { @MainActor in
            let frames = 36
            for i in 1...frames {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
                let p = Double(i) / Double(frames)
                let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
                t = start + (target - start) * eased
            }
        }
    }
}

/// 识别时沿屏幕边缘流动的彩色光晕
struct IntelligenceGlow: View {
    static let colors: [Color] = [
        Color(red: 0.74, green: 0.51, blue: 0.95), Color(red: 0.96, green: 0.73, blue: 0.92),
        Color(red: 0.55, green: 0.62, blue: 1.00), Color(red: 1.00, green: 0.40, blue: 0.47),
        Color(red: 1.00, green: 0.73, blue: 0.44), Color(red: 0.78, green: 0.53, blue: 1.00),
        Color(red: 0.74, green: 0.51, blue: 0.95),
    ]
    static let gradient = LinearGradient(colors: [colors[2], colors[0], colors[3], colors[4]],
                                         startPoint: .leading, endPoint: .trailing)

    var body: some View {
        TimelineView(.animation) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(seconds.truncatingRemainder(dividingBy: 3.2) / 3.2 * 360)
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: angle)
            ZStack {
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 14)
                    .blur(radius: 18)
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 4)
                    .blur(radius: 1.5)
            }
            .drawingGroup()  // 交给 Metal 一次性渲染，避免每帧在 CPU 上做模糊
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
