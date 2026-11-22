import SwiftUI

/// 关于清读：哪些是真做、哪些是模拟、哪些还没做（答辩时可以直接打开给评委看）
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("清读").font(.largeTitle.bold())
                        Text("帮老人看清、读懂、照做医院给的纸质须知。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    item("doc.viewfinder", "相机扫描", "VisionKit 文档扫描器，自动找边、拉正")
                    item("text.viewfinder", "中文文字识别", "Vision 在设备上识别，再按缩进和标点拼回段落")
                    item("exclamationmark.triangle", "找出禁止事项和时间", "规则识别「不要」「禁止」「检查前 2 小时」等写法")
                    item("textformat.size", "分层排版", "放大、换字体、一句一行、关键句放大、次要句退后")
                    item("bell.badge", "提醒", "按检查时间算出每件事的时刻，用系统通知提醒")
                    item("speaker.wave.2", "朗读", "系统普通话语音，逐句高亮")
                    item("square.and.arrow.up", "发给家人", "把清单整理成一段话，通过系统分享发出")
                } header: {
                    Label("真实运行", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                }

                Section {
                    item("text.bubble", "示例须知的大白话要点",
                         "这 8 条是预先整理好的，模拟大模型改写的效果。扫描的须知则用原文句子。")
                    item("sparkles", "「正在理解内容」的光效", "只表示进度，背后是上面的规则，并没有调用模型")
                } header: {
                    Label("模拟", systemImage: "theatermasks.fill").foregroundStyle(.orange)
                }

                Section {
                    item("wand.and.stars", "任意须知改写成大白话", "需要大模型，演示设备不支持 Apple Intelligence")
                    item("waveform", "方言朗读", "系统没有方言语音，需要第三方服务")
                    item("mic", "语音提问", "如「几点开始不能喝水？」")
                } header: {
                    Label("还没有做", systemImage: "hourglass").foregroundStyle(.secondary)
                }

                Section {
                    item("lock.shield", "信息不离开手机",
                         "扫描、识别、整理都在这台设备上完成，不联网、不上传。医疗信息只有你和你选择分享的家人能看到。")
                } header: {
                    Label("隐私", systemImage: "hand.raised.fill")
                }

                Section {
                    Text("CrossPointX 2026 · Apple Human Care 赛道")
                    Text("示例须知为编写的示例文本，不代表任何真实医院。")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("关于清读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func item(_ icon: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 2)
    }
}
