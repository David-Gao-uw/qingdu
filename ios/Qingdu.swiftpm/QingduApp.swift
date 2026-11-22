import SwiftUI

@main
struct QingduApp: App {
    init() {
        Reminders.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}

/// 从哪里打开一份须知
enum ReaderSource: Hashable {
    case sample
    case scan(ScanBatch)
}

/// 一次扫描或从相册选的图片。按 id 比较，避免比较图片本身。
struct ScanBatch: Hashable {
    let id = UUID()
    let images: [UIImage]

    static func == (a: ScanBatch, b: ScanBatch) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct RootView: View {
    // 开发调试：带 -openSample（或录屏用的 -demoTour）启动时直接打开示例
    @State private var path: [ReaderSource] = ["-openSample", "-demoTour"].contains(where: ProcessInfo.processInfo.arguments.contains) ? [.sample] : []

    var body: some View {
        NavigationStack(path: $path) {
            StartView { path.append($0) }
                .navigationDestination(for: ReaderSource.self) { ReaderScreen(source: $0) }
        }
    }
}
